import "./globals.css";

export const metadata = {
  title: "LeadRE — Makler-Marketing auf Autopilot",
  description: "Komplettes Online- und Offline-Marketing für Makler, automatisiert in 10 Minuten.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="de">
      <body>
        <nav className="topnav">
          <div className="wrap">
            <a href="/" className="brand">Lead<b>RE</b></a>
            <div className="spacer" />
            <a href="/onboarding">Onboarding</a>
            <a href="/dashboard">Dashboard</a>
          </div>
        </nav>
        <main className="wrap" style={{ padding: "28px 22px 60px" }}>{children}</main>
      </body>
    </html>
  );
}
