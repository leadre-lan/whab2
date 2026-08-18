import { NextResponse } from "next/server";
import { setAccount, log } from "../../../../lib/store.js";

// STUB for the Meta Embedded Signup flow.
// Production: redirect the Makler to Facebook Login for Business (Embedded Signup) with your
// app_id + config_id, receive the code on the callback, exchange for a System User token,
// and store the granted ad_account_id / page_id / pixel_id.
// Requires: Meta App with advanced_access ads_management + business_management,
// Business Verification, and App Review.
export async function GET() {
  setAccount({ metaConnected: true, metaStub: true });
  log({ kind: "meta.connect", msg: "Meta verbunden (Stub) — Embedded Signup in Produktion" });
  return NextResponse.json({ ok: true, connected: true, note: "stub" });
}
