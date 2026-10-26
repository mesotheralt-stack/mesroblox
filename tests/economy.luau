-- Runs real Config functions. The Python runner supplies Config and a Color3 shim.
local assertions = 0
local function check(condition, message)
	assertions += 1
	assert(condition, message)
end

local function uniqueIds(list, label)
	local seen = {}
	for _, item in ipairs(list) do
		check(type(item.id) == "string" and #item.id > 0, label .. " ID must be nonempty")
		check(not seen[item.id], label .. " has duplicate ID: " .. item.id)
		seen[item.id] = true
	end
end
for name, list in pairs({Rarities=Config.Rarities, Worlds=Config.Worlds, Detectors=Config.Detectors, Foods=Config.Foods, Creatures=Config.Creatures}) do
	uniqueIds(list, name)
end

check(#Config.Rarities == 7, "Must have exactly seven rarity tiers")
check(#Config.Creatures == 28, "Must have 28 original brainrot species")
check(#Config.Foods >= 10 and #Config.Foods <= 15, "Food catalogue must contain 10–15 foods")
check(#Config.Worlds >= 2 and #Config.Worlds <= 3, "Must have 2–3 worlds")
check(Config.RotationSeconds == 300, "Food rotation must last exactly five minutes")
check(Config.Boosts.Growth.duration == 300 and Config.Boosts.Income.duration == 300, "Both boosts must last five minutes")
check(Config.StartCoins >= Config.Foods[1].price, "New players must afford at least one food")
check(Config.Detectors[1].price == 0 and Config.Detectors[1].world == Config.Worlds[1].id, "Starter detector must be free and reachable")

local expected = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}
local speciesByRarity = {}
for i, rarity in ipairs(Config.Rarities) do
	check(rarity.id == expected[i], "Rarity order must match the requested progression")
	check(rarity.weight > 0, "Every rarity needs a positive drop chance")
	check(rarity.taps > 0 and rarity.taps / Config.DigDuration <= 8, "Capture requirements must be physically achievable")
	if i > 1 then
		check(rarity.multiplier > Config.Rarities[i-1].multiplier, "Higher rarities must earn more")
		check(rarity.weight < Config.Rarities[i-1].weight, "Higher rarities must be less common")
	end
	speciesByRarity[rarity.id] = {}
end
for _, creature in ipairs(Config.Creatures) do
	check(speciesByRarity[creature.rarity] ~= nil, "Creature must reference an existing rarity")
	check(type(creature.shape) == "string" and #creature.shape > 0, "Each creature needs a procedural shape")
	table.insert(speciesByRarity[creature.rarity], creature)
	local previousIncome = 0
	local previousSell = 0
	for level = 1, Config.MaxLevel do
		local income = Config.income(creature.id, level)
		local sell = Config.sellValue(creature.id, level)
		check(income > previousIncome, creature.id .. " must earn strictly more with every level")
		check(sell > previousSell, creature.id .. " sale value must grow with level")
		check(income % 1 == 0 and sell % 1 == 0, "Coin amounts must be integers")
		previousIncome, previousSell = income, sell
	end
	check(Config.income(creature.id, -100) == Config.income(creature.id, 1), "Income must clamp below level one")
	check(Config.income(creature.id, 10000) == Config.income(creature.id, Config.MaxLevel), "Income must clamp above max level")
end
for i, rarity in ipairs(Config.Rarities) do
	check(#speciesByRarity[rarity.id] == 4, "Every rarity must have four obtainable species")
	if i > 1 then
		for level = 1, Config.MaxLevel do
			local lower = speciesByRarity[Config.Rarities[i-1].id][1]
			local higher = speciesByRarity[rarity.id][1]
			check(Config.income(higher.id, level) > Config.income(lower.id, level), "Rarity income ordering failed at level " .. level)
		end
	end
end
check(Config.income("missing-species", 1) == 0, "Unknown species must not generate income")
check(Config.get(Config.Foods, "missing-food") == nil, "Unknown IDs must not resolve")

local previousXP = 0
for level = 1, Config.MaxLevel do
	local xp = Config.xpNeeded(level)
	check(xp > previousXP and xp % 1 == 0, "XP requirements must be positive increasing integers")
	previousXP = xp
end
for i, food in ipairs(Config.Foods) do
	check(food.xp > 0 and food.price > 0 and food.stock > 0, "Foods must have valid XP, cost and stock")
	if i > 1 then
		check(food.xp > Config.Foods[i-1].xp, "Food progression must increase XP")
		check(food.price > Config.Foods[i-1].price, "Stronger foods must cost more")
	end
end

local reachableWorlds = {[Config.Worlds[1].id] = true}
for i, world in ipairs(Config.Worlds) do
	if i > 1 then
		local canEnter = false
		for _, detector in ipairs(Config.Detectors) do
			if reachableWorlds[detector.world] and detector.power >= world.minPower then canEnter = true end
		end
		check(canEnter, "World " .. world.id .. " requires a detector locked behind itself")
		reachableWorlds[world.id] = true
		check(world.unlockCost > Config.Worlds[i-1].unlockCost, "World unlocks should progress in cost")
	end
	check(world.maxRarity >= world.minPower and world.maxRarity <= #Config.Rarities, "World rarity range invalid")
end
for i, detector in ipairs(Config.Detectors) do
	check(reachableWorlds[detector.world] == true, "Detector shop world must exist and be reachable")
	check(detector.speed > 0 and detector.power >= 1 and detector.power <= #Config.Rarities, "Invalid detector capabilities")
	if i > 1 then
		check(detector.price > Config.Detectors[i-1].price, "Upgraded detectors should cost more")
		check(detector.speed < Config.Detectors[i-1].speed, "Upgraded detectors should search faster")
		check(detector.power >= Config.Detectors[i-1].power, "Upgraded detectors cannot lose power")
	end
end
for rank, rarity in ipairs(Config.Rarities) do
	local obtainable = false
	for _, world in ipairs(Config.Worlds) do
		for _, detector in ipairs(Config.Detectors) do
			if reachableWorlds[world.id] and reachableWorlds[detector.world] and detector.power >= rank and world.maxRarity >= rank then
				obtainable = true
			end
		end
	end
	check(obtainable, "Rarity " .. rarity.id .. " cannot be found with any detector/world combination")
end
print("PASS economy, content and progression (" .. assertions .. " assertions)")
