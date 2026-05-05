// Lovable Agent Worker — runs on Railway/Fly.
// Polls Supabase Edge Function `agent-worker-api/claim`, then drives Anthropic Computer Use
// via Browserbase + Playwright to autonomously complete user tasks.
//
// Required ENV:
//   SUPABASE_FUNCTIONS_URL   e.g. https://wxriqujkusncquznsusr.supabase.co/functions/v1
//   WORKER_SHARED_SECRET     same value you stored in Lovable secrets
//   ANTHROPIC_API_KEY
//   BROWSERBASE_API_KEY
//   BROWSERBASE_PROJECT_ID

import Anthropic from "@anthropic-ai/sdk";
import Browserbase from "@browserbasehq/sdk";
import { chromium } from "playwright-core";

const FN = process.env.SUPABASE_FUNCTIONS_URL;
const SECRET = process.env.WORKER_SHARED_SECRET;
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const bb = new Browserbase({ apiKey: process.env.BROWSERBASE_API_KEY });

const MODEL = "claude-sonnet-4-5";
const VIEWPORT = { width: 1280, height: 800 };

async function api(action, body = {}) {
  const r = await fetch(`${FN}/agent-worker-api/${action}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${SECRET}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`${action} ${r.status}: ${await r.text()}`);
  return r.json();
}

async function claim() { return (await api("claim")).job; }
const log = (job_id, kind, message, data) => api("update", { job_id, kind, message, data });
const ask = (job_id, question) => api("ask", { job_id, question });
const finish = (job_id, summary, result) => api("finish", { job_id, summary, result });
const fail = (job_id, error) => api("fail", { job_id, error });
const pollAnswer = (job_id) => api("poll_answer", { job_id });

async function waitForAnswer(job_id, timeoutMs = 30 * 60 * 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    await new Promise((r) => setTimeout(r, 5000));
    const s = await pollAnswer(job_id);
    if (s.status === "running" && s.user_answer) return s.user_answer;
    if (s.status === "failed" || s.status === "done") return null;
  }
  return null;
}

async function runJob(job) {
  console.log(`[job ${job.id}] ${job.user_request}`);
  // 1) Browserbase session
  const session = await bb.sessions.create({ projectId: process.env.BROWSERBASE_PROJECT_ID, browserSettings: { viewport: VIEWPORT } });
  const dbg = await bb.sessions.debug(session.id);
  const liveUrl = dbg.debuggerFullscreenUrl ?? dbg.debuggerUrl;
  await log(job.id, "browser_ready", "Browser session started", { live_url: liveUrl });
  await api("update", { job_id: job.id, browserbase_session_id: session.id, live_url: liveUrl });

  const browser = await chromium.connectOverCDP(session.connectUrl);
  const page = (await browser.contexts())[0].pages()[0] ?? await (await browser.contexts())[0].newPage();

  // 2) Anthropic Computer Use loop
  const messages = [
    { role: "user", content: `Du bist ein autonomer Web-Agent. Aufgabe vom Inhaber:\n\n"${job.user_request}"\n\nNutze den Browser, um die Aufgabe vollständig zu erledigen. Wenn du Daten brauchst, die nur der Mensch kennen kann (Login, Kreditkarte, persönliche Infos, Bestätigung), benutze das Tool 'ask_human'. Antworte am Ende mit einer kurzen Zusammenfassung.` },
  ];

  const tools = [
    { type: "computer_20250124", name: "computer", display_width_px: VIEWPORT.width, display_height_px: VIEWPORT.height, display_number: 1 },
    {
      name: "ask_human",
      description: "Ask the human owner for missing info (credentials, address, payment, confirmation). Pauses execution until they answer.",
      input_schema: { type: "object", properties: { question: { type: "string" } }, required: ["question"] },
    },
  ];

  for (let i = 0; i < 50; i++) {
    const resp = await anthropic.beta.messages.create({
      model: MODEL, max_tokens: 4096, tools, messages,
      betas: ["computer-use-2025-01-24"],
    });
    messages.push({ role: "assistant", content: resp.content });

    const toolUses = resp.content.filter((b) => b.type === "tool_use");
    if (toolUses.length === 0) {
      const text = resp.content.filter((b) => b.type === "text").map((b) => b.text).join("\n");
      await finish(job.id, text || "Erledigt.", { transcript: text });
      break;
    }

    const toolResults = [];
    for (const tu of toolUses) {
      if (tu.name === "ask_human") {
        await ask(job.id, tu.input.question);
        const answer = await waitForAnswer(job.id);
        toolResults.push({ type: "tool_result", tool_use_id: tu.id, content: answer ?? "(no answer, abort)" });
      } else if (tu.name === "computer") {
        const out = await runComputerAction(page, tu.input);
        toolResults.push({ type: "tool_result", tool_use_id: tu.id, content: out });
        await log(job.id, "action", tu.input.action, tu.input);
      }
    }
    messages.push({ role: "user", content: toolResults });
  }

  await browser.close().catch(() => {});
  await bb.sessions.update(session.id, { projectId: process.env.BROWSERBASE_PROJECT_ID, status: "REQUEST_RELEASE" }).catch(() => {});
}

async function runComputerAction(page, input) {
  const { action } = input;
  try {
    if (action === "screenshot") {
      const buf = await page.screenshot({ type: "png" });
      return [{ type: "image", source: { type: "base64", media_type: "image/png", data: buf.toString("base64") } }];
    }
    if (action === "left_click" || action === "double_click" || action === "right_click") {
      const [x, y] = input.coordinate; const button = action === "right_click" ? "right" : "left";
      await page.mouse.click(x, y, { button, clickCount: action === "double_click" ? 2 : 1 });
    }
    if (action === "mouse_move") { const [x, y] = input.coordinate; await page.mouse.move(x, y); }
    if (action === "type") { await page.keyboard.type(input.text); }
    if (action === "key") {
      const map = { Return: "Enter", Page_Down: "PageDown", Page_Up: "PageUp" };
      const keys = String(input.text).split("+").map((k) => map[k] ?? k);
      for (const k of keys) await page.keyboard.down(k);
      for (const k of keys.reverse()) await page.keyboard.up(k);
    }
    if (action === "scroll") {
      const [x, y] = input.coordinate ?? [VIEWPORT.width / 2, VIEWPORT.height / 2];
      const dy = input.scroll_direction === "up" ? -300 : 300;
      await page.mouse.move(x, y); await page.mouse.wheel(0, dy * (input.scroll_amount || 1));
    }
    if (action === "wait") await new Promise((r) => setTimeout(r, (input.duration || 1) * 1000));
    // Always return a fresh screenshot
    const buf = await page.screenshot({ type: "png" });
    return [{ type: "image", source: { type: "base64", media_type: "image/png", data: buf.toString("base64") } }];
  } catch (e) {
    return `error: ${e.message}`;
  }
}

async function loop() {
  console.log("Worker started, polling…");
  while (true) {
    try {
      const job = await claim();
      if (!job) { await new Promise((r) => setTimeout(r, 5000)); continue; }
      try { await runJob(job); }
      catch (e) { console.error(e); await fail(job.id, e.message ?? String(e)); }
    } catch (e) {
      console.error("loop error", e);
      await new Promise((r) => setTimeout(r, 10000));
    }
  }
}
loop();
