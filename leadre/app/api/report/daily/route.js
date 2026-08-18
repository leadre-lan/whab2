import { NextResponse } from "next/server";
import { getAccount } from "../../../../lib/store.js";
import { dailyReport } from "../../../../lib/agent.js";

// Sends the morning SMS report. In production: Vercel Cron daily at 07:00.
export async function POST() {
  const rep = await dailyReport(getAccount());
  return NextResponse.json({ ok: true, report: rep });
}
