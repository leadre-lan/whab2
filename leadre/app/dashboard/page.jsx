"use client";
import { useEffect, useState } from "react";

export default function Dashboard() {
  const [state, setState] = useState(null);
  const [busy, setBusy] = useState("");

  async function load() {
    const r = await fetch("/api/state");
    setState(await r.json());
  }
  useEffect(() => { load(); }, []);

  async function run(path, key) {
    setBusy(key);
    await fetch(path, { method: "POST" });
    await load();
    setBusy("");
  }

  if (!state) return <p className="muted">Lädt…</p>;
  const { account, funnels, leads, events, reports } = state;

  if (!account) {
    return (
      <div className="narrow">
        <h1>Dashboard</h1>
        <div className="card"><p className="muted">Noch kein Konto. Zuerst das <a href="/onboarding">Onboarding</a> durchlaufen.</p></div>
      </div>
    );
  }

  return (
    <div>
      <h1>Dashboard</h1>
      <p className="sub">
        {account.region} · Domain {account.domain} · Meta {account.metaConnected ? "verbunden" : "nicht verbunden"}
      </p>

      <div className="grid3">
        <div className="card"><span className="label">Leads gesamt</span><h1 style={{ margin: 0 }}>{leads.length}</h1></div>
        <div className="card"><span className="label">Aktive Funnel</span><h1 style={{ margin: 0 }}>{funnels.length}</h1></div>
        <div className="card"><span className="label">Angles in Test</span><h1 style={{ margin: 0 }}>{funnels.reduce((n, f) => n + (f.tests?.length || 0), 0)}</h1></div>
      </div>

      <div style={{ display: "flex", gap: 10, margin: "6px 0 18px" }}>
        <button className="btn" disabled={busy} onClick={() => run("/api/optimize", "opt")}>{busy === "opt" ? "Optimiere…" : "Optimierungs-Lauf (Winner skalieren / Loser killen)"}</button>
        <button className="btn ghost" disabled={busy} onClick={() => run("/api/report/daily", "rep")}>{busy === "rep" ? "Sende…" : "Morgen-Bericht per SMS senden"}</button>
      </div>

      {/* Funnels + weekly tests */}
      {funnels.map((f) => (
        <div className="card" key={f.id}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <h2 style={{ margin: 0 }}>{f.label}</h2>
            <span className="pill on">{f.status}</span>
            <div className="spacer" style={{ flex: 1 }} />
            <a className="small" href={`/f/${f.slug}`}>Landingpage ansehen →</a>
          </div>
          <p className="muted" style={{ margin: "6px 0 10px" }}>{f.goal} · {f.region}</p>
          <table>
            <thead><tr><th>Angle</th><th>Status</th><th>Soft-KPIs</th></tr></thead>
            <tbody>
              {(f.tests || []).map((t, i) => (
                <tr key={i}>
                  <td>{t.hook}</td>
                  <td><span className={"pill " + (t.status === "winner" ? "win" : t.status === "killed" ? "kill" : "test")}>{t.status}</span></td>
                  <td>{t.kpis ? <span className="kpis"><span>CTR <b>{t.kpis.ctr}%</b></span><span>CPC <b>{t.kpis.cpc}€</b></span><span>CPL <b>{t.kpis.cpl}€</b></span></span> : <span className="muted">noch keine Daten</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ))}

      <div className="grid2">
        <div className="card">
          <h2>CRM · Leads</h2>
          <table>
            <thead><tr><th>Name</th><th>Kontakt</th><th>Funnel</th></tr></thead>
            <tbody>
              {leads.length === 0 && <tr><td colSpan={3} className="muted">Noch keine Leads. Öffne eine Landingpage und trag dich testweise ein.</td></tr>}
              {leads.map((l) => (
                <tr key={l.id}><td>{l.name || "—"}</td><td>{l.phone || l.email || "—"}</td><td>{l.type}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="card">
          <h2>Agent · Aktivität</h2>
          <div style={{ maxHeight: 320, overflow: "auto" }}>
            {events.map((e) => (
              <div key={e.id} className="step" style={{ padding: "8px 0" }}>
                <div><b className="small">{new Date(e.at).toLocaleTimeString("de-DE")}</b><div>{e.msg}</div></div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {reports.length > 0 && (
        <div className="card">
          <h2>Berichte (SMS)</h2>
          {reports.map((r) => <div key={r.id} className="muted" style={{ padding: "6px 0" }}>📱 {r.body}</div>)}
        </div>
      )}
    </div>
  );
}
