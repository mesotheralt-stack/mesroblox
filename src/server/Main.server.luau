-- Brainrot Bloom: all currency, collections, rolls and capture rewards live on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("BrainrotShared")
local Config = require(Shared:WaitForChild("Config"))
local CreatureFactory = require(Shared:WaitForChild("CreatureFactory"))
local World = require(script.Parent:WaitForChild("World"))
local DetectorTool = require(script.Parent:WaitForChild("DetectorTool"))
local map = World.build(Config)

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "BrainrotRemotes"
local Action = Instance.new("RemoteFunction")
Action.Name = "Action"
Action.Parent = remoteFolder
local State = Instance.new("RemoteEvent")
State.Name = "State"
State.Parent = remoteFolder
local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remoteFolder
remoteFolder.Parent = ReplicatedStorage

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("BrainrotBloom_Player_v1")
end)
if not storeOk then
	warn("[Brainrot Bloom] Save store could not initialize: " .. tostring(store))
	store = nil
end
local sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
local profiles = {}
local savesInFlight = {}
local closing = false
local rng = Random.new()
local MAX_COINS = 1e15
local LOCK_SECONDS = 180
local cachedEpoch = -1
local rotation = {}

local function integer(value, minimum, maximum, fallback)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function lookup(list, id)
	if type(id) ~= "string" then return nil end
	return Config.get(list, id)
end

local function owned(list, id)
	return table.find(list, id) ~= nil
end

local function newData()
	return {
		coins = Config.StartCoins,
		brainrots = {},
		foods = { [Config.Foods[1].id] = 3 },
		ownedDetectors = { Config.Detectors[1].id },
		detector = Config.Detectors[1].id,
		unlockedWorlds = { Config.Worlds[1].id },
		activeBrainrot = nil,
		discoveryCount = 0,
	}
end

local function sanitize(raw)
	local data = newData()
	if type(raw) ~= "table" then return data end
	data.coins = integer(raw.coins, 0, MAX_COINS, Config.StartCoins)
	data.discoveryCount = integer(raw.discoveryCount, 0, 1e9, 0)
	data.foods = {}
	for _, food in Config.Foods do
		data.foods[food.id] = integer(type(raw.foods) == "table" and raw.foods[food.id], 0, 9999, 0)
	end
	for _, spec in Config.Detectors do
		if type(raw.ownedDetectors) == "table" and owned(raw.ownedDetectors, spec.id) and not owned(data.ownedDetectors, spec.id) then
			table.insert(data.ownedDetectors, spec.id)
		end
	end
	if owned(data.ownedDetectors, raw.detector) then data.detector = raw.detector end
	for _, world in Config.Worlds do
		if type(raw.unlockedWorlds) == "table" and owned(raw.unlockedWorlds, world.id) and not owned(data.unlockedWorlds, world.id) then
			table.insert(data.unlockedWorlds, world.id)
		end
	end
	local seen = {}
	if type(raw.brainrots) == "table" then
		for _, saved in raw.brainrots do
			if #data.brainrots >= Config.MaxBrainrots then break end
			if type(saved) == "table" and lookup(Config.Creatures, saved.specId) then
				local uid = type(saved.uid) == "string" and #saved.uid <= 64 and saved.uid or HttpService:GenerateGUID(false)
				if not seen[uid] then
					seen[uid] = true
					local level = integer(saved.level, 1, Config.MaxLevel, 1)
					table.insert(data.brainrots, {
						uid = uid, specId = saved.specId, level = level,
						xp = level < Config.MaxLevel and integer(saved.xp, 0, Config.xpNeeded(level) - 1, 0) or 0,
						growthBoostUntil = integer(saved.growthBoostUntil, 0, os.time() + Config.Boosts.Growth.duration, 0),
						incomeBoostUntil = integer(saved.incomeBoostUntil, 0, os.time() + Config.Boosts.Income.duration, 0),
					})
				end
			end
		end
	end
	if seen[raw.activeBrainrot] then data.activeBrainrot = raw.activeBrainrot end
	if not data.activeBrainrot and data.brainrots[1] then data.activeBrainrot = data.brainrots[1].uid end
	return data
end

local function findBrainrot(profile, uid)
	if type(uid) ~= "string" then return nil end
	for index, brainrot in profile.data.brainrots do
		if brainrot.uid == uid then return brainrot, index end
	end
	return nil
end

local function brainrotIncome(brainrot)
	local boost = brainrot.incomeBoostUntil > os.time() and 2 or 1
	return Config.income(brainrot.specId, brainrot.level) * boost
end

local function totalIncome(profile)
	local total = 0
	for _, brainrot in profile.data.brainrots do total += brainrotIncome(brainrot) end
	return total
end

-- Same rotation for every server at the same five-minute UTC boundary. Quantities are per player.
local function refreshRotation()
	local epoch = math.floor(os.time() / Config.RotationSeconds)
	if epoch ~= cachedEpoch then
		cachedEpoch = epoch
		local random = Random.new(epoch)
		local candidates = {}
		for index = 2, #Config.Foods do table.insert(candidates, Config.Foods[index]) end
		for index = #candidates, 2, -1 do
			local other = random:NextInteger(1, index)
			candidates[index], candidates[other] = candidates[other], candidates[index]
		end
		rotation = { Config.Foods[1] }
		for index = 1, math.min(5, #candidates) do table.insert(rotation, candidates[index]) end
	end
	return epoch
end

local function ensureStock(profile)
	local epoch = refreshRotation()
	if profile.stockEpoch ~= epoch then
		profile.stockEpoch = epoch
		profile.purchased = {}
	end
end

local function publicState(profile)
	ensureStock(profile)
	local brainrots = {}
	for _, brainrot in profile.data.brainrots do
		local spec = lookup(Config.Creatures, brainrot.specId)
		table.insert(brainrots, {
			uid = brainrot.uid, specId = brainrot.specId, name = spec.name, rarity = spec.rarity,
			level = brainrot.level, xp = brainrot.xp, xpNeeded = Config.xpNeeded(brainrot.level),
			income = brainrotIncome(brainrot), growthBoostUntil = brainrot.growthBoostUntil,
			incomeBoostUntil = brainrot.incomeBoostUntil,
		})
	end
	local stock = {}
	for _, food in rotation do
		table.insert(stock, { id = food.id, remaining = math.max(0, food.stock - (profile.purchased[food.id] or 0)) })
	end
	return {
		coins = math.floor(profile.data.coins), income = totalIncome(profile), world = profile.world,
		detector = profile.data.detector, ownedDetectors = table.clone(profile.data.ownedDetectors),
		unlockedWorlds = table.clone(profile.data.unlockedWorlds), activeBrainrot = profile.data.activeBrainrot,
		brainrots = brainrots, foods = table.clone(profile.data.foods), stock = stock,
		rotationEnds = (cachedEpoch + 1) * Config.RotationSeconds, discoveryCount = profile.data.discoveryCount,
		serverTime = os.time(), persistenceEnabled = profile.persistent,
	}
end

local function push(player, profile)
	if player.Parent == Players then State:FireClient(player, publicState(profile)) end
end

local function updateCompanion(profile)
	if profile.companion then profile.companion:Destroy(); profile.companion = nil end
	local brainrot = findBrainrot(profile, profile.data.activeBrainrot)
	if not brainrot then return end
	local spec = lookup(Config.Creatures, brainrot.specId)
	local model = CreatureFactory.create(spec, 0.7 + (brainrot.level - 1) * 0.015)
	model.Name = profile.player.Name .. "'s " .. spec.name
	model.Parent = workspace
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		model.PrimaryPart = primary
		local label = Instance.new("BillboardGui")
		label.Name = "CompanionLabel"
		label.Size = UDim2.fromOffset(164, 38)
		label.StudsOffset = Vector3.new(0, 5.3 * (0.7 + (brainrot.level - 1) * 0.015), 0)
		label.MaxDistance = 28
		label.Parent = primary
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.BuilderSansMedium
		text.TextSize = 12
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = string.format("%s  •  Lv.%d\n$%s / sec", spec.name, brainrot.level, tostring(brainrotIncome(brainrot)))
		text.Parent = label
	end
	profile.companion = model
end

local function snapshot(profile)
	local copy = {
		coins = math.floor(profile.data.coins), discoveryCount = profile.data.discoveryCount,
		foods = table.clone(profile.data.foods), detector = profile.data.detector,
		ownedDetectors = table.clone(profile.data.ownedDetectors), unlockedWorlds = table.clone(profile.data.unlockedWorlds),
		activeBrainrot = profile.data.activeBrainrot, brainrots = {},
	}
	for _, brainrot in profile.data.brainrots do table.insert(copy.brainrots, table.clone(brainrot)) end
	return copy
end

local function save(profile, release)
	if not profile.persistent then return true end
	local userId = profile.player.UserId
	-- A removal waits for an autosave so the final snapshot cannot be skipped.
	if savesInFlight[userId] then
		if not release then return false end
		local deadline = os.clock() + 12
		repeat task.wait(0.1) until not savesInFlight[userId] or os.clock() >= deadline
		if savesInFlight[userId] then return false end
	end
	savesInFlight[userId] = true
	local data = snapshot(profile)
	local ok, result = pcall(function()
		return store:UpdateAsync("Player_" .. userId, function(previous)
			if type(previous) ~= "table" or type(previous.session) ~= "table" or previous.session.id ~= sessionId then
				return nil -- Never overwrite a profile whose session lock we no longer own.
			end
			return { schema = 1, data = data, session = not release and { id = sessionId, expires = os.time() + LOCK_SECONDS } or nil }
		end)
	end)
	savesInFlight[userId] = nil
	if not ok then
		warn("[Brainrot Bloom] Save failed for user " .. userId .. ": " .. tostring(result))
		return false
	end
	if not result then
		profile.persistent = false
		if profile.player.Parent == Players then profile.player:Kick("Your save session moved to another server. Please rejoin to protect your collection.") end
		return false
	end
	return true
end

local function acquire(player)
	local finalError
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:UpdateAsync("Player_" .. player.UserId, function(previous)
				if type(previous) == "table" and type(previous.session) == "table"
					and previous.session.id ~= sessionId and (tonumber(previous.session.expires) or 0) > os.time() then
					return nil
				end
				local data = type(previous) == "table" and previous.data or nil
				return { schema = 1, data = sanitize(data), session = { id = sessionId, expires = os.time() + LOCK_SECONDS } }
			end)
		end)
		if ok then
			if type(result) == "table" and type(result.session) == "table" and result.session.id == sessionId then
				return sanitize(result.data), true
			end
			return nil, false, "Your collection is still open on another server. Wait a moment and rejoin."
		end
		finalError = result
		if attempt < 3 then task.wait(attempt) end
	end
	warn("[Brainrot Bloom] DataStore unavailable: " .. tostring(finalError))
	if RunService:IsStudio() then
		warn("[Brainrot Bloom] Studio uses temporary progress until the experience is published and API Services are enabled. No failed load will be saved.")
		return newData(), false
	end
	return nil, false, "Your collection could not be loaded safely. Please rejoin in a moment."
end

local function rootFor(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function pitForPosition(position)
	for id, pit in map.pits do
		local relative = position - pit.center
		if math.abs(relative.X) <= pit.size.X / 2 and math.abs(relative.Z) <= pit.size.Z / 2 and math.abs(relative.Y) < 35 then
			return lookup(Config.Worlds, id)
		end
	end
	return nil
end

local function teleport(player, profile, destination)
	local frame = type(destination) == "string" and map.destinations[destination]
	if not frame then return false, "That destination does not exist." end
	local world = lookup(Config.Worlds, destination)
	if world and not owned(profile.data.unlockedWorlds, world.id) then return false, "Unlock this world in the Worlds menu first." end
	local root = rootFor(player)
	if not root then return false, "Wait for your character to spawn." end
	profile.dig = nil
	player.Character:PivotTo(frame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	profile.world = world and world.id or Config.Worlds[1].id
	return true
end

local function charge(profile, cost)
	if profile.data.coins < cost then return false end
	profile.data.coins -= cost
	return true
end

local function fail(message)
	return { ok = false, message = message }
end

local function rollCreature(world, detector)
	local choices = {}
	local total = 0
	local ceiling = math.min(world.maxRarity, detector.power)
	for index, rarity in Config.Rarities do
		if index <= ceiling then
			local species = {}
			for _, spec in Config.Creatures do
				if spec.rarity == rarity.id then table.insert(species, spec) end
			end
			if #species > 0 then
				local weight = rarity.weight * (1 + math.max(0, detector.power - 1) * (index - 1) * 0.25)
				total += weight
				table.insert(choices, { rarity = rarity, species = species, threshold = total })
			end
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, choice in choices do
		if roll <= choice.threshold then return choice.species[rng:NextInteger(1, #choice.species)], choice.rarity end
	end
	error("No valid creature roll; check world and rarity configuration")
end

local handlers = {}

function handlers.GetState(_player, _profile, _payload)
	return { ok = true }
end

function handlers.Teleport(player, profile, payload)
	local ok, message = teleport(player, profile, payload.destination)
	return { ok = ok, message = message }
end

function handlers.EquipDetector(_player, profile, payload)
	if not lookup(Config.Detectors, payload.id) or not owned(profile.data.ownedDetectors, payload.id) then return fail("You do not own that detector.") end
	if profile.dig and profile.dig.deadline > os.clock() then return fail("Finish your current capture first.") end
	profile.data.detector = payload.id
	DetectorTool.equip(profile.player, lookup(Config.Detectors, payload.id))
	return { ok = true, message = "Detector equipped." }
end

function handlers.BuyDetector(_player, profile, payload)
	local spec = lookup(Config.Detectors, payload.id)
	if not spec then return fail("Unknown detector.") end
	if profile.dig and profile.dig.deadline > os.clock() then return fail("Finish your current capture first.") end
	if owned(profile.data.ownedDetectors, spec.id) then return fail("You already own this detector.") end
	if not owned(profile.data.unlockedWorlds, spec.world) then return fail("Unlock " .. spec.world .. " before buying this detector.") end
	if not charge(profile, spec.price) then return fail("You need more coins for this detector.") end
	table.insert(profile.data.ownedDetectors, spec.id)
	profile.data.detector = spec.id
	DetectorTool.equip(profile.player, spec)
	return { ok = true, message = spec.name .. " purchased and equipped!" }
end

function handlers.BuyFood(_player, profile, payload)
	ensureStock(profile)
	local food = lookup(Config.Foods, payload.id)
	if not food then return fail("Unknown food.") end
	if not table.find(rotation, food) then return fail("This food is not in the current rotation.") end
	local quantity = integer(payload.quantity, 1, 100, 1)
	local remaining = food.stock - (profile.purchased[food.id] or 0)
	if quantity > remaining then return fail("There is not enough stock left in this rotation.") end
	if (profile.data.foods[food.id] or 0) + quantity > 9999 then return fail("Your pantry is full of this food.") end
	if not charge(profile, food.price * quantity) then return fail("You need more coins for this food.") end
	profile.data.foods[food.id] = (profile.data.foods[food.id] or 0) + quantity
	profile.purchased[food.id] = (profile.purchased[food.id] or 0) + quantity
	return { ok = true, message = "Bought " .. quantity .. " × " .. food.name .. "." }
end

function handlers.Feed(_player, profile, payload)
	local brainrot = findBrainrot(profile, payload.uid)
	local food = lookup(Config.Foods, payload.foodId)
	if not brainrot or not food then return fail("Choose a brainrot and food from your inventory.") end
	if brainrot.level >= Config.MaxLevel then return fail("This brainrot has reached the maximum level.") end
	local quantity = integer(payload.quantity, 1, 100, 1)
	if quantity > (profile.data.foods[food.id] or 0) then return fail("You do not have enough of this food.") end
	profile.data.foods[food.id] -= quantity
	local previousLevel = brainrot.level
	brainrot.xp += food.xp * quantity * (brainrot.growthBoostUntil > os.time() and 2 or 1)
	while brainrot.level < Config.MaxLevel and brainrot.xp >= Config.xpNeeded(brainrot.level) do
		brainrot.xp -= Config.xpNeeded(brainrot.level)
		brainrot.level += 1
	end
	if brainrot.level == Config.MaxLevel then brainrot.xp = 0 end
	if profile.data.activeBrainrot == brainrot.uid then updateCompanion(profile) end
	local gained = brainrot.level - previousLevel
	return { ok = true, message = gained > 0 and ("Grew " .. gained .. " level" .. (gained == 1 and "!" or "s!")) or "Yum! Growth XP added." }
end

function handlers.EquipBrainrot(_player, profile, payload)
	if not findBrainrot(profile, payload.uid) then return fail("You do not own that brainrot.") end
	profile.data.activeBrainrot = payload.uid
	updateCompanion(profile)
	return { ok = true, message = "Your companion is ready. All collected brainrots still earn income!" }
end

function handlers.Sell(_player, profile, payload)
	local brainrot, index = findBrainrot(profile, payload.uid)
	if not brainrot then return fail("Choose a brainrot to sell.") end
	local value = Config.sellValue(brainrot.specId, brainrot.level)
	table.remove(profile.data.brainrots, index)
	profile.data.coins = math.min(MAX_COINS, profile.data.coins + value)
	if profile.data.activeBrainrot == brainrot.uid then
		profile.data.activeBrainrot = profile.data.brainrots[1] and profile.data.brainrots[1].uid or nil
		updateCompanion(profile)
	end
	return { ok = true, message = "Brainrot sold for $" .. tostring(value) .. "." }
end

function handlers.BuyBoost(_player, profile, payload)
	if payload.kind ~= "Growth" and payload.kind ~= "Income" then return fail("Choose a growth or income boost.") end
	local brainrot = findBrainrot(profile, payload.uid)
	local boost = Config.Boosts[payload.kind]
	if not brainrot then return fail("Choose the brainrot you want to boost.") end
	local field = payload.kind == "Growth" and "growthBoostUntil" or "incomeBoostUntil"
	if brainrot[field] > os.time() then return fail("This boost is already active. Wait for it to finish.") end
	if payload.kind == "Growth" and brainrot.level >= Config.MaxLevel then return fail("This brainrot is already at maximum level.") end
	if not charge(profile, boost.price) then return fail("You need more coins for this boost.") end
	brainrot[field] = os.time() + boost.duration
	if profile.data.activeBrainrot == brainrot.uid then updateCompanion(profile) end
	return { ok = true, message = "2× " .. string.lower(payload.kind) .. " active for five minutes!" }
end

function handlers.UnlockWorld(player, profile, payload)
	local world = lookup(Config.Worlds, payload.id)
	if not world then return fail("Unknown world.") end
	if owned(profile.data.unlockedWorlds, world.id) then return fail("You have already unlocked this world.") end
	local index = table.find(Config.Worlds, world)
	if index > 1 and not owned(profile.data.unlockedWorlds, Config.Worlds[index - 1].id) then return fail("Unlock the previous world first.") end
	if not charge(profile, world.unlockCost) then return fail("You need more coins to unlock " .. world.name .. ".") end
	table.insert(profile.data.unlockedWorlds, world.id)
	teleport(player, profile, world.id)
	return { ok = true, message = world.name .. " unlocked! New detectors are available in the gear shop." }
end

function handlers.StartDig(player, profile, _payload)
	local root = rootFor(player)
	if not root then return fail("Wait for your character to spawn.") end
	local world = pitForPosition(root.Position)
	if not world then return fail("Stand inside a sand pit to search for brainrots.") end
	if not owned(profile.data.unlockedWorlds, world.id) then return fail("Unlock this world before digging here.") end
	local detector = lookup(Config.Detectors, profile.data.detector)
	if detector.power < world.minPower then return fail("This pit needs a stronger detector. Visit the gear shop.") end
	if #profile.data.brainrots >= Config.MaxBrainrots then return fail("Your collection is full. Sell a brainrot first.") end
	if profile.dig and os.clock() < profile.dig.deadline then return fail("A capture is already in progress.") end
	if os.clock() < profile.nextDig then return fail(string.format("Detector recharging… %.1fs", profile.nextDig - os.clock())) end
	local spec, rarity = rollCreature(world, detector)
	local duration = Config.DigDuration
	profile.world = world.id
	profile.nextDig = os.clock() + detector.speed
	profile.dig = {
		id = HttpService:GenerateGUID(false), specId = spec.id, required = rarity.taps,
		count = 0, deadline = os.clock() + duration, lastTap = 0, world = world.id,
	}
	return { ok = true, dig = { id = profile.dig.id, required = rarity.taps, duration = duration, specId = spec.id, rarity = rarity.id, name = spec.name } }
end

function handlers.TapDig(player, profile, payload)
	local dig = profile.dig
	if not dig or payload.sessionId ~= dig.id then return fail("No active capture. Search the sand again.") end
	if os.clock() > dig.deadline then profile.dig = nil; return fail("It escaped! Try digging again.") end
	local root = rootFor(player)
	local currentWorld = root and pitForPosition(root.Position)
	if not currentWorld or currentWorld.id ~= dig.world then profile.dig = nil; return fail("Stay in the sand pit during a capture.") end
	if os.clock() - dig.lastTap < 0.045 then return { ok = true, count = dig.count, taps = dig.count } end
	dig.lastTap = os.clock()
	dig.count += 1
	if dig.count < dig.required then return { ok = true, count = dig.count, taps = dig.count } end
	profile.dig = nil -- Clear the session before awarding; replayed requests cannot grant another creature.
	if #profile.data.brainrots >= Config.MaxBrainrots then return fail("Your collection is full.") end
	local brainrot = { uid = HttpService:GenerateGUID(false), specId = dig.specId, level = 1, xp = 0, growthBoostUntil = 0, incomeBoostUntil = 0 }
	table.insert(profile.data.brainrots, brainrot)
	profile.data.discoveryCount += 1
	if not profile.data.activeBrainrot then profile.data.activeBrainrot = brainrot.uid; updateCompanion(profile) end
	local spec = lookup(Config.Creatures, brainrot.specId)
	return { ok = true, complete = true, message = "Captured " .. spec.name .. "! It now earns coins every second." }
end

Action.OnServerInvoke = function(player, action, payload)
	local profile = profiles[player]
	if not profile then return fail("Your collection is loading. Try again in a moment.") end
	if closing then return fail("The server is closing. Your collection is being saved.") end
	if type(action) ~= "string" or not handlers[action] then return fail("Unknown action.") end
	if payload ~= nil and type(payload) ~= "table" then return fail("Invalid request.") end
	-- Token bucket permits rapid capture taps while bounding every other action.
	local now = os.clock()
	profile.tokens = math.min(45, profile.tokens + (now - profile.tokenAt) * 28)
	profile.tokenAt = now
	local cost = action == "TapDig" and 1 or 4
	if profile.tokens < cost then return fail("Please slow down for a moment.") end
	profile.tokens -= cost
	local ok, result = pcall(handlers[action], player, profile, payload or {})
	if not ok then
		warn("[Brainrot Bloom] Action " .. action .. " failed: " .. tostring(result))
		return fail("That action could not finish. Please try again.")
	end
	-- A state snapshot accompanies meaningful actions; individual taps only return progress.
	if action ~= "TapDig" or result.complete then
		result.state = publicState(profile)
		push(player, profile)
	end
	return result
end

local function onPlayerAdded(player)
	local data, persistent, message = acquire(player)
	if not data then player:Kick(message); return end
	local profile = {
		player = player, data = data, persistent = persistent, world = Config.Worlds[1].id,
		nextDig = 0, tokens = 45, tokenAt = os.clock(), stockEpoch = -1, purchased = {},
	}
	if player.Parent ~= Players or closing then save(profile, true); return end
	profiles[player] = profile
	local function spawnCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and profiles[player] == profile then
			character:PivotTo(map.spawnCFrame)
			profile.world = Config.Worlds[1].id
			profile.dig = nil
			DetectorTool.equip(player, lookup(Config.Detectors, profile.data.detector))
			updateCompanion(profile)
			push(player, profile)
		end
	end
	player.CharacterAdded:Connect(spawnCharacter)
	if player.Character then task.spawn(spawnCharacter, player.Character) end
	push(player, profile)
	if not persistent then
		task.delay(5, function()
			if player.Parent == Players then Notify:FireClient(player, "Studio session: progress is temporary. Publish and enable API Services to test saving.", "warning") end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do task.spawn(onPlayerAdded, player) end
Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		if profile.companion then profile.companion:Destroy() end
		for attempt = 1, 3 do
			if save(profile, true) then break end
			if attempt < 3 then task.wait(attempt) end
		end
	end
end)

-- Map ProximityPrompt UI is handled by the client; all resulting actions still pass these server checks.
task.spawn(function()
	local elapsed = 0
	while not closing do
		task.wait(1)
		elapsed += 1
		for player, profile in profiles do
			profile.data.coins = math.min(MAX_COINS, profile.data.coins + totalIncome(profile))
			if profile.dig and os.clock() > profile.dig.deadline then profile.dig = nil end
			if elapsed % 2 == 0 then push(player, profile) end
			if elapsed % 60 == 0 then task.spawn(save, profile, false) end
			if elapsed % 5 == 0 and profile.companion then
				local brainrot = findBrainrot(profile, profile.data.activeBrainrot)
				local primary = profile.companion.PrimaryPart
				local label = primary and primary:FindFirstChild("CompanionLabel")
				local text = label and label:FindFirstChild("Text")
				if brainrot and text then
					local spec = lookup(Config.Creatures, brainrot.specId)
					text.Text = string.format("%s  •  Lv.%d\n$%s / sec", spec.name, brainrot.level, tostring(brainrotIncome(brainrot)))
				end
			end
		end
	end
end)

local companionTime = 0
RunService.Heartbeat:Connect(function(delta)
	companionTime += delta
	if companionTime < 0.1 then return end
	companionTime = 0
	for player, profile in profiles do
		local root = rootFor(player)
		if root and profile.companion and profile.companion.PrimaryPart then
			local target = root.CFrame * CFrame.new(3.8, -1 + math.sin(os.clock() * 3) * 0.2, 2.5)
			profile.companion:PivotTo(target)
		end
	end
end)

game:BindToClose(function()
	closing = true
	local remaining = 0
	for _, profile in profiles do
		remaining += 1
		task.spawn(function()
			for attempt = 1, 3 do
				if save(profile, true) then break end
				if attempt < 3 then task.wait(attempt) end
			end
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
end)
