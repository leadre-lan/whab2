"use client";
import { useState } from "react";

export default function Onboarding() {
  const [step, setStep] = useState(1);
  const [domain, setDomain] = useState("");
  const [metaConnected, setMetaConnected] = useState(false);
  const [region, setRegion] = useState("");
  const [phone, setPhone] = useState("");
  const [funnels, setFunnels] = useState(["seller", "buyer"]);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(null);

  const toggleFunnel = (t) =>
    setFunnels((f) => (f.includes(t) ? f.filter((x) => x !== t) : [...f, t]));

  async function connectMeta() {
    const r = await fetch("/api/meta/connect");
    if (r.ok) setMetaConnected(true);
  }

  async function finish() {
    setBusy(true);
    const r = await fetch("/api/agent/setup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ domain, metaConnected, region, phone, funnels }),
    });
    const data = await r.json();
    setDone(data);
    setBusy(false);
    setStep(5);
  }

  const canDomain = domain.trim().includes(".");
  const canRegion = region.trim().length > 1 && phone.trim().length > 5 && funnels.length > 0;

  return (
    <div className="narrow">
      <h1>Onboarding</h1>
      <p className="sub">In wenigen Schritten ist dein komplettes Marketing automatisiert aufgesetzt.</p>

      {/* Step 1: Domain (required) */}
      <div className={"card"}>
        <span className="label">Schritt 1 · Domain verbinden (erforderlich)</span>
        <h2>Deine Domain</h2>
        <p className="muted">Für deine Landingpages und den E-Mail-Versand an Bestandskontakte.</p>
        <input placeholder="z. B. mueller-immobilien.de" value={domain} onChange={(e) => setDomain(e.target.value)} />
        <p className="small" style={{ marginTop: 10 }}>Wir richten DNS (CNAME zu Vercel) und E-Mail-Auth (SPF/DKIM/DMARC) automatisch ein. Läuft im Hintergrund weiter.</p>
      </div>

      {/* Step 2: Meta */}
      <div className="card">
        <span className="label">Schritt 2 · Meta verbinden</span>
        <h2>Werbekonto verbinden</h2>
        <p className="muted">Ein Klick über Facebook Login. Wir bekommen Zugriff auf Werbekonto, Seite und Pixel.</p>
        {metaConnected ? (
          <span className="pill on">✓ Meta verbunden</span>
        ) : (
          <button className="btn" onClick={connectMeta}>Mit Meta verbinden</button>
        )}
        <p className="small" style={{ marginTop: 10 }}>Produktion: Meta Embedded Signup. Aktuell Demo-Stub.</p>
      </div>

      {/* Step 3: Region + phone + funnels */}
      <div className="card">
        <span className="label">Schritt 3 · Angaben</span>
        <h2>Region & Ziele</h2>
        <div className="grid2">
          <div>
            <span className="label">Region / Zielgebiet</span>
            <input placeholder="z. B. Karlsruhe" value={region} onChange={(e) => setRegion(e.target.value)} />
          </div>
          <div>
            <span className="label">Handynummer für Berichte</span>
            <input placeholder="+49 …" value={phone} onChange={(e) => setPhone(e.target.value)} />
          </div>
        </div>
        <div style={{ marginTop: 14 }}>
          <span className="label">Welche Funnel?</span>
          <div style={{ display: "flex", gap: 10 }}>
            <button className={"btn " + (funnels.includes("seller") ? "gold" : "ghost")} onClick={() => toggleFunnel("seller")}>Verkäufer finden</button>
            <button className={"btn " + (funnels.includes("buyer") ? "gold" : "ghost")} onClick={() => toggleFunnel("buyer")}>Käufer finden</button>
          </div>
        </div>
      </div>

      <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
        <button className="btn gold" disabled={!canDomain || !canRegion || busy} onClick={finish}>
          {busy ? "Agent baut deine Funnel…" : "Funnel automatisiert aufsetzen"}
        </button>
        {(!canDomain || !canRegion) && <span className="small">Domain, Region, Nummer und mindestens ein Funnel nötig.</span>}
      </div>

      {done && (
        <div className="card" style={{ marginTop: 18, borderColor: "var(--green)" }}>
          <h2>✓ Fertig aufgesetzt</h2>
          <p className="muted">Der Agent hat folgende Funnel gebaut und die erste Angle-Testwoche gestartet:</p>
          <ul>
            {done.funnels?.map((f) => (
              <li key={f.id}>
                <b>{f.label}</b> · Landingpage: <a href={`/f/${f.slug}`}>/f/{f.slug}</a>
              </li>
            ))}
          </ul>
          <a className="btn" href="/dashboard">Zum Dashboard →</a>
        </div>
      )}
    </div>
  );
}
