import { NextResponse } from "next/server";
import { getAccount } from "../../../../lib/store.js";
import { dailyReport } from "../../../../lib/agent.js";

// Sends the morning SMS report.
async function run() {
  const rep = await dailyReport(getAccount());
  return NextResponse.json({ ok: true, report: rep });
}
export async function POST() { return run(); }
// Vercel Cron invokes endpoints via GET (see vercel.json), so support GET too.
export async function GET() { return run(); }
