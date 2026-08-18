import { getFunnel } from "../../../lib/store.js";
import { FUNNELS } from "../../../lib/funnels.js";
import LeadForm from "./LeadForm.jsx";

export default function FunnelPage({ params }) {
  const f = getFunnel(params.slug);
  if (!f) {
    return <div className="narrow"><h1>Funnel nicht gefunden</h1><p className="muted">Diese Landingpage existiert nicht. Zuerst im <a href="/onboarding">Onboarding</a> anlegen.</p></div>;
  }
  const tpl = FUNNELS[f.type];
  return (
    <div className="narrow">
      <div className="hero-lp">
        <span className="pill" style={{ background: "rgba(255,255,255,.15)", color: "#fff" }}>{tpl.label} · {f.region}</span>
        <h1 style={{ marginTop: 14 }}>{tpl.hero}</h1>
        <p>{tpl.sub}</p>
      </div>
      <div className="card" style={{ marginTop: -18, position: "relative" }}>
        <LeadForm slug={f.slug} type={f.type} cta={tpl.cta} />
      </div>
      <p className="small">Mit dem Absenden willigst du in die Kontaktaufnahme ein. Impressum und Datenschutz gelten. (Platzhalter für Rechtstexte.)</p>
    </div>
  );
}
