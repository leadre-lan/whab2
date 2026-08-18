// In-memory store for the MVP scaffold. Swap for Supabase/Postgres in production.
// State lives on globalThis so it survives Next.js hot-reloads in dev.
const g = globalThis;
if (!g.__leadre) {
  g.__leadre = {
    account: null, // set during onboarding
    funnels: [],   // { id, type: 'seller'|'buyer', slug, status, region, angleQueue, tests }
    leads: [],     // { id, funnelId, type, name, phone, email, meta, createdAt }
    events: [],    // activity log for the "agent"
    reports: [],   // daily report snapshots
  };
}
const db = g.__leadre;

export function getAccount() { return db.account; }
export function setAccount(a) { db.account = { ...db.account, ...a }; return db.account; }

export function listFunnels() { return db.funnels; }
export function getFunnel(slug) { return db.funnels.find((f) => f.slug === slug); }
export function upsertFunnel(f) {
  const i = db.funnels.findIndex((x) => x.id === f.id);
  if (i >= 0) db.funnels[i] = { ...db.funnels[i], ...f };
  else db.funnels.push(f);
  return f;
}

export function addLead(lead) {
  const l = { id: cryptoRandom(), createdAt: new Date().toISOString(), ...lead };
  db.leads.unshift(l);
  return l;
}
export function listLeads() { return db.leads; }

export function log(event) {
  db.events.unshift({ id: cryptoRandom(), at: new Date().toISOString(), ...event });
  return db.events[0];
}
export function listEvents() { return db.events; }

export function addReport(r) { db.reports.unshift({ id: cryptoRandom(), at: new Date().toISOString(), ...r }); return db.reports[0]; }
export function listReports() { return db.reports; }

function cryptoRandom() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}
