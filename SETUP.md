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

## Das Waffen-Modell

Die Sniper basiert auf dem **texturierten Gewehr-Mesh aus Robloxs eigenem
"Trench Warfare Shotgun"-Gear** (Holzschaft + Metall, plus aufgesetztes Scope).
Roblox-eigene Assets laden in jedem Spiel garantiert — kein LoadAsset, keine
Berechtigungsprobleme. Jeder Skin tönt die echte Textur per VertexColor
(Klassik-Tarn = Original; Gold/Chrom hell-metallisch; Legendary+ dunkel-moody
mit Neon-Akzenten, Partikeln, Lichtspur und Puls). IDs in `Shared/Assets.lua`
(`Assets.WEAPON`).

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
