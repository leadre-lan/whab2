import { NextResponse } from "next/server";
import { addLead, listLeads, getFunnel, log } from "../../../lib/store.js";

export async function GET() {
  return NextResponse.json({ leads: listLeads() });
}

// Public lead capture from a funnel landing page.
// Body: { slug, name, phone, email, extra }
export async function POST(req) {
  const b = await req.json();
  const f = getFunnel(b.slug);
  const lead = addLead({
    funnelId: f?.id || null,
    type: f?.type || "unknown",
    region: f?.region || null,
    name: b.name || "",
    phone: b.phone || "",
    email: b.email || "",
    extra: b.extra || {},
  });
  log({ kind: "lead.new", funnelId: lead.funnelId, msg: `Neuer Lead: ${lead.name || lead.email || lead.phone}` });
  return NextResponse.json({ ok: true, lead });
}
