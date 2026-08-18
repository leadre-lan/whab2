import { NextResponse } from "next/server";
import { setAccount, log } from "../../../../lib/store.js";
import { setupFunnel } from "../../../../lib/agent.js";
import { domain } from "../../../../lib/integrations.js";

// Body: { domain, metaConnected, region, phone, funnels: ["seller","buyer"] }
export async function POST(req) {
  const b = await req.json();
  await domain.verify(b.domain);
  setAccount({
    domain: b.domain,
    metaConnected: !!b.metaConnected,
    region: b.region,
    phone: b.phone,
    onboardedAt: new Date().toISOString(),
  });
  log({ kind: "onboarding.done", msg: `Onboarding abgeschlossen für ${b.region}` });
  const created = [];
  for (const type of b.funnels || ["seller", "buyer"]) {
    const f = await setupFunnel({ type, region: b.region });
    created.push({ id: f.id, slug: f.slug, type: f.type, label: f.label });
  }
  return NextResponse.json({ ok: true, funnels: created });
}
