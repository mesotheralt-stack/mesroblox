# Studio acceptance pass

These engine checks remain to be performed in Roblox Studio. Automated CLI checks are not a substitute for this pass.

1. Open the built `BrainrotBloom.rbxlx` and press Play. Confirm three islands, a green hub, trees, sand pits, shops, gallery, a held detector, and no errors in Output. If save APIs are unavailable, confirm the explicit temporary-progress warning and that the game still plays.
2. Use WORLDS to teleport to Clover Commons. Walk onto and out of the sand: E/DETECT should only start a capture on the sand. Verify ground collision, jumping, walking, respawn, and HOME.
3. Complete a capture using Space, then another with the touch/mouse button. Let one expire and verify it awards nothing. Teleporting out must prevent capture rewards; rapid duplicated requests must not duplicate a reward.
4. Verify BAG shows the real name, rarity, level, XP, and income. Display different creatures, feed one or all foods, and confirm level-ups increase income and model size. A second creature should keep earning while the first is displayed.
5. Teleport to FOOD, buy different quantities, verify coins/stock/pantry counts, and wait for a five-minute rotation. Walk-up F prompts should open the same shops.
6. Verify GEAR has Detectors and Boosts. Buy and equip a detector, inspect its held model, and verify its shorter scan cooldown. Buy each boost for a chosen creature; verify only that creature's XP/income doubles, five-minute expiration works, and a duplicate purchase is refused without charging.
7. Earn enough coins, unlock Sunset Sands then Moonbloom Crater, and verify their detector requirements and expanded rarity ceilings. A locked destination must refuse teleporting. Rare/Mythic/Secret are probability-based finds; no particular number of searches guarantees one.
8. SELL should show the level-dependent value and require confirmation. Verify the creature disappears once, its income stops, and the displayed companion changes if necessary.
9. In Studio's Device Emulator, check phone portrait, phone landscape, and tablet views. Open every page, scroll a full collection and food list, and complete the tap minigame without clipped buttons. Keyboard E must not double-trigger the F proximity prompts.
10. Use **Test → Start** with two players. Confirm inventories, coins, boosts, and sales are independent. Rotation contents should match, but one player's purchases should not remove the other player's stock. Capture taps must not affect the other player's capture.
11. Run through a full 12-minute lighting cycle and confirm nighttime readability around pits and paths.
12. In a published private test experience, verify live persistence: buy food, capture/feed a creature, upgrade a detector, unlock a world, leave, and rejoin. Confirm everything reloads. Resetting the character must retain progress. Verify a second live session cannot overwrite the first session's collection.

For tuning, use `src/shared/Config.luau`; keep game rewards and purchases on the server. No debug money grant or save-wipe endpoint is shipped.

## Visual update checks

- Verify the 700 × 660-stud islands and 320 × 280 sand pits have solid ground, clear digging areas, and working world teleports. Check the pond, outer trails, ruins, and crystals without getting stuck.
- Check the physical shop/world signs are readable nearby and no floating destination panels cover the scenery.
- Inspect all 21 creatures in the collection and as companions. Check fine details remain attached when models grow, and each preview frames the whole creature.
- Search/filter/sort a full collection; move through the 12-creature pages and open/feed/sell the selected creature. Confirm the scroll position stays comfortable after feeding.
- Verify the Builder Sans text and muted colors are readable at phone sizes. Switch directly between pages using the bottom navigation, including phone landscape. Complete a capture using the new creature preview sheet.

## Sculpture and scenery pass

- Before Play, confirm the complete map is visible in the downloaded place. Press Play and confirm the server refreshes it once, with one BrainrotWorld and one gallery.
- Inspect distinct body shapes: the frog’s four legs, shark’s long body/slippers, capybara’s muzzle/four feet, wizard’s robe, moon’s crescent, octopus’s curled tentacles, and bee’s abdomen/wings. Check all species at both level 1 and high levels. Native build validation checks finite transforms; Studio still needs to check materials and appearance.
- Walk the sunken pit entrance steps and all landmark trails. Check the windmill, pond bridge stairs, oasis paths, observatory entrance, shop counters and trading post without blocked teleports or trapping collisions.
- Verify the cream/sage journal UI contrast in daylight and at night; inspect the illustrated world cards, sculpture stages, food tokens, detector stats, and complete a capture on a phone.
- Confirm the full creature remains in frame in portrait and landscape viewports, including broad wings and tall hats. The camera now responds to the viewport aspect ratio.
