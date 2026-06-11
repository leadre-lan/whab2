# Asset-Register

Alle externen Roblox-Assets des Spiels leben in **`src/Shared/Assets.lua`**.
Jede ID wurde am 2026-06-11 über die Roblox-APIs verifiziert (Asset-Typ korrekt
und öffentlich abrufbar). Zum Austauschen: nur die ID in `Assets.lua` ändern —
kein Service-Code nötig.

## Meshes (Schwerter)

| Key | Asset | Creator | Verwendung |
|---|---|---|---|
| `ClassicSword` | `12221720` (sword.mesh) + `rbxasset://textures/SwordTexture.png` | Roblox | Schwert-Tiers 1–4 (per VertexColor getönt) |
| `Katana` | `11442510` (Katana Mesh) + `11442524` (Katana Texture) | Roblox | Schwert-Tiers 5–10 + Monument im Hub |

Die Maße (`length`, `handleZ`) wurden direkt aus den Mesh-Dateien geparst:
Klinge liegt bei beiden entlang **+Z**, daher die −90°-X-Rotation beim Weld in
`InputController.buildSword`.

## Sound-Effekte (ProSoundEffects = offizielle Roblox-SFX-Library)

| Key | ID | Einsatz |
|---|---|---|
| `Swing` | 9126284532 | Schwert-Whoosh, Slam (tiefer), Dash |
| `Slice` | 9116333867 | Bambus-Schnitt |
| `RockHit` / `RockBreak` | 9118627392 / 9125869797 | Stein-Treffer / -Bruch |
| `Anvil` | 9113446174 | Schmiede-Craft |
| `MonsterHit` / `MonsterDeath` | 9113980480 / 9113988071 | Monster-Treffer / -Tod |
| `Chime` / `ChimeSoft` | 9116395089 / 9116394876 | Level-Up, Rebirth / Schicht-Unlock |
| `Coin` | 9113848490 | Coin-Popup, Daily-Reward |
| `Teleport` | 9116394545 | Portal / Hub-Teleport |

## Musik (DistrokidOfficial / APMOfficial = lizenzierte Roblox-Musik-Library)

| Gruppe | Tracks |
|---|---|
| Hub | 89453444795932 (Koi Fish Dream), Fallback 9043887091 |
| Forest (Schicht 1–2) | 98002463968288 (Forest Calm Ambient), 119364922573470 (Cherry Blossoms), Fallback 1843463175 |
| Mystic (3–4) | 106152951949961, 73731220283940 (APM Mysterious), Fallback 1843463175 |
| Epic (5–6) | 130204756191999, 113554213644551, Fallback 9046515361 |

> Hintergrund: 4 der früheren Musik-IDs (9046863017, 9046896990, 9045766818,
> 9046897116) existieren nicht mehr auf Roblox — deshalb lief in mehreren
> Biomen nur noch der Fallback-Track. Diese Liste ersetzt sie vollständig.

## Partikel

Nur eingebaute `rbxasset://`-Texturen (sparkles/smoke/fire) — immer verfügbar,
kein Moderations-/Lade-Risiko.

## Warum keine Toolbox-Modelle (.rbxm) im Repo?

Model-Downloads über die Asset-Delivery-API erfordern einen eingeloggten
Roblox-Account — aus der CI/Cloud heraus sind nur Meshes/Texturen/Audio der
offiziellen Bibliotheken zuverlässig verifizierbar. Deshalb:

- Schwerter & Monument: offizielle Classic-Meshes (siehe oben)
- Welt-Props: prozedural pro Biom-Theme (`WorldGenerator.lua`), mit
  Template-Hook — eigene Toolbox-Modelle in `ReplicatedStorage/Assets/Trees`
  bzw. `/Rocks` werden automatisch bevorzugt.
