# Hatch Snipers – Setup

**Konzept:** Waffen-Skins sind das Sammelobjekt. Am **Omega-Gehäuse** in der
Neon-Cyber-Mythos-Lobby öffnet man Cases mit CS-Style-Spinner (Pity-System:
spätestens Pull 45 ist Legendary+ garantiert). In der **1v1-Sniper-Arena**
macht jede Waffe exakt gleichen Schaden — 100% skill-basiert; der Skin
entscheidet nur, wer der König auf dem Server ist. Dazu: **Wager-Duelle**
(Sieger nimmt den Pot), **ELO-Rangsystem** (Silber I → GLOBAL ELITE, 5v5-Portal
zeigt Rang + Rangtabelle), obere Ebene **Handelshalle** mit Live-Ticker,
**Bestenliste** und **Prime Status**.

Das Projekt ist ein [Rojo](https://rojo.space)-Projekt: der gesamte Code liegt
unter `src/`, Lobby und Arenen werden zur Laufzeit generiert.

## Schnellstart

1. `HatchSnipers.rbxlx` in Roblox Studio öffnen.
2. Game Settings → Security → **Enable Studio Access to API Services**
   (sonst speichert der DataStore in Studio nichts — zum Testen ok).
3. **Play** (F5). Du spawnst in der Neon-Lobby mit 1000 Credits → reicht direkt
   für den ersten Pull am Omega-Ei (E drücken).
4. 1v1 testen: **blaues Pad = sofort gegen den Trainings-Bot** (geht solo!),
   rotes Pad = Wager wählen → PvP-Queue (*Test → 2 Players*, beide aufs Pad;
   gematcht wird nur bei gleichem Einsatz).

## Entwicklung mit Rojo

```bash
aftman install                      # rojo 7.6.1
rojo build -o HatchSnipers.rbxlx    # Place-File bauen
rojo serve                          # oder live in Studio syncen
```

## Steuerung

- **Klick**: Schießen (One-Shot, Bolt-Action-Cooldown)
- **Rechtsklick halten**: Scope (Zoom, langsamer laufen)
- **E**: Interagieren (Omega-Ei, Daily-Terminal)
- **Rotes Pad**: 1v1-PvP — Wager wählen (0/50/100/250/500), Queue rein/raus
- **Blaues Pad**: 1v1 gegen den Trainings-Bot (reduzierte Rewards)
- **Treppe hinten**: Handelshalle (Kioske öffnen den Handelsplatz, Live-Ticker)
- **👑-Button**: Prime-Status-Menü (Gamepass-ID in Config.lua)

## Die AWP — echtes CS-Modell aktivieren (einmalig, 20 Sekunden)

**Variante A — Einzeiler (am schnellsten):** In Studio im **Edit-Modus**
(nicht während Play!) unten die **Befehlsleiste** öffnen (Ansicht →
Befehlsleiste), diese Zeile einfügen und Enter drücken:

```lua
local m=game:GetService("InsertService"):LoadAsset(13638913296):GetChildren()[1] local f=game.ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder") f.Name="Assets" f.Parent=game.ReplicatedStorage m.Name="Awp" m.Parent=f print("AWP-Template installiert ✔")
```

Danach den Platz **speichern** (Ctrl+S) — fertig für immer.

**Variante B — Toolbox:** Suche **"AWP sniper"** (ID `13638913296`),
einfügen, im Explorer nach **`ReplicatedStorage → Assets`** ziehen und
**`Awp`** nennen. Speichern.

Beim nächsten Play vermisst der Server das Modell automatisch (Größe,
Lauf-Richtung per Raycast-Probe) und baut **alle Skins** aus dem echten
texturierten AWP (Klassik-Tarn = Original-Look, Rest = VertexColor-Tints).
Im Spiel bestätigt „🔫 Echtes AWP-Modell aktiv!" den Erfolg.

> Hintergrund: Zur Laufzeit blockt Roblox `LoadAsset` für fremde Assets —
> die Befehlsleiste/Toolbox haben aber Studio-Rechte. Einmal eingefügt ist
> Mesh + Textur fest in deinem Platz gebakt. Ohne Template läuft die
> eingebaute Part-AWP als Fallback.

**Scope:** Rechtsklick = CS-Style-Overlay (kreisrundes Scope-Bild, Fadenkreuz
mit Mil-Dots, Waffe ausgeblendet, FOV 16, langsameres Laufen).
**Sound:** echte CS-AWP-Ports wenn ladbar, sonst gelayerter Knall
(Gewehr-Boom + Bass + Crack-Tail) — nie wieder dünner Peitschenklatscher.

## ⚠ Für ECHTE Texturen im Live-Spiel: Mesh-/Bild-APIs aktivieren!

Alle Skin- und Umgebungs-Texturen werden zur Laufzeit per **EditableImage**
generiert. In Studio läuft das immer — im VERÖFFENTLICHTEN Spiel blockt
Roblox die API, solange dieser Haken fehlt:

**Creator Hub → dein Spiel → Inhaltseinstellungen → APIs →
„Mesh-/Bild-APIs aktivieren" ✓** (Nutzungsbedingungen bestätigen)

Ohne den Haken sind Waffen und Boden im Live-Spiel nur eingefärbt statt
texturiert. Zusätzlich braucht das Waffen-Mesh das AWP-Template
(Einzeiler oben) — die Skin-Texturen liegen auf dem echten AWP-Modell.

## Mobile-Steuerung

Auf Touch-Geräten gibt es eigene **FEUER- (🔫)** und **SCOPE-Buttons (⊕)**
unten rechts — ein Tap auf den Bildschirm schießt absichtlich NICHT (sonst
würde jede Kameradrehung feuern). Gezielt wird über die Bildmitte
(Fadenkreuz). Im Scope wird zusätzlich die Maus-Empfindlichkeit aufs FOV
runterskaliert und in die Ego-Sicht gewechselt — kein Zappeln mehr.

## Grafik maximal stellen (wichtig gegen den "Pixel-Look"!)

Roblox rendert PBR-Materialien, weiche Schatten und Reflexionen erst auf
hohen Qualitätsstufen:

- **In Studio:** File → Studio Settings → Rendering → **Editor Quality Level:
  Level 21** und **Quality Level: Level 21**.
- **Im Spiel/Test:** Esc-Menü → Einstellungen → Grafikmodus **Manuell** →
  Regler ganz nach **rechts (10)**.

Ohne das sehen Future-Lighting, Tiefenschärfe, Glanzboden und die
Panel-/Stein-Texturen deutlich flacher aus.

**Wichtig beim Testen:** Nach jedem `git pull` die NEUE `HatchSnipers.rbxlx`
öffnen oder per `rojo serve` in deinen gespeicherten Platz syncen — alte
Platz-Kopien enthalten alten Code (die Build-Version steht unten rechts im
HUD).

## Projektstruktur

| Pfad | Zweck |
|---|---|
| `src/Shared/Config.lua` | Economy, Arena, Cooldowns, **Monetarisierungs-IDs** |
| `src/Shared/Skins.lua` | Skin-Katalog, Tiers, Drop-Gewichte, Odds-Berechnung |
| `src/Shared/SniperBuilder.lua` | Baut das Waffen-Modell pro Skin (server-seitig → alle sehen den Flex) |
| `src/Shared/Assets.lua` | Verifizierte Sound-/Musik-IDs |
| `src/Server/Services/` | Data, Egg (Hatch/Luck/Daily), Weapon (Schuss-Validierung), Arena (Queue/Match), Lobby, Trade |
| `src/Client/Controllers/` | Weapon (Input/Scope), UI (HUD/Ei/Hatch-Animation/Trade), Effects (Tracer/Puls/Flash) |

## Monetarisierung scharf schalten

In `src/Shared/Config.lua`:

- `LUCK_PRODUCT_ID` — Developer-Product anlegen ("Luck Potion"), ID eintragen.
  Kauf = 15 Minuten doppelte Chance auf Nicht-Common-Skins (stackt).
- `TRADER_PASS_ID` — Gamepass anlegen ("Trader"), ID eintragen.
  Ohne Pass: max. 3 Items pro Trade-Seite, mit Pass: 6.
- `PRIME_PASS_ID` — Gamepass "Prime Status": Exklusiv-Skin 'Prime: Ägis',
  goldene Aura, +25% ELO-Gewinn, wöchentlich 1500 Credits. Niemals stärkere
  Waffen — Matches bleiben skill-basiert.

Solange die IDs `0` sind, melden die Buttons "nicht konfiguriert" — das Spiel
funktioniert ohne Monetarisierung vollständig.

> ⚠ Roblox-Policy: Die Drop-Chancen bezahlter Zufalls-Items müssen offengelegt
> sein — die Ei-UI zeigt deshalb pro Skin die exakte Prozent-Chance (inkl.
> Luck-Boost live).

## Nächste Ausbaustufen (bewusst noch nicht drin)

- Weitere Eier (z.B. teures "Cyberpunk-Ei") — `Config.EGGS` + Katalog-Eintrag
  genügt, EggService/UI sind config-getrieben.
- Skin-Wetten in der Arena, Killstreak-Effekte, globales Leaderboard.
