export default function Home() {
  return (
    <div className="narrow">
      <h1>Dein Makler-Marketing auf Autopilot.</h1>
      <p className="sub">
        Verbinde Domain und Meta, wähle deine Region, und der LeadRE Agent baut deine Funnel für
        <b> Verkäufer</b> und <b>Käufer</b>, testet jede Woche neue Angles, skaliert Winner, killt Loser
        und schickt dir jeden Morgen einen Bericht per SMS. In 10 Minuten aufgesetzt.
      </p>
      <div className="card">
        <h2>So funktioniert es</h2>
        <div className="step"><div className="n">1</div><div><b>Onboarding (10 Min)</b><div className="muted">Domain verbinden, Meta verbinden, Region angeben.</div></div></div>
        <div className="step"><div className="n">2</div><div><b>Agent baut die Funnel</b><div className="muted">Verkäufer finden und Käufer finden, komplett automatisiert.</div></div></div>
        <div className="step"><div className="n">3</div><div><b>Wöchentliches Testen</b><div className="muted">Neue Angles und Creatives, Soft-KPI-Tracking, Auto-Skalierung.</div></div></div>
        <div className="step"><div className="n">4</div><div><b>Leads und Berichte</b><div className="muted">CRM im Backend, täglicher Morgen-Bericht per SMS.</div></div></div>
      </div>
      <a href="/onboarding" className="btn gold">Jetzt starten →</a>
    </div>
  );
}
