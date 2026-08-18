// LeadRE Agent orchestrator: sets up a funnel, seeds the weekly angle test batch,
// runs the optimization loop (scale winners / kill losers on soft KPIs), builds reports.
import { upsertFunnel, listFunnels, log, listLeads, addReport } from "./store.js";
import { FUNNELS, ANGLE_LIBRARY, renderAngle } from "./funnels.js";
import { meta, higgsfield, sms } from "./integrations.js";

// How many angles we actually test per week (realistic, not 100 live at once).
const WEEKLY_TEST_BATCH = 8;
// Soft-KPI thresholds for culling.
const KILL = { ctrBelow: 0.8, cplAbove: 30 };
const SCALE = { ctrAbove: 2.0, cplBelow: 12 };

export async function setupFunnel({ type, region }) {
  const tpl = FUNNELS[type];
  if (!tpl) throw new Error("unknown funnel type");
  const id = `${type}-${Date.now().toString(36)}`;
  const slug = `${type}-${region.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`.slice(0, 40);
  const funnel = upsertFunnel({
    id, slug, type, region, status: "aktiv",
    label: tpl.label, goal: tpl.goal,
    angleQueue: [], tests: [], createdAt: new Date().toISOString(),
  });
  log({ kind: "agent.setup", funnelId: id, msg: `Funnel "${tpl.label}" für ${region} aufgesetzt` });
  await seedWeeklyBatch(id);
  return funnel;
}

// Seed this week's test batch: pick angles, generate creatives, launch ads.
export async function seedWeeklyBatch(funnelId) {
  const f = findById(funnelId);
  if (!f) return;
  const library = ANGLE_LIBRARY[f.type].map((a) => renderAngle(a, { region: f.region }));
  const batch = pickN(library, Math.min(WEEKLY_TEST_BATCH, library.length));
  const tests = [];
  for (const angle of batch) {
    const creative = await higgsfield.generateCreative({ angle, style: "editorial-typo" });
    const ad = await meta.launchAd({ funnelId, angle, creativeUrl: creative.url, budgetCents: 1000 });
    tests.push({ angleId: angle.id, hook: angle.hook, adId: ad.adId, creative: creative.url, status: "testing", kpis: null });
  }
  f.tests = tests;
  upsertFunnel(f);
  log({ kind: "agent.batch", funnelId, msg: `${tests.length} Angles diese Woche gestartet` });
  return tests;
}

// Optimization pass: fetch soft KPIs, scale winners, kill losers.
export async function optimize(funnelId) {
  const f = findById(funnelId);
  if (!f) return;
  let scaled = 0, killed = 0;
  for (const t of f.tests) {
    const k = await meta.fetchSoftKpis(t.adId);
    t.kpis = k;
    if (k.ctr >= SCALE.ctrAbove && k.cpl <= SCALE.cplBelow) { await meta.scaleAd(t.adId, 1.3); t.status = "winner"; scaled++; }
    else if (k.ctr <= KILL.ctrBelow || k.cpl >= KILL.cplAbove) { await meta.pauseAd(t.adId); t.status = "killed"; killed++; }
    else { t.status = "testing"; }
  }
  upsertFunnel(f);
  log({ kind: "agent.optimize", funnelId, msg: `Optimiert: ${scaled} skaliert, ${killed} gekillt` });
  return { scaled, killed };
}

// Build + "send" the daily morning report to the Makler's number.
export async function dailyReport(account) {
  const leads = listLeads();
  const today = leads.filter((l) => sameDay(l.createdAt, new Date()));
  const body = `LeadRE Bericht: ${today.length} neue Leads heute, ${leads.length} gesamt. Winner laufen, Loser gekillt.`;
  await sms.send({ to: account?.phone, body });
  const rep = addReport({ leadsToday: today.length, leadsTotal: leads.length, body });
  log({ kind: "report.daily", msg: body });
  return rep;
}

function findById(id) { return listFunnels().find((x) => x.id === id); }
function pickN(arr, n) { return [...arr].sort(() => Math.random() - 0.5).slice(0, n); }
function sameDay(iso, d) { const a = new Date(iso); return a.toDateString() === d.toDateString(); }
