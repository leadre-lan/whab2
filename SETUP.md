# Bamboo Slasher Simulator – Setup Guide

This document explains how to import the six Lua source files into Roblox Studio
so the game runs correctly.

---

## Prerequisites

- Roblox Studio installed and open.
- A **blank Baseplate** project (or any place; the scripts generate the world at runtime).
- `DataStoreService` must be **enabled** in Game Settings → Security → Enable Studio Access to API Services (required for DataStore to work in Studio test sessions).

---

## File Placement

| Source file | Studio location | Instance type |
|---|---|---|
| `src/Shared/Config.lua` | `ReplicatedStorage` | **ModuleScript** named `Config` |
| `src/Server/RemoteSetup.server.lua` | `ServerScriptService` | **Script** named `RemoteSetup` |
| `src/Server/BambooWorld.server.lua` | `ServerScriptService` | **Script** named `BambooWorld` |
| `src/Server/GameManager.server.lua` | `ServerScriptService` | **Script** named `GameManager` |
| `src/Client/PlayerController.client.lua` | `StarterPlayer → StarterPlayerScripts` | **LocalScript** named `PlayerController` |
| `src/Client/UIController.client.lua` | `StarterPlayer → StarterPlayerScripts` | **LocalScript** named `UIController` |

---

## Step-by-step Instructions

### 1 – Config (ModuleScript in ReplicatedStorage)

1. In the Explorer panel, right-click **ReplicatedStorage** → **Insert Object** → `ModuleScript`.
2. Rename it to `Config`.
3. Open it and **replace** the default contents with the code from `src/Shared/Config.lua`.

### 2 – RemoteSetup (must load first)

1. Right-click **ServerScriptService** → **Insert Object** → `Script`.
2. Rename it to `RemoteSetup` (or prefix it `01_RemoteSetup` if you want alphabetical ordering to guarantee it runs before the other server scripts).
3. Paste the contents of `src/Server/RemoteSetup.server.lua`.

> **Why first?** This script creates the `BambooRemotes` folder that `BambooWorld` and `GameManager` wait for with `WaitForChild`. In practice the `WaitForChild` calls handle ordering, but running it first avoids any startup delay.

### 3 – BambooWorld (Script in ServerScriptService)

1. Right-click **ServerScriptService** → `Script`, name it `BambooWorld`.
2. Paste `src/Server/BambooWorld.server.lua`.

### 4 – GameManager (Script in ServerScriptService)

1. Right-click **ServerScriptService** → `Script`, name it `GameManager`.
2. Paste `src/Server/GameManager.server.lua`.

### 5 – PlayerController (LocalScript in StarterPlayerScripts)

1. Expand **StarterPlayer** in the Explorer.
2. Right-click **StarterPlayerScripts** → **Insert Object** → `LocalScript`.
3. Rename it `PlayerController`.
4. Paste `src/Client/PlayerController.client.lua`.

### 6 – UIController (LocalScript in StarterPlayerScripts)

1. Right-click **StarterPlayerScripts** → **Insert Object** → `LocalScript`.
2. Rename it `UIController`.
3. Paste `src/Client/UIController.client.lua`.

---

## Testing in Studio

1. Press **Play** (F5) to run a local solo session.
2. The Output window should show:
   - `[RemoteSetup] BambooRemotes folder created with 3 RemoteEvents.`
   - Five `[BambooWorld] Zone N '...' generated with 25 stalks.`
   - `[BambooWorld] World generation complete.`
   - `[GameManager] Server logic ready.`
3. Your character spawns with a **Sword** tool in the backpack.
4. Equip the sword, walk up to the green bamboo in Zone 1 (**Bambushain**), and click to chop.
5. Coins accumulate in the top-left HUD. Use the **UPGRADE** button (bottom-right) to buy better swords.
6. Higher zones require a higher sword level shown on the sign above each platform.

---

## World Layout

| Zone # | Name | Platform X offset | Required Sword Level |
|---|---|---|---|
| 1 | Bambushain | 0 | 1 |
| 2 | Dunkler Hain | 120 | 5 |
| 3 | Olivenhain | 240 | 12 |
| 4 | Sandhain | 360 | 20 |
| 5 | Urwald | 480 | 30 |

Platforms are 100×100 studs, separated by 20-stud gaps.

---

## DataStore Notes

- Player data (coins, sword level, total chopped) is saved to a DataStore named `BambooSlasher_v1`.
- Data is loaded on `PlayerAdded` and saved on `PlayerRemoving`.
- An **auto-save** runs every 60 seconds for all connected players.
- In **Studio test mode** DataStore calls require the API access toggle mentioned above; without it calls silently fail and players start fresh each session (which is fine for testing).

---

## Customisation Tips

All game balance lives in `src/Shared/Config.lua`:

- Add more zones by appending to `Config.ZONES` and `Config.BAMBOO_TYPES`.
- Rebalance costs, damage, or health by editing the relevant table entry.
- Change zone spacing by adjusting the `offset` `Vector3.new(X, 0, 0)` values (keep gaps > 20 studs so platforms do not overlap).
