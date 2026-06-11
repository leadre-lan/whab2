# Asset-Register (Hatch Snipers)

Alle externen Roblox-Assets leben in **`src/Shared/Assets.lua`** bzw.
`Config.lua` (Waffen-Mesh). Jede ID wurde am 2026-06-11 über die Roblox-APIs
geprüft.

## Waffen-Modell (Creator Store, per Thumbnail-Render geprüft)

| ID | Asset | Einsatz |
|---|---|---|
| 13638913296 | "AWP sniper" (CS-Style, Olive-Textur, Scope+Bipod) | Basis aller Skins |
| 504829517 | "[L4D2] AWP" | Fallback-Modell |

Geladen via `InsertService:LoadAsset` beim Server-Start; Lauf-Achse und
Mündungsrichtung werden zur Laufzeit per Raycast-Probe bestimmt (das dünne
Ende ist der Lauf). Schlägt alles fehl → prozedurales Part-Modell.

## Sound-Effekte (ProSoundEffects / APM = offizielle Roblox-Libraries)

| Key | ID | Einsatz |
|---|---|---|
| `Shot` (bevorzugt) | 138705939667182, 131254751896361 | Echte AWP-Fire-Sounds (CS-Ports); Client testet Ladbarkeit via PreloadAsync |
| `Shot` (Fallback) | 9126213373 | Whip-Crack mit Hall (verifiziert); pro Tier gepitcht: Common dumpf → Mythical knackig |
| `Bolt` (bevorzugt) | 133852631085337, 140632128823885 | AWP Bolt-Pull/-Forward |
| `Bolt` (Fallback) | 9114004212 | Crossbow-Latch (verifiziert) |
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
