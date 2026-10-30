# Studio acceptance pass

These engine checks remain to be performed in Roblox Studio. Automated CLI checks are not a substitute for this pass.

1. Open the built `BrainrotBloom.rbxlx` and press Play. Confirm three islands, a green hub, trees, sand pits, shops, a held detector, and no errors in Output. If save APIs are unavailable, confirm the explicit temporary-progress warning and that the game still plays.
2. Use the World portal near the entrance to travel to Clover Commons. Walk onto and out of the sand: E/DETECT should only start a capture on the sand. Verify ground collision, jumping, walking, respawn, and HOME.
3. Complete a capture using Space, then another with the touch/mouse button. Let one expire and verify it awards nothing. Teleporting out must prevent capture rewards; rapid duplicated requests must not duplicate a reward.
4. Verify BAG shows the real name, rarity, level, XP, and income. Display different creatures, feed one or all foods, and confirm level-ups increase income and model size. A second creature should keep earning while the first is displayed.
5. Teleport to FOOD, buy different quantities, verify coins/stock/pantry counts, and wait for a five-minute rotation. Walk-up F prompts should open the same shops.
6. Verify GEAR has Detectors and Boosts. Buy and equip a detector, inspect its held model, and verify its shorter scan cooldown. Buy each boost for a chosen creature; verify only that creature's XP/income doubles, five-minute expiration works, and a duplicate purchase is refused without charging.
7. Earn enough coins, unlock Sunset Sands then Moonbloom Cove, and verify their detector requirements and expanded rarity ceilings. A locked destination must refuse teleporting. Rare/Mythic/Secret are probability-based finds; no particular number of searches guarantees one.
8. SELL should show the level-dependent value and require confirmation. Verify the creature disappears once, its income stops, and the displayed companion changes if necessary.
9. In Studio's Device Emulator, check phone portrait, phone landscape, and tablet views. Open every page, scroll a full collection and food list, and complete the tap minigame without clipped buttons. Keyboard E must not double-trigger the F proximity prompts.
10. Use **Test → Start** with two players. Confirm inventories, coins, boosts, and sales are independent. Rotation contents should match, but one player's purchases should not remove the other player's stock. Capture taps must not affect the other player's capture.
11. Run through a full 12-minute lighting cycle and confirm nighttime readability around pits and paths.
12. In a published private test experience, verify live persistence: buy food, capture/feed a creature, upgrade a detector, unlock a world, leave, and rejoin. Confirm everything reloads. Resetting the character must retain progress. Verify a second live session cannot overwrite the first session's collection.

For tuning, use `src/shared/Config.luau`; keep game rewards and purchases on the server. No debug money grant or save-wipe endpoint is shipped.

## Visual update checks

- Verify the 700 × 660-stud islands and 320 × 280 sand pits have solid ground, clear digging areas, and working world teleports. Check the pond, outer trails, ruins, and crystals without getting stuck.
- Check the physical shop/world signs are readable nearby and no floating destination panels cover the scenery.
- Inspect all 28 creatures in the collection and as companions. Check fine details remain attached when models grow, and each preview frames the whole creature.
- Search/filter/sort a full collection; move through the 12-creature pages and open/feed/sell the selected creature. Confirm the scroll position stays comfortable after feeding.
- Verify the Builder Sans text and muted colors are readable at phone sizes. Switch directly between pages using the left-side dock, including phone landscape. Complete a capture using the new creature preview sheet.

## Sculpture and scenery pass

- Before Play, confirm the complete map is visible in the downloaded place. Press Play and confirm the server refreshes it once, with one BrainrotWorld and no public rarity showcase. Personal garden displays must still work.
- Inspect distinct body shapes: the frog’s four legs, shark’s long body/slippers, capybara’s muzzle/four feet, wizard’s robe, moon’s crescent, octopus’s curled tentacles, and bee’s abdomen/wings. Check all species at both level 1 and high levels. Native build validation checks finite transforms; Studio still needs to check materials and appearance.
- Walk the sunken pit entrance steps and all landmark trails. Check the windmill, pond bridge stairs, oasis paths, observatory entrance, shop counters and trading post without blocked teleports or trapping collisions.
- Verify the cream/sage journal UI contrast in daylight and at night; inspect the illustrated world cards, sculpture stages, food tokens, detector stats, and complete a capture on a phone.
- Confirm the full creature remains in frame in portrait and landscape viewports, including broad wings and tall hats. The camera now responds to the viewport aspect ratio.

## Delayed searches and empty finds

- Click Dig in the pit. Confirm “Scanning…” stays visible for approximately one second. Some searches should report no signal, while successful searches open the capture challenge. The chance is 50% per scan, not alternating guaranteed results.
- Confirm an empty scan adds no creature/discovery, opens no capture sheet, and still consumes the detector's recharge. Successful scans must give the full ten-second capture period after the search delay.
- Try repeated clicks during a scan, switch detectors, leave the sand, teleport, reset the character, and leave/rejoin. Pending searches must not produce late captures or extra rewards after cancellation.

## Index and six-player gardens

1. Start a Studio server with six players. Each must spawn facing inward in a different claimed garden. Inspect all six ownership signs. Verify a seventh connection is refused without stealing a plot, and that the published place setting is Maximum Players 6.
2. Open Index (I): undiscovered species show silhouettes and ???. Capture a species, confirm it unlocks the entry, then sell it and confirm it remains discovered. Capturing a duplicate must not increase the unique count.
3. Open Garden (G), place/move/clear your own creatures across six pads, then feed a displayed creature and inspect the new size. Clearing a pad must keep the creature in the collection. Selling a displayed creature must remove only its display. Total passive income must not double.
4. Walk to another player's garden, inspect their models, and try their F prompts. Your UI should identify it as another garden; forged assignment payloads must not change its slots. Garden teleport must always take you to your own plot.
5. Leave/rejoin the same experience. Discovery history and pad arrangement should reload even when a different physical plot is assigned. Leave a fully decorated garden and confirm its models/sign clear before another player receives it.
6. On phone portrait and landscape, check the new Index/Garden shortcuts, rarity filters/progress, six slot selectors, species chooser, and collection's Place in garden action. The shortcuts should not cover the coin HUD.
7. Simulate a load failure or disconnect during load: the reserved plot must be released, temporary Studio progress must not overwrite a save, and a late load must not reclaim another player's reassigned plot.

## World portal travel

- Verify there is no permanent Worlds HUD button. Approach the glowing gate near the entrance in all three worlds and use F / the mobile prompt to open Choose a world.
- Check unlocked travel, locked-world costs, return travel to Clover Commons, and closing the menu without traveling. Confirm gates are easy to find from each sand-pit arrival and do not overlap the shop approaches.


## Enclosed worlds, R6, and sprint

- Open the new place and verify **Avatar Type: R6** in Studio’s avatar settings. Press Play with an account normally using R15; confirm the character has Torso, Left Arm, Right Arm, Left Leg, Right Leg, Head and HumanoidRootPart, and its Humanoid.RigType is R6. Reset and verify the same rig, garden spawn, held detector, walking animation, jumping, and camera controls. When updating a published experience, also save R6 in that experience’s avatar settings.
- Walk around every edge of all three maps. The natural rock walls should meet without escape gaps, leave the whole pit unobstructed, and retain the garden bridge opening in Clover Commons. Walk through the stone-framed garden corridor in both directions and visit all six plots.
- Inspect the new sage valley/chalk cliff, ochre sandstone canyon, and turquoise/lilac Moonbloom Cove palettes. The cove should use crystal groves instead of trees, have visible faceted crystal tips, shallow water, and an accessible viewing pier. Check walls and pathways in daylight and at night.
- Hold/release Shift on keyboard; click L3 twice on a controller; toggle Sprint on a touch device. Confirm walking returns immediately after release or toggling off, opening a menu, focusing a text box, losing window focus, dying, and respawning. Sprint must not conflict with jump, detect, shop prompts, or the capture challenge.
- Check the refined HUD on phone portrait, landscape, tablet, and desktop. Keep coin/income values, navigation, garden/index shortcuts, and the touch Sprint button clear of Roblox’s movement/jump controls.


## Terrain depth and side navigation

- Confirm the public rarity showcase, specimen plinths, and showcase sign are gone. The six personal gardens and their display pads must remain intact.
- Explore every new elevated route: meadow orchard/brook trails, canyon mesa/mining trails, and cove mineral shelves/grotto. Walk up and down each route with a normal R6 character and without sprint or jumping. Check stair lips, platform joins, headroom, and that scenery does not block the digging sand.
- Check the terrain from ground level as well as an elevated lookout: the worlds should have different silhouettes, materials, scenery, and landmarks. Confirm doors, portals, garden bridge, shops, and world arrival locations remain accessible.
- In portrait, landscape, tablet, and desktop sizes, confirm Collection/Food/Sell/Gear/Index/Garden sit together along the left side, around the vertical middle. Index and Garden must show each icon to the left of its label, with no overlap or padding shift. Open every menu and complete a capture; dock controls must not cover modal titles, close buttons, or touch targets.
- Find the seven new species across the seven rarity tiers. Check all 28 species in the index, collection previews, following companion, and personal gardens; feed a new species, sell it, and confirm discovery history remains saved.


## Prominent portals and station characters

- From the gardens, follow the direction sign through the village and then the turquoise arrows to the large circular portal. Confirm the gate sits directly on the main avenue in every world, is labeled from both sides, and leaves the route to the sand unobstructed.
- Press Play and watch all three spiral arms rotate, sparks orbit in the opposite direction, and the light pulse gently. Travel between worlds, move far away and return, and reset the character. Effects should recover without duplicate animation or errors. Edit mode shows the static spiral.
- Inspect Chef Pip behind the Food counter, Milo the Mechanic behind Gear, and Tessa the Trader at the trading post. Verify their face, outfit, name plaque, and F prompt. Food must open the food market, Gear the detector/boost shop, and Tessa the sale menu.
- Confirm the characters do not collide with players, portal effects do not block walking, and both NPC and portal prompts are reachable on keyboard and touch. Buy, feed, equip, boost, sell, and travel once to check existing gameplay still works.


## Equipped detector HUD and left-side dock

- Equip a detector from the Roblox hotbar: Dig and the detector/world status must appear. Put it away, switch to another tool, or remove it: both must immediately disappear. Owning a detector in the Backpack alone must not show its HUD or allow E to start a search.
- With the detector held, open and close every menu. Detector controls must stay hidden while a page or capture challenge is open, then return only if the tool remains equipped. Complete a capture after putting the detector away; the challenge may finish, but detector controls must remain hidden afterward.
- Die/reset while holding a detector, then respawn and equip again. Check the old character cannot leave stale controls visible or prevent the new detector from working.
- Check the centered left navigation dock in desktop, portrait, tablet, and narrow landscape views. All six controls need readable labels and icons on their left. Keep the coin display, Roblox thumbstick, touch Sprint, and Dig controls clear; short screens use a compact two-column dock.
- Open a menu on each screen size and verify the dock cannot cover or intercept its title, close button, content, or scrolling.


## Model and interface finishing pass

- Inspect all 28 species in the collection, as a following companion, and on a garden pad at low and high levels. Check connected shark/slipper anatomy, koi tail and body scales, turtle shell plates, wizard robe/beard, and manta wing roots. Small eye and accessory details must remain attached when growing.
- Equip all seven detector tiers. Check the hollow coil, grip ridges, tuning dial, and signal screen; stronger tiers should show a broader loop and additional windings. Walk, sprint, jump, unequip, and upgrade while wearing R6: tool details must follow the handle without affecting movement.
- Inspect the chef’s hat, mechanic’s goggles, trader’s scarf, boots/hands, and smaller wearable name badges. Verify all three F prompts remain reachable and open their existing station menus.
- Check creature cards on portrait phones, landscape, tablet, and desktop. Models, names, rarity, level, and income must fit without crowded text. Inspect XP progress, capture progress, hover/press feedback, and selected states. The six left-side menu buttons and equipped-only detector HUD must keep their current behavior.
