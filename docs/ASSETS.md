# Asset-Register (Hatch Snipers)

Alle externen Roblox-Assets leben in **`src/Shared/Assets.lua`**. Jede ID wurde
am 2026-06-11 über die Roblox-APIs verifiziert (Typ korrekt + öffentlich
abrufbar). Waffen-Modelle sind bewusst prozedural (Parts), damit Skins frei
einfärbbar sind und nichts an Moderation/Privacy scheitern kann.

## Sound-Effekte (ProSoundEffects / APM = offizielle Roblox-Libraries)

| Key | ID | Einsatz |
|---|---|---|
| `Shot` | 9126213373 | Schuss (Whip-Crack mit Hall; pro Tier gepitcht: Common dumpf → Mythical knackig) |
| `Bolt` | 9114004212 | Bolt-Action-Klack nach dem Schuss |
| `Magazine` | 9113104176 | Skin-Equip |
| `EggCrack` / `EggCrack2` | 9113959337 / 9113959539 | Hatch-Animation |
| `DrumRoll` | 1846418712 | Hatch-Spannung |
| `Chime` / `ChimeSoft` | 9116395089 / 9116394876 | Reveal, Sieg / UI, Hit-Marker |
| `Coin` | 9113848490 | Credits/Daily |
| `Teleport` | 9116394545 | Arena-Teleport |

## Musik (DistrokidOfficial / APMOfficial = lizenzierte Roblox-Library)

| Gruppe | Tracks |
|---|---|
| Lobby (Synthwave) | 139180277700549 (Calm Retro Wave), 140487226538429 (Dreams Across the Skyline) |
| Arena (treibend) | 117068758599157 (auraincrease), 1843819038 (Moving Drone 60) |

## Wichtige Erkenntnis zu User-Audio

Sniper-/Gun-Sounds normaler User sind seit Robloxs Audio-Privacy-Update fast
immer **privat** — sie erscheinen zwar in der Toolbox-Suche, laden aber in
fremden Spielen nicht. Deshalb ausschließlich IDs aus Robloxs eigenen
Libraries (per Download-Check verifiziert).

## Partikel

Nur eingebaute `rbxasset://`-Texturen (sparkles/smoke/fire) — immer verfügbar.
