// Funnel templates + angle library. Two products: "Verkäufer finden" (seller) and "Käufer finden" (buyer).
// The agent pulls angles from these libraries, generates creatives, launches, and culls on soft KPIs.

export const FUNNELS = {
  seller: {
    type: "seller",
    label: "Verkäufer finden",
    goal: "Eigentümer-Leads (Objektakquise)",
    hero: "Was ist Ihre Immobilie heute wert?",
    sub: "Kostenlose, unverbindliche Wertermittlung für Ihre Region. In 60 Sekunden.",
    cta: "Jetzt starten",
    fields: ["name", "phone", "email", "address"],
    kpiFocus: ["hookRate", "ctr", "cpc", "cpl", "leadQuality"],
  },
  buyer: {
    type: "buyer",
    label: "Käufer finden",
    goal: "Kaufinteressenten-Leads",
    hero: "Finden Sie Ihre passende Immobilie zuerst.",
    sub: "Neue Objekte in Ihrer Region, bevor sie öffentlich gelistet werden.",
    cta: "Jetzt starten",
    fields: ["name", "phone", "email", "budget"],
    kpiFocus: ["hookRate", "ctr", "cpc", "cpl", "leadQuality"],
  },
};

// Angle library. In production this is generated + expanded by the LLM each week.
export const ANGLE_LIBRARY = {
  seller: [
    { id: "s1", kicker: "WERTERMITTLUNG", hook: "Was ist Ihre Immobilie heute wert?", note: "Neugier + kostenlos" },
    { id: "s2", kicker: "MARKTLAGE", hook: "Die Preise in {region} haben sich verändert. Wissen Sie, wo Sie stehen?", note: "Region + FOMO" },
    { id: "s3", kicker: "JETZT ODER SPÄTER", hook: "Verkaufen oder warten? Die ehrliche Rechnung für {region}.", note: "Entscheidung" },
    { id: "s4", kicker: "OHNE MAKLER-STRESS", hook: "Verkaufen ohne Besichtigungs-Chaos. So geht es 2026.", note: "Pain: Aufwand" },
    { id: "s5", kicker: "GEERBT?", hook: "Immobilie geerbt und unsicher, was jetzt? Erst den Wert kennen.", note: "Sub-Nische" },
  ],
  buyer: [
    { id: "b1", kicker: "VOR DEM MARKT", hook: "Neue Objekte in {region}, bevor sie öffentlich gelistet werden.", note: "Exklusivität" },
    { id: "b2", kicker: "FINANZIERUNG", hook: "Wie viel Immobilie können Sie sich wirklich leisten?", note: "Rechner-Hook" },
    { id: "b3", kicker: "CASHFLOW", hook: "Positiver Cashflow ab Tag 1? So finden Sie das richtige Objekt in {region}.", note: "Kapitalanleger" },
    { id: "b4", kicker: "JUNGE FAMILIE", hook: "Genug Platz für die Familie, in {region} noch bezahlbar.", note: "Familien" },
    { id: "b5", kicker: "SUCHPROFIL", hook: "Sagen Sie uns, was Sie suchen. Wir melden uns, wenn es passt.", note: "Low-friction Lead" },
  ],
};

// Fill {region} etc. into a hook string.
export function renderAngle(angle, ctx = {}) {
  return { ...angle, hook: (angle.hook || "").replace(/\{(\w+)\}/g, (_, k) => ctx[k] || `Ihrer Region`) };
}
