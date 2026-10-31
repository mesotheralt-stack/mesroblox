--!strict
-- All economy and content tuning lives here. No paid products or external assets.
local Config = {}
Config.StartCoins = 150
Config.MaxBrainrots = 50
Config.MaxPlayers = 6
Config.GardenSlots = 6
Config.MaxLevel = 100
Config.RotationSeconds = 300
Config.DigDuration = 10
Config.SearchSeconds = 1
Config.FindChance = 0.5

-- Finishes roll independently of species rarity, after a successful signal.
-- The weights total 10,000: 87.8%, 8%, 3%, 1%, and 0.2% respectively.
Config.Variants = {
	{id = "Normal", name = "Normal", weight = 8780, multiplier = 1, color = Color3.fromRGB(177, 191, 180), accent = Color3.fromRGB(239, 229, 201)},
	{id = "Bronze", name = "Bronze", weight = 800, multiplier = 1.5, color = Color3.fromRGB(191, 122, 71), accent = Color3.fromRGB(245, 185, 124)},
	{id = "Silver", name = "Silver", weight = 300, multiplier = 2, color = Color3.fromRGB(184, 201, 215), accent = Color3.fromRGB(241, 249, 255)},
	{id = "Gold", name = "Gold", weight = 100, multiplier = 3, color = Color3.fromRGB(237, 184, 60), accent = Color3.fromRGB(255, 232, 155)},
	{id = "Diamond", name = "Diamond", weight = 20, multiplier = 5, color = Color3.fromRGB(119, 220, 244), accent = Color3.fromRGB(222, 251, 255)},
}

Config.Rarities = {
	{id = "Common", name = "Common", color = Color3.fromRGB(177, 191, 180), weight = 5800, multiplier = 1, taps = 6},
	{id = "Uncommon", name = "Uncommon", color = Color3.fromRGB(131, 227, 108), weight = 2600, multiplier = 2.5, taps = 9},
	{id = "Rare", name = "Rare", color = Color3.fromRGB(84, 180, 255), weight = 1100, multiplier = 7, taps = 12},
	{id = "Epic", name = "Epic", color = Color3.fromRGB(193, 133, 255), weight = 380, multiplier = 20, taps = 16},
	{id = "Legendary", name = "Legendary", color = Color3.fromRGB(255, 200, 74), weight = 100, multiplier = 60, taps = 20},
	{id = "Mythic", name = "Mythic", color = Color3.fromRGB(255, 112, 157), weight = 19, multiplier = 160, taps = 25},
	{id = "Secret", name = "Secret", color = Color3.fromRGB(131, 255, 237), weight = 1, multiplier = 500, taps = 30},
}

Config.Worlds = {
	{id = "Meadow", name = "Clover Commons", unlockCost = 0, minPower = 1, maxRarity = 4, color = Color3.fromRGB(139, 183, 127), description = "A sheltered clover valley beneath mossy chalk cliffs. Common through Epic discoveries."},
	{id = "Dunes", name = "Sunset Sands", unlockCost = 8000, minPower = 4, maxRarity = 6, color = Color3.fromRGB(219, 165, 111), description = "Warm sandstone canyons and a quiet oasis. Mythic creatures hide beneath the sand."},
	{id = "Cosmic", name = "Moonbloom Cove", unlockCost = 125000, minPower = 6, maxRarity = 7, color = Color3.fromRGB(137, 209, 206), description = "Turquoise tidal pools and lilac crystal groves. A tiny chance of a Secret discovery."},
}

Config.Detectors = {
	{id = "twig", name = "Tin Twig", power = 2, speed = 4, price = 0, world = "Meadow", color = Color3.fromRGB(163, 177, 159)},
	{id = "copper", name = "Copper Chirper", power = 3, speed = 3.5, price = 650, world = "Meadow", color = Color3.fromRGB(230, 160, 107)},
	{id = "clover", name = "Clover Scanner", power = 4, speed = 3, price = 4200, world = "Meadow", color = Color3.fromRGB(162, 237, 124)},
	{id = "sunbeam", name = "Sunbeam Seeker", power = 5, speed = 2.5, price = 16000, world = "Dunes", color = Color3.fromRGB(255, 208, 102)},
	{id = "prism", name = "Prism Pulse", power = 6, speed = 2, price = 70000, world = "Dunes", color = Color3.fromRGB(255, 143, 183)},
	{id = "moon", name = "Moonbeam Array", power = 7, speed = 1.4, price = 240000, world = "Cosmic", color = Color3.fromRGB(180, 156, 255)},
	{id = "void", name = "Void Whisperer", power = 7, speed = 0.8, price = 800000, world = "Cosmic", color = Color3.fromRGB(129, 255, 230)},
}

Config.Foods = {
	{id = "crumb", name = "Suspicious Crumb", emoji = "🍞", xp = 25, price = 15, stock = 24},
	{id = "carrot", name = "Crunchy Carrot", emoji = "🥕", xp = 60, price = 40, stock = 20},
	{id = "apple", name = "Wobble Apple", emoji = "🍎", xp = 110, price = 80, stock = 18},
	{id = "banana", name = "Bonkers Banana", emoji = "🍌", xp = 180, price = 150, stock = 16},
	{id = "cookie", name = "Chaos Cookie", emoji = "🍪", xp = 300, price = 280, stock = 14},
	{id = "taco", name = "Turbo Taco", emoji = "🌮", xp = 500, price = 500, stock = 12},
	{id = "donut", name = "Disco Donut", emoji = "🍩", xp = 800, price = 900, stock = 10},
	{id = "pizza", name = "Party Pizza", emoji = "🍕", xp = 1250, price = 1600, stock = 9},
	{id = "sushi", name = "Silly Sushi", emoji = "🍣", xp = 2000, price = 2800, stock = 8},
	{id = "burger", name = "Galaxy Burger", emoji = "🍔", xp = 3200, price = 5000, stock = 7},
	{id = "cake", name = "Cloud Cake", emoji = "🍰", xp = 5000, price = 8500, stock = 6},
	{id = "melon", name = "Meteor Melon", emoji = "🍉", xp = 7500, price = 14000, stock = 5},
	{id = "honey", name = "Mythic Honey", emoji = "🍯", xp = 11000, price = 23000, stock = 4},
	{id = "star", name = "Stardust Sorbet", emoji = "🍨", xp = 16000, price = 36000, stock = 3},
	{id = "feast", name = "Secret Midnight Feast", emoji = "🍱", xp = 24000, price = 60000, stock = 2},
}

Config.Boosts = {
	Growth = {name = "Growth Juice", price = 500, duration = 300},
	Income = {name = "Golden Hour", price = 1000, duration = 300},
}

-- Original names and procedural silhouettes; every species has its own palette.
Config.Creatures = {
	{id = "sprout", name = "Sproutini Spaghetti", rarity = "Common", color = Color3.fromRGB(144, 211, 113), accent = Color3.fromRGB(255, 226, 135), shape = "sprout"},
	{id = "toast", name = "Toasto Bamboozlo", rarity = "Common", color = Color3.fromRGB(231, 171, 109), accent = Color3.fromRGB(255, 230, 168), shape = "toast"},
	{id = "pebble", name = "Pebblino Wobblino", rarity = "Common", color = Color3.fromRGB(172, 185, 201), accent = Color3.fromRGB(249, 176, 188), shape = "rock"},
	{id = "croissant", name = "Croissantino Butterbello", rarity = "Common", color = Color3.fromRGB(224, 164, 95), accent = Color3.fromRGB(255, 224, 163), shape = "croissant"},
	{id = "frog", name = "Froggolini Ravioli", rarity = "Uncommon", color = Color3.fromRGB(111, 211, 127), accent = Color3.fromRGB(255, 226, 130), shape = "frog"},
	{id = "mushroom", name = "Mushmello Jellino", rarity = "Uncommon", color = Color3.fromRGB(255, 174, 199), accent = Color3.fromRGB(255, 246, 217), shape = "mushroom"},
	{id = "bee", name = "Buzzetti Confetti", rarity = "Uncommon", color = Color3.fromRGB(255, 207, 92), accent = Color3.fromRGB(97, 76, 63), shape = "bee"},
	{id = "snail", name = "Snailini Pistachio", rarity = "Uncommon", color = Color3.fromRGB(171, 205, 139), accent = Color3.fromRGB(238, 177, 139), shape = "snail"},
	{id = "shark", name = "Sharkuccino Slippers", rarity = "Rare", color = Color3.fromRGB(111, 181, 236), accent = Color3.fromRGB(255, 210, 129), shape = "shark"},
	{id = "cactus", name = "Cactini Linguini", rarity = "Rare", color = Color3.fromRGB(94, 195, 161), accent = Color3.fromRGB(255, 145, 197), shape = "cactus"},
	{id = "cloud", name = "Cloudolini Macaroni", rarity = "Rare", color = Color3.fromRGB(188, 225, 255), accent = Color3.fromRGB(140, 150, 245), shape = "cloud"},
	{id = "teapot", name = "Teapotelli Chamomillo", rarity = "Rare", color = Color3.fromRGB(153, 202, 214), accent = Color3.fromRGB(249, 211, 139), shape = "teapot"},
	{id = "octopus", name = "Octopesto Presto", rarity = "Epic", color = Color3.fromRGB(189, 138, 242), accent = Color3.fromRGB(255, 208, 143), shape = "octopus"},
	{id = "disco", name = "Disco Dodo Deluxe", rarity = "Epic", color = Color3.fromRGB(239, 133, 220), accent = Color3.fromRGB(139, 245, 219), shape = "bird"},
	{id = "wizard", name = "Wizzaroni Pepperoni", rarity = "Epic", color = Color3.fromRGB(160, 142, 240), accent = Color3.fromRGB(255, 210, 109), shape = "wizard"},
	{id = "turtle", name = "Turtellini Terrarium", rarity = "Epic", color = Color3.fromRGB(109, 190, 172), accent = Color3.fromRGB(215, 169, 238), shape = "turtle"},
	{id = "lion", name = "Lionardo Lemonardo", rarity = "Legendary", color = Color3.fromRGB(255, 208, 98), accent = Color3.fromRGB(224, 131, 76), shape = "lion"},
	{id = "dragon", name = "Dragolato Gelato", rarity = "Legendary", color = Color3.fromRGB(255, 164, 116), accent = Color3.fromRGB(158, 242, 195), shape = "dragon"},
	{id = "sun", name = "Solini Gnocchini", rarity = "Legendary", color = Color3.fromRGB(255, 227, 115), accent = Color3.fromRGB(255, 157, 110), shape = "sun"},
	{id = "koi", name = "Koiramisu Goldentino", rarity = "Legendary", color = Color3.fromRGB(250, 213, 132), accent = Color3.fromRGB(232, 131, 113), shape = "koi"},
	{id = "phoenix", name = "Phoeniccini Fettuccine", rarity = "Mythic", color = Color3.fromRGB(255, 116, 151), accent = Color3.fromRGB(255, 216, 126), shape = "phoenix"},
	{id = "moon", name = "Lunatici Mochi", rarity = "Mythic", color = Color3.fromRGB(202, 166, 255), accent = Color3.fromRGB(255, 194, 233), shape = "moon"},
	{id = "jelly", name = "Jellybean Astronautini", rarity = "Mythic", color = Color3.fromRGB(255, 160, 218), accent = Color3.fromRGB(164, 244, 255), shape = "jelly"},
	{id = "clock", name = "Ticktockini Eternelli", rarity = "Mythic", color = Color3.fromRGB(178, 161, 227), accent = Color3.fromRGB(246, 209, 138), shape = "clock"},
	{id = "void", name = "Voidolini Neveroni", rarity = "Secret", color = Color3.fromRGB(73, 62, 117), accent = Color3.fromRGB(130, 255, 224), shape = "void"},
	{id = "cosmic", name = "Cosmic Capybaroni", rarity = "Secret", color = Color3.fromRGB(153, 230, 218), accent = Color3.fromRGB(255, 220, 151), shape = "capybara"},
	{id = "crown", name = "Emperor Noodlestar", rarity = "Secret", color = Color3.fromRGB(220, 202, 255), accent = Color3.fromRGB(255, 218, 113), shape = "crown"},
	{id = "manta", name = "Mantaroni Nebulini", rarity = "Secret", color = Color3.fromRGB(100, 126, 195), accent = Color3.fromRGB(154, 245, 224), shape = "manta"},
}

function Config.get(list, id)
	for _, item in ipairs(list) do
		if item.id == id then return item end
	end
	return nil
end

function Config.xpNeeded(level: number): number
	return math.floor(40 + 18 * level ^ 1.2)
end

function Config.variant(id)
	return Config.get(Config.Variants, id) or Config.Variants[1]
end

function Config.rollVariant(unitRoll: number)
	local total = 0
	for _, variant in Config.Variants do total += variant.weight end
	local roll = math.clamp(unitRoll, 0, 1) * total
	local threshold = 0
	for _, variant in Config.Variants do
		threshold += variant.weight
		if roll < threshold then return variant end
	end
	return Config.Variants[#Config.Variants]
end

function Config.income(specId: string, level: number, variantId: string?): number
	local spec = Config.get(Config.Creatures, specId)
	if not spec then return 0 end
	local rarity = Config.get(Config.Rarities, spec.rarity)
	local growth = math.clamp(level, 1, Config.MaxLevel) - 1
	local base = math.floor(2 * rarity.multiplier * (1 + growth * 0.24) ^ 1.15) + growth
	return math.floor(base * Config.variant(variantId).multiplier)
end

function Config.sellValue(specId: string, level: number, variantId: string?): number
	return Config.income(specId, level, variantId) * 45
end

return Config
