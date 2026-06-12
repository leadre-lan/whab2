# Asset-Register (Hatch Snipers)

Alle externen Roblox-Assets leben in **`src/Shared/Assets.lua`** bzw.
`Config.lua` (Waffen-Mesh). Jede ID wurde am 2026-06-11 über die Roblox-APIs
geprüft.

## Waffen-Modell (Roblox-eigenes Gear — lädt GARANTIERT überall)

| ID | Asset | Einsatz |
|---|---|---|
| 94219391 | Gewehr-Mesh aus "Trench Warfare Shotgun" (Gear 94233344, by Roblox) | Körper aller Skins |
| 94219470 | zugehörige Holz/Metall-Textur (256×256) | Textur aller Skins |
| 94191736 / 94191778 | FireSound / PumpSound desselben Gears | garantierte Schuss-/Bolt-Sounds |

Wichtig gelernt: `InsertService:LoadAsset` darf in Live-Games nur eigene oder
Roblox-eigene Assets laden — der frühere Creator-Store-AWP schlug deshalb fehl
(Waffe ohne Textur). Jetzt rendert ein **SpecialMesh** das Roblox-eigene
Gewehr-Mesh direkt (kein LoadAsset nötig); Skins tönen die Textur per
**VertexColor**, der Klassik-Skin bleibt Original. Maße wurden offline aus der
Mesh-Datei geparst: 6.53 Studs lang, Mündung entlang −Z (dünnes hohes Ende),
das aufgesetzte Scope macht daraus die Sniper.

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
