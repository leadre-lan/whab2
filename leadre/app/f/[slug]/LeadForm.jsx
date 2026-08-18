"use client";
import { useState } from "react";

export default function LeadForm({ slug, type, cta }) {
  const [form, setForm] = useState({ name: "", phone: "", email: "", extra: "" });
  const [sent, setSent] = useState(false);
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  async function submit(e) {
    e.preventDefault();
    await fetch("/api/leads", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ slug, name: form.name, phone: form.phone, email: form.email, extra: { note: form.extra } }),
    });
    setSent(true);
  }

  if (sent) return <div><h2>Danke!</h2><p className="muted">Wir melden uns in Kürze. (Lead ist im CRM.)</p></div>;

  return (
    <form onSubmit={submit}>
      <div className="grid2">
        <div><span className="label">Name</span><input required value={form.name} onChange={set("name")} /></div>
        <div><span className="label">Telefon</span><input required value={form.phone} onChange={set("phone")} /></div>
      </div>
      <div style={{ marginTop: 12 }}><span className="label">E-Mail</span><input type="email" value={form.email} onChange={set("email")} /></div>
      <div style={{ marginTop: 12 }}>
        <span className="label">{type === "seller" ? "Adresse der Immobilie" : "Budget / Suchprofil"}</span>
        <input value={form.extra} onChange={set("extra")} placeholder={type === "seller" ? "Straße, Ort" : "z. B. 400.000 €, 4 Zimmer"} />
      </div>
      <button className="btn gold" style={{ marginTop: 16 }} type="submit">{cta} →</button>
    </form>
  );
}
