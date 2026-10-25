# Brainrot Bloom

A complete source project for a Roblox collection and growth game. Everything visual is built from original Roblox parts at runtime: no Toolbox models, uploaded meshes, paid assets, or external asset IDs are required.

## Open and play

1. Download [`BrainrotBloom.rbxlx`](BrainrotBloom.rbxlx) from this repository or workspace and open it in **Roblox Studio**.
2. Press **Play**. The server creates the islands, shops, creature gallery, day/night cycle, and player data; the client creates the interface. The edit view is intentionally empty before Play.
3. Open **WORLDS**, choose **Clover Commons → TELEPORT TO PIT**, and press **E** or **DETECT** while standing in the sand.
4. Tap the capture button or press **Space** enough times within 10 seconds. Your new brainrot immediately starts earning coins.
5. Open **BAG**, select a creature, and feed it. You start with 150 coins, a Tin Twig detector, and three Suspicious Crumbs.

Use **FOOD**, **SELL**, and **GEAR** to teleport directly to each shop. **HOME** returns to the garden. Walk-up shop prompts use **F**, so they do not conflict with the detector's E key. Touch players use the on-screen buttons.

Studio is needed to actually play Roblox. This Linux cloud workspace builds the place and runs automated checks, but it cannot run the Roblox engine.

## What's included

- **21 original creatures**, three in each rarity: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret. Each has a distinct procedural silhouette and palette.
- **Feeding and levels** to level 100. Food grants XP; every level increases income and the displayed companion grows as it levels. All owned creatures earn income while you are online, including creatures you are not displaying.
- **15 foods**, from Suspicious Crumb to Secret Midnight Feast. A random six-food selection refreshes at shared five-minute boundaries. The inexpensive Crumb is always available; purchase quantities are personal to the current player session.
- **Seven detector tiers**, progressively shorter search cooldowns and higher rarity reach. Higher power also improves the weighting of rare finds. Detectors are visible tools held by the character.
- **Three worlds** with massive sand beds, green surroundings, shops, and teleport controls:

| World | Unlock cost | Minimum detector power to dig | Possible rarity ceiling |
| --- | ---: | ---: | --- |
| Clover Commons | Free | 1 | Epic |
| Sunset Sands | 8,000 | 4 | Mythic |
| Moonbloom Crater | 125,000 | 6 | Secret |

A world's rarity ceiling also requires a sufficiently strong detector. The starter Tin Twig reaches Uncommon; upgrade to reach higher tiers. Unlocking a world grants access to its detectors in the Gear Shop.

- **A ten-second capture minigame** requiring 6–30 taps depending on rarity. Failed captures award nothing. The server verifies the pit, world, time limit, tap rate, and unique session before awarding a creature.
- **Gear Shop sections** for detectors and boosts. Growth Juice doubles food XP for a chosen creature; Golden Hour doubles its income. Each lasts five minutes. The two kinds can coexist; buying an already active kind is refused without charging.
- **A sell station** with confirmation and level-based sale values. Collection capacity is 50 creatures.
- **A 12-minute day/night cycle**, night lamps, original creature previews, a following companion, and a responsive interface with 3D creature cards.
- **Server-owned purchases and rewards**, profile validation, request limits, DataStore session locks, autosave, leave/shutdown saving, and explicit Studio temporary-data fallback.

Income is earned online only. Boost clocks continue to expire while offline. There are no Robux purchases or external account requirements.

## Persistent saves

The place plays without DataStore access in Studio using temporary progress. The game warns you when this fallback is active; it does not save failed loads over existing data.

To test persistence, publish your own test experience in Studio, then enable **Game Settings → Security → Enable Studio Access to API Services**. Use a separate test experience while developing to avoid touching production data. Published Roblox servers use their normal DataStore access; they refuse a failed profile load rather than risk overwriting a collection. No Roblox cookie, API key, or other secret belongs in this repository.

## Develop and rebuild

The Rojo layout is specified by [`default.project.json`](default.project.json). You can install Rojo 7.5.1 with Aftman using [`aftman.toml`](aftman.toml), or use the tested Linux setup script:

```sh
cd /workspace/mesroblox
bash scripts/setup.sh
```

The script downloads pinned Rojo 7.5.1 and Luau 0.744 tools over verified HTTPS into ignored `.tools/`, runs the automated checks, and builds `build/BrainrotBloom.rbxlx`. Python 3, curl, and unzip must be present. Re-running it reuses installed tools.

```sh
# Check syntax, economy, and authoritative server action behavior.
python3 scripts/test.py --luau-dir .tools

# Rebuild the Studio file after edits.
mkdir -p build
.tools/rojo build default.project.json -o build/BrainrotBloom.rbxlx

# Optional: sync source to Studio through the Rojo plugin on your own machine.
.tools/rojo serve default.project.json
```

Cloud tasks already have an isolated checkout; use this checkout without creating a worktree. No background process is needed for the file-based build workflow. Rojo's optional sync server is not the Roblox game server.

| Source | Purpose |
| --- | --- |
| `src/shared/Config.luau` | Rarities, creatures, foods, prices, XP, income, worlds, detector tuning |
| `src/shared/CreatureFactory.luau` | Original procedural creature models |
| `src/server/World.luau` | Map, shops, sand pits, gallery, lighting cycle |
| `src/server/DetectorTool.luau` | Welded detector models |
| `src/server/Main.server.luau` | Profiles, saving, shops, income, validated capture sessions |
| `src/client/Main.client.luau` | HUD, shop and collection UI, teleport controls, capture presentation |

## Verification boundary

The automated suite compiles every source with the official Luau compiler, executes real economy functions, and exercises the actual server action handlers with deterministic Roblox service doubles. It checks purchases, finite quantities, capture success/failure/replays, growth, boost expiration, passive income, world progression, and save/reload behavior.

These checks do **not** render the game or connect to Roblox DataStores. Follow [`docs/PLAYTEST.md`](docs/PLAYTEST.md) in Roblox Studio for real character controls, touch layouts, multiplayer, and live saving before publishing the game to players. The built place has not been published to Roblox.
