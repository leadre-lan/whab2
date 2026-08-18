// Integration stubs. Each returns a fake-but-shaped result and logs a TODO.
// Replace the bodies with real API calls. Keep the signatures stable so the rest of the app does not change.

import { log } from "./store.js";

// ---- META (Marketing API) -------------------------------------------------
// Production: Embedded Signup (Facebook Login for Business) -> System User token ->
// create Campaign/AdSet/Ad via Graph API. Requires App Review advanced_access for
// ads_management + business_management + Business Verification.
export const meta = {
  connectUrl() {
    // TODO: return real Embedded Signup URL with your app_id + config_id.
    return "/api/meta/connect?stub=1";
  },
  async launchAd({ funnelId, angle, creativeUrl, budgetCents }) {
    log({ kind: "meta.launch", funnelId, msg: `Ad geschaltet: "${angle.hook}"`, angleId: angle.id });
    // TODO: POST /act_{adAccountId}/ads
    return { adId: "stub_" + angle.id, status: "ACTIVE" };
  },
  async pauseAd(adId) {
    log({ kind: "meta.pause", msg: `Ad pausiert: ${adId}` });
    return { adId, status: "PAUSED" };
  },
  async scaleAd(adId, factor) {
    log({ kind: "meta.scale", msg: `Ad skaliert x${factor}: ${adId}` });
    return { adId, status: "ACTIVE" };
  },
  // Soft KPIs the optimizer culls on (conversions are sparse at small budgets).
  async fetchSoftKpis(adId) {
    return {
      adId,
      hookRate: rand(0.05, 0.35), // 3s video views / impressions (or thumbstop for statics via CTR proxy)
      ctr: rand(0.4, 4.5),
      cpc: rand(0.3, 2.5),
      cpl: rand(4, 40),
    };
  },
};

// ---- HIGGSFIELD (creatives) ----------------------------------------------
export const higgsfield = {
  async generateCreative({ angle, style }) {
    log({ kind: "creative.generate", msg: `Creative generiert (${style}): "${angle.hook}"`, angleId: angle.id });
    // TODO: call Higgsfield generate_image with the angle + brand style, poll, return asset URL.
    return { url: `https://placehold.co/1080x1350?text=${encodeURIComponent(angle.kicker)}`, style };
  },
};

// ---- LLM (angle + copy generation) ---------------------------------------
export const llm = {
  async expandAngles({ type, region, count }) {
    // TODO: call Claude to generate `count` fresh angles from avatar + region context.
    log({ kind: "angles.expand", msg: `${count} neue Angles generiert (${type}, ${region})` });
    return [];
  },
};

// ---- TWILIO (daily SMS report) -------------------------------------------
export const sms = {
  async send({ to, body }) {
    log({ kind: "sms.send", msg: `SMS an ${to || "Makler"}: ${body.slice(0, 60)}...` });
    // TODO: Twilio Messages.create
    return { sid: "SM_stub_" + Date.now(), to, body };
  },
};

// ---- DOMAIN / VERCEL ------------------------------------------------------
export const domain = {
  async verify(domainName) {
    log({ kind: "domain.verify", msg: `Domain-Verbindung geprüft: ${domainName}` });
    // TODO: check DNS (CNAME to Vercel) + email auth (SPF/DKIM/DMARC).
    return { domain: domainName, dns: "pending", emailAuth: "pending" };
  },
};

function rand(a, b) { return Math.round((a + Math.random() * (b - a)) * 100) / 100; }
