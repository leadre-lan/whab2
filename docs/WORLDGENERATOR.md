# WorldGenerator — Schichten per Config hinzufügen

`src/Server/Services/WorldGenerator.lua` generiert eine komplette Schicht aus einer
Config: Terrain (Perlin-Noise-Heightmap über die Roblox Terrain-API), organisches
Prop-Scattering (Cluster + Lichtungen, nie Reihen), 2–3 Landmarks (See, alter Baum,
Felsformation), unsichtbare Grenzen (Terrain steigt am Rand zu Klippen an, Fog endet
davor) und einen Spawn-Punkt (geebnetes Zentrum).

## Neue Schicht generieren lassen

In `src/Shared/Layers.lua` beim gewünschten Layer einfach einen `gen`-Block ergänzen —
mehr ist nicht nötig, `WorldService` erkennt das automatisch:

```lua
[2] = {
    name          = "Goldener Hain",
    requiredLevel = 2,
    offsetX       = 10000,          -- Schichten liegen 5000 Studs auseinander!
    bambooColor   = ...,            -- (bestehende Felder)
    ...
    -- Lighting-Preset (Client wendet es beim Teleport an):
    lighting = {
        clockTime   = 16.5,                          -- Tageszeit
        atmoDensity = 0.45,                          -- dichter = mystischer
        atmoColor   = Color3.fromRGB(220, 195, 130), -- Atmosphären-Färbung
    },
    -- WorldGenerator-Config:
    gen = {
        seed         = 47110815,             -- fester Seed = reproduzierbare Welt
        size         = 900,                  -- Studs, mind. 800
        material     = Enum.Material.Sand,   -- Terrain-Material des Bioms
        bambooCount  = 100,                  -- interaktiver Bambus
        oreCount     = 18,                   -- Erz-Spots (60% an der Felsformation)
        treeCount    = 80,                   -- Deko-Bäume
        boulderCount = 30,                   -- Deko-Felsen
    },
},
```

Beim nächsten Serverstart wird die Schicht generiert:

- **Terrain:** sanfte Hügel/Senken aus zwei Noise-Oktaven, Spawn-Pad im Zentrum
  geebnet, Rand steigt quadratisch zu ~110 Studs hohen Klippen an.
- **Interaktiv:** Bambus-Spots (mit Scale 0.8–1.3x + Zufallsrotation) und Erz-Spots
  werden an `WorldService` zurückgegeben, das dort die schlagbaren Objekte baut.
- **Monster-Camps:** 4 Positionen an den Landmarks → `MonsterService` spawnt dort.
- **Teleport:** `HubService` nutzt automatisch den generierten Spawn-Punkt
  (`WorldService.getLayerSpawn(layerIdx)`).

## Regeln

1. `offsetX` immer in 5000er-Schritten — Schichten dürfen sich nie sehen
   (Teleport-only, StreamingEnabled übernimmt das Laden/Entladen).
2. Fog (`fog.finish` im Layer) muss **kleiner** sein als die Distanz Spawn→Klippen
   (bei size=900 beginnen die Klippen ~310 Studs vom Zentrum) — der Spieler darf
   den Weltrand niemals sehen.
3. Seed nie ändern, wenn die Welt gleich bleiben soll — gleicher Seed = gleiche Welt.
4. Layer ohne `gen`-Block bekommen weiterhin die Part-basierte Insel (Fallback).
