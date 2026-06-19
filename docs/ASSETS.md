# Asset-Register (Hatch Snipers)

Alle externen Roblox-Assets leben in **`src/Shared/Assets.lua`** bzw.
`Config.lua` (Waffen-Mesh). Jede ID wurde am 2026-06-11 über die Roblox-APIs
geprüft.

## Waffen-Modell

Die AWP ist eine **prozedurale CS:GO-Silhouette aus Parts** (skeletierter
Schaft mit Daumenloch, Receiver + Bolt, Magazin, langer Handschutz,
freiliegender Lauf mit Mündungsbremse, großes Scope mit Objektivglocke und
Türmen). Bewusst kein Mesh: LoadAsset ist in Live-Games permission-gesperrt
und SpecialMesh-Texturen waren nicht zuverlässig — Parts sehen überall gleich
aus und lassen sich pro Skin sauber einfärben (Furniture = body, Akzente =
accent, Metallteile bleiben dunkel). Der Standard-Skin trägt das klassische
AWP-Olivgrün.

## AWP-Schuss-Sound (gelayert)

Lädt einer der CS-AWP-Ports (s.u.), spielt er pur. Sonst layert der Client den
Knall aus drei garantierten/verifizierten Sounds: Gewehr-Boom 94191736
(Roblox-Gear-FireSound) + Deep-Boom 9125404320 + Whip-Crack-Tail 9126213373.

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
