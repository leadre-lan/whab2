import { NextResponse } from "next/server";
import { listFunnels } from "../../../lib/store.js";
import { optimize } from "../../../lib/agent.js";

// Runs the optimization pass across all funnels. In production this is a weekly/daily cron.
export async function POST() {
  const results = [];
  for (const f of listFunnels()) {
    const r = await optimize(f.id);
    results.push({ funnel: f.label, ...r });
  }
  return NextResponse.json({ ok: true, results });
}
