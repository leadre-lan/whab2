# Bamboo Slasher – Setup

Das Projekt ist ein [Rojo](https://rojo.space)-Projekt: der gesamte Code liegt
unter `src/`, die Welt wird **komplett zur Laufzeit generiert** (Terrain, Hub,
Biome, Monster).

## Schnellstart (fertiges Place-File)

1. `BambooSlasher.rbxlx` in Roblox Studio öffnen.
2. Game Settings → Security → **Enable Studio Access to API Services** aktivieren
   (sonst speichert der DataStore in Studio-Sessions nichts — zum Testen ok).
3. **Play** (F5). Du spawnst in der Overworld am Torii-Portal.

## Entwicklung mit Rojo

```bash
aftman install            # installiert rojo 7.6.1 (siehe aftman.toml)
rojo build -o BambooSlasher.rbxlx   # Place-File neu bauen
# oder live in Studio syncen:
rojo serve                # + Rojo-Plugin in Studio verbinden
```

## Projektstruktur

| Pfad | Zweck |
|---|---|
| `src/Shared/Assets.lua` | **Alle externen Asset-IDs** (Meshes, SFX, Musik) — zentral austauschbar |
| `src/Shared/Layers.lua` | Biom-Definitionen (Farben, Themes, Seeds, Level-Gates) |
| `src/Shared/Balance.lua` | Alle Spielwerte (XP, Schaden, Kosten, Respawns) |
| `src/Shared/UITheme.lua` | Design-System fürs HUD |
| `src/Server/Server.server.lua` | Entry Point, Remotes, Service-Wiring |
| `src/Server/Services/` | World/Hub/Monster/Combat/Forge/Rebirth/Arena/Data |
| `src/Client/Client.client.lua` | Entry Point, Musik, Lighting, Effekt-Routing |
| `src/Client/Controllers/` | Input (Schwert/Dash/Block), UI, Effekte |

## Steuerung

- **Linksklick / Touch**: Schlagen (in der Luft + fallend = Slam)
- **Q**: Dash · **F**: Block halten · **E**: Interagieren (Portal, Schmiede, Schrein, Daily-Chest)

## Eigene 3D-Modelle (optional)

Der WorldGenerator nutzt automatisch eigene Modelle, wenn sie in Studio unter
`ReplicatedStorage/Assets/Trees` bzw. `ReplicatedStorage/Assets/Rocks` liegen
(Toolbox-Modelle einfach reinziehen). Ohne diese Ordner baut er die
prozeduralen Biom-Props — das Spiel funktioniert immer.

Details zu allen verwendeten Asset-IDs: [docs/ASSETS.md](docs/ASSETS.md).
