# Hatch Snipers – Setup

**Konzept:** Waffen-Skins sind das Sammelobjekt. Aus dem massiven **Omega-Ei**
in der Lobby-Mitte zieht man rein kosmetische Sniper-Skins (Common → Rare →
Legendary → Godly → Mythical). In der **1v1-Sniper-Arena** macht jede Waffe
exakt gleichen Schaden — 100% skill-basiert; der Skin entscheidet nur, wer der
König auf dem Server ist.

Das Projekt ist ein [Rojo](https://rojo.space)-Projekt: der gesamte Code liegt
unter `src/`, Lobby und Arenen werden zur Laufzeit generiert.

## Schnellstart

1. `HatchSnipers.rbxlx` in Roblox Studio öffnen.
2. Game Settings → Security → **Enable Studio Access to API Services**
   (sonst speichert der DataStore in Studio nichts — zum Testen ok).
3. **Play** (F5). Du spawnst in der Neon-Lobby mit 1000 Credits → reicht direkt
   für den ersten Pull am Omega-Ei (E drücken).
4. 1v1 testen: *Test → Clients and Servers → 2 Players* starten und beide auf
   das rote Queue-Pad stellen.

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
- **Rotes Pad**: 1v1-Queue rein/raus

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

Solange die IDs `0` sind, melden die Buttons "nicht konfiguriert" — das Spiel
funktioniert ohne Monetarisierung vollständig.

> ⚠ Roblox-Policy: Die Drop-Chancen bezahlter Zufalls-Items müssen offengelegt
> sein — die Ei-UI zeigt deshalb pro Skin die exakte Prozent-Chance (inkl.
> Luck-Boost live).

## Nächste Ausbaustufen (bewusst noch nicht drin)

- Weitere Eier (z.B. teures "Cyberpunk-Ei") — `Config.EGGS` + Katalog-Eintrag
  genügt, EggService/UI sind config-getrieben.
- Skin-Wetten in der Arena, Killstreak-Effekte, globales Leaderboard.
