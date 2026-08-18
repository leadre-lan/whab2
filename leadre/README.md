# LeadRE — Makler-Marketing auf Autopilot (MVP-Gerüst)

Next.js-App (App Router) für Vercel. Klickbares Grundgerüst: Onboarding → Agent baut
**beide** Funnel (Verkäufer + Käufer) → wöchentliches Angle-Testing (Soft-KPIs) → CRM +
täglicher SMS-Bericht. Alle externen Integrationen sind **Stubs mit TODO-Hooks**.

## Lokal starten
```bash
cd leadre
npm install
npm run dev      # http://localhost:3000
```
Klick-Flow: `/onboarding` (Domain + Meta-Stub + Region + Funnel) → „Funnel aufsetzen" →
`/dashboard` (Optimieren / SMS-Bericht) → `/f/<slug>` (öffentliche Landingpage, Lead absenden).

## Struktur
```
app/
  page.jsx                 Startseite
  onboarding/page.jsx      10-Min-Wizard (Domain, Meta, Region, Funnel-Auswahl)
  dashboard/page.jsx       CRM, Funnel-Status, Angle-Tests, Agent-Log, Berichte
  f/[slug]/                Öffentliche Funnel-Landingpage + Lead-Formular
  api/
    agent/setup            Onboarding -> Funnel(s) bauen + erste Testwoche
    optimize               Winner skalieren / Loser killen (Soft-KPIs)
    report/daily           Morgen-SMS an Makler
    leads                  Lead-Capture (POST) + Liste (GET)
    meta/connect           Meta-Verbindung (Stub)
    state                  Kompletter State fürs Dashboard
lib/
  store.js                 In-Memory-Store (Prod: Supabase/Postgres)
  funnels.js               Funnel-Templates + Angle-Bibliothek
  agent.js                 Orchestrator (Setup, Test-Batch, Optimierung, Report)
  integrations.js          Meta / Higgsfield / LLM / Twilio / Domain — Stubs
```

## Von Stub zu Produktion (TODO-Hooks in `lib/integrations.js`)
- **Meta:** Embedded Signup (Facebook Login for Business) → System-User-Token →
  Kampagnen/AdSets/Ads via Graph API. Braucht App Review (`ads_management`,
  `business_management`), Business-Verifizierung.
- **Higgsfield:** `generate_image` mit Angle + Brand-Style, pollen, Asset-URL zurück.
- **LLM:** Angle-/Copy-Generierung pro Woche aus Avatar + Region.
- **Twilio:** täglicher SMS-Bericht (Vercel Cron 07:00).
- **DB:** `lib/store.js` → Supabase/Postgres (Account, Funnels, Leads, Events, Reports).
- **E-Mail an Bestandslisten:** DSGVO/UWG beachten (Rechtsgrundlage, Double-Opt-in, Abmeldung).

## Realismus-Hinweise
- „100 Angles/Woche" = **Bibliotheks-Tiefe**, live getestet werden realistisch ~8/Woche
  (`WEEKLY_TEST_BATCH` in `lib/agent.js`), Culling über Soft-KPIs, weil Conversions dünn sind.
- „10 Minuten" = UI-Zeit; DNS-Propagation, E-Mail-Auth und Meta-Review laufen im Hintergrund.
