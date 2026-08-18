import { NextResponse } from "next/server";
import { getAccount, listFunnels, listLeads, listEvents, listReports } from "../../../lib/store.js";

export async function GET() {
  return NextResponse.json({
    account: getAccount(),
    funnels: listFunnels(),
    leads: listLeads(),
    events: listEvents().slice(0, 40),
    reports: listReports().slice(0, 10),
  });
}
