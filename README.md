# Brainrot Bloom

A complete source project for a Roblox collection and growth game. All visuals are made from original Roblox parts: no Toolbox models, uploaded meshes, paid assets, or external asset IDs are required.

## Open and play

1. Download [`BrainrotBloom.rbxlx`](BrainrotBloom.rbxlx) from this repository or workspace and open it in **Roblox Studio**.
2. The complete map is already visible in Studio’s edit view. Press **Play** to start the UI, day/night cycle, player data, personal gardens, and gameplay. The server refreshes the scenery on startup.
3. Follow the turquoise ground arrows to the **World portal** on the main avenue between the village and sand pit and press **F** (or tap its prompt), then choose your destination. To begin collecting, choose **Clover Commons → Travel to sand pit**, and press **E** or **Dig** while standing in the sand. Each scan takes one second and has a 50% chance to find a signal; empty searches are normal.
4. Tap the capture button or press **Space** enough times within 10 seconds. Your new brainrot immediately starts earning coins.
5. Open **Collection** (or **Bag** on mobile), select a creature, and feed it. You start with 150 coins, a Tin Twig detector, and three Suspicious Crumbs.

Use the left-side dock for **Collection**, **Food**, **Sell**, **Gear**, **Index**, and **Garden**. Index opens the discovery book; Garden manages your personal displays. Use **FOOD**, **SELL**, and **GEAR** to teleport directly to each shop. **HOME** returns to the garden. Walk-up shop prompts use **F**, so they do not conflict with the detector's E key. Touch players use the on-screen buttons. Hold **Shift** to sprint on keyboard, click **L3** to toggle sprint on a controller, or use the touch **Sprint** button. Sprint stops when opening a menu or starting a capture. Characters use classic **R6** rigs. Equip your detector from the Roblox hotbar to show the **Dig** button and detector/world status; putting it away hides both. The E shortcut starts a search only while the detector is equipped.

Studio is needed to actually play Roblox. This Linux cloud workspace builds the place and runs automated checks, but it cannot run the Roblox engine.

## What's included

- **28 individually sculpted creatures** with different anatomy: sliced toast, a pasta planter, a squat frog, a segmented bee, a full shark in slippers, curled tentacles, four-legged lion/dragon/capybara, a crescent moon, and robed wizard/emperor. New designs include a butter croissant, coiled snail, porcelain teapot, terrarium turtle, golden koi, pocketwatch, and astral manta. Each has tailored face placement, limbs, accessories, and layered construction. Four in each rarity: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret. Each has a distinct procedural silhouette and palette.
- **Feeding and levels** to level 100. Food grants XP; every level increases income and the displayed companion grows as it levels. All owned creatures earn income while you are online, including creatures you are not displaying.
- **15 foods**, from Suspicious Crumb to Secret Midnight Feast. A random six-food selection refreshes at shared five-minute boundaries. The inexpensive Crumb is always available; purchase quantities are personal to the current player session.
- **Seven detector tiers**, progressively shorter search cooldowns and higher rarity reach. Higher power also improves the weighting of rare finds. Detectors are visible tools held by the character.
- **Three expanded worlds**: each island is 700 × 660 studs (four times the original area), with 320 × 280 sand pits, continuous natural rock boundaries, recessed excavation basins, stone steps, rope fences, survey carts, crates, lanterns, shops, and physical world portals. Mossy chalk cliffs enclose the green valley; warm sandstone walls enclose the ochre canyon; turquoise slate and lilac crystal groves enclose the cove. The garden neighborhood has its own escarpment and an open rock-framed bridge route. The hub has a fountain plaza, gabled markets with stocked shelves, and a trading scale. The public specimen showcase has been removed; the six personal gardens remain available for players’ own displays. Each world has its own terrain and landmarks: a terraced orchard and brook in Clover Commons, layered mesa trails and a mining camp in Sunset Sands, and raised mineral shelves and a crystal grotto in Moonbloom Cove. Walkable stairs and trails connect the different elevations while the sand pits remain clear:

| World | Unlock cost | Minimum detector power to dig | Possible rarity ceiling |
| --- | ---: | ---: | --- |
| Clover Commons | Free | 1 | Epic |
| Sunset Sands | 8,000 | 4 | Mythic |
| Moonbloom Cove | 125,000 | 6 | Secret |

A world's rarity ceiling also requires a sufficiently strong detector. The starter Tin Twig reaches Uncommon; upgrade to reach higher tiers. Unlocking a world grants access to its detectors in the Gear Shop.

- **A server-timed one-second search** with a 50% find chance. An empty search gives feedback without starting a capture or awarding a creature. Detector recharge applies to both outcomes. Moving out of the pit, teleporting, respawning, or leaving cancels a pending search.
- **A ten-second capture minigame** after a successful search, requiring 6–30 taps depending on rarity. Failed captures award nothing. The server verifies the pit, world, time limit, tap rate, and unique session before awarding a creature.
- **Gear Shop sections** for detectors and boosts. Growth Juice doubles food XP for a chosen creature; Golden Hour doubles its income. Each lasts five minutes. The two kinds can coexist; buying an already active kind is refused without charging.
- **A sell station** with confirmation and level-based sale values. Collection capacity is 50 creatures.
- **A 12-minute day/night cycle**, night lamps, original creature previews, and a following companion. Physical signs replace floating map pins.
- **Keyboard, controller, and touch sprint controls** with fixed server-selected walk/sprint speeds and reset on respawn. Classic **R6** is saved in the place settings; gameplay scripts do not write protected avatar settings.
- **A Builder Sans field-journal interface** with cream paper, sage accents, illustrated world postcards, vector navigation icons, rarity-tinted sculpture stages, food tokens, readable detector stats, larger touch targets, gentle transitions, a navigation dock along the left side, centered vertically, Index/Garden icons to the left of their labels, searchable/sortable collection cards, rarity filters, and 12-creature pagination. The capture sheet previews the actual creature.
- **Server-owned purchases and rewards**, profile validation, request limits, DataStore session locks, autosave, leave/shutdown saving, and explicit Studio temporary-data fallback.

Income is earned online only. Boost clocks continue to expire while offline. There are no Robux purchases or external account requirements.

## World portals

Every world has a large circular **World portal** on the main avenue between the village and sand pit. Follow the turquoise ground arrows; signs label the gate from both sides, and the garden approach points toward it. Three spiral arms rotate inside the stone ring, sparks orbit in the opposite direction, and the glow pulses gently. Press **F** or tap the prompt to choose a world. Unlocked worlds offer travel; locked worlds show their cost and detector requirement.

Portal motion runs locally at up to 30 updates per second and pauses beyond 350 studs from the camera. The static gate and spiral remain visible in Studio’s edit view; press Play for animation and travel.

The three shop stations now have original characters: **Chef Pip** at Food, **Milo the Mechanic** at Gear, and **Tessa the Trader** at Sell. Their F prompts open the existing station menus. They use anchored, nonblocking scenery geometry and physical name plaques.

## Index book and personal gardens

- **Index (I)** records all 28 species with rarity progress, silhouettes for undiscovered brainrots, and world/detector hints. Discoveries stay recorded after selling a creature. Existing saves seed the book from currently owned creatures; species sold before this feature existed cannot be reconstructed from the old capture total.
- **Garden (G)** opens your personal layout. Each server has **six gardens**, and each player is assigned one on arrival. The neighborhood is connected to Clover Commons by a bridge; players can walk around and visit one another.
- Each garden has **six display pads**. New captures fill empty pads automatically until all six are occupied. Choose a slot in Garden to place, move, or clear one of your owned brainrots. Clear removes the display only; selling removes that creature from its pad. Feeding updates its displayed size.
- Discoveries and display choices save alongside the collection. Physical plot numbers are reassigned between servers, so you always receive an available plot with your saved arrangement. Every owned brainrot still earns income; displaying it does not duplicate its income.

The place file is configured with a **six-player maximum**, and the server reserves a garden before loading a profile, refusing extra joins if all six are occupied. When publishing/updating an existing Roblox experience, also set the place's **Maximum Players to 6** in Roblox's place settings so matchmaking uses six-player servers. This repository update does not change the live Creator Dashboard settings or publish the experience. The downloaded place also saves **Avatar Type: R6**. When updating an existing published experience, set its Avatar Type to **R6** in Studio’s Avatar/Game Settings so the experience uses the same rig setting.

## Persistent saves

The place plays without DataStore access in Studio using temporary progress. The game warns you when this fallback is active; it does not save failed loads over existing data.

To test persistence, publish your own test experience in Studio, then enable **Game Settings → Security → Enable Studio Access to API Services**. Use a separate test experience while developing to avoid touching production data. Published Roblox servers use their normal DataStore access; they refuse a failed profile load rather than risk overwriting a collection. No Roblox cookie, API key, or other secret belongs in this repository.

## Develop and rebuild

The Rojo layout is specified by [`default.project.json`](default.project.json). You can install Rojo 7.5.1 with Aftman using [`aftman.toml`](aftman.toml), or use the tested Linux setup script:

```sh
cd /workspace/mesroblox
bash scripts/setup.sh
```

The script downloads pinned Rojo 7.5.1, Luau 0.744, and Lune 0.11.1 tools over verified HTTPS into ignored `.tools/`, runs the automated checks, assembles and validates the actual map with native Roblox datatypes, and saves the map into both `BrainrotBloom.rbxlx` and `build/BrainrotBloom.rbxlx`. Python 3, curl, and unzip must be present. Re-running it reuses installed tools.

```sh
# Check syntax, economy, and authoritative server action behavior.
python3 scripts/test.py --luau-dir .tools

# Rebuild the Studio file, including the editor-visible map, after edits.
bash scripts/setup.sh

# Optional: sync source to Studio through the Rojo plugin on your own machine.
.tools/rojo serve default.project.json
```

Cloud tasks already have an isolated checkout; use this checkout without creating a worktree. No background process is needed for the file-based build workflow. Rojo's optional sync server is not the Roblox game server.

| Source | Purpose |
| --- | --- |
| `src/shared/Config.luau` | Rarities, creatures, foods, prices, XP, income, worlds, detector tuning |
| `src/shared/CreatureFactory.luau` | Original procedural creature models |
| `src/server/World.luau` | Themed terrain, shops, sand pits, world portals, lighting cycle |
| `src/server/PortalFactory.luau` | Circular travel gates and animated effect metadata |
| `src/server/StationKeeper.luau` | Chef, mechanic, and trader characters with shop prompts |
| `src/client/PortalEffects.client.luau` | Portal swirls, orbiting sparks, pulse, and distance culling |
| `src/server/DetectorTool.luau` | Welded detector models |
| `src/server/GardenService.luau` | Six garden plots, ownership, display models and cleanup |
| `src/server/Main.server.luau` | Profiles, saving, shops, income, validated capture sessions |
| `src/client/Main.client.luau` | HUD, shop and collection UI, teleport controls, capture presentation |
| `src/client/Sprint.client.luau` | Keyboard, controller, and touch sprint input |
| `src/server/Sprint.server.luau` | Validated sprint requests and character speed lifecycle |

## Geometry previews

[Creature sculpture contact sheet](docs/creature-geometry-preview.png) · [Six gardens](docs/garden-geometry-preview.png) · [Village detail](docs/village-geometry-preview.png) · [Clover Commons](docs/meadow-geometry-preview.png) · [Sunset Sands](docs/dunes-geometry-preview.png) · [Moonbloom Cove](docs/cove-geometry-preview.png)

[Meadow terrain](docs/meadow-terrain-preview.png) · [Canyon terrain](docs/canyon-terrain-preview.png) · [Crystal grotto](docs/grotto-terrain-preview.png)

These previews are drawn from the generated Parts’ actual positions and rotations. They are **offline geometry renders**, not Roblox Studio screenshots: materials, transparency, fonts, lighting, and vegetation scatter may differ in the engine.

To regenerate them with the optional NumPy/Pillow preview dependencies installed:

```sh
.tools/lune run scripts/scene_export.luau build/BrainrotBloom-preview.rbxlx --geometry
python3 scripts/render_preview.py
```

The scene exporter uses deterministic preview randomness for scattered vegetation. Hand-authored landmark/creature transforms are the source transforms. It checks for non-finite transforms (including vertical look-at rotations) and bounds geometry budgets; it does not emulate Roblox networking or physics.

## Verification boundary

The automated suite compiles every source with the official Luau compiler, executes real economy functions, and exercises the actual server action handlers with deterministic Roblox service doubles. It checks purchases, finite quantities, capture success/failure/replays, growth, boost expiration, passive income, world progression, and save/reload behavior. The garden tests cover six concurrent owners, seventh-join refusal, saved placements/discovery history, and disconnect/save-retry cleanup. Sprint checks execute the actual server and client scripts together for fixed speeds, malformed requests, all three input methods, UI cancellation, death, and respawn. It also executes every creature factory, the actual expanded map builder with the restricted Workspace-write guard, and client UI flows at seven mocked viewport sizes, including left-side dock bounds and detector equipment visibility through tool swaps, death, and respawn. Portal animation checks cover rotation, pulses, rate limiting, distance culling, late replication, and scene cleanup. UI mocks do not validate real layout or rendering. The build also executes every sculpture and the map using native Roblox datatypes and reflected Instances via Lune, validates finite transforms, confirms pit alignment and the saved R6 setting, checks the new stair rises, landing heights, terrace surfaces, portal effects metadata, and station attendants, and bakes the editor-visible scene.

These checks do **not** render the game or connect to Roblox DataStores. Follow [`docs/PLAYTEST.md`](docs/PLAYTEST.md) in Roblox Studio for real character controls, touch layouts, multiplayer, and live saving before publishing the game to players. The built place has not been published to Roblox.
