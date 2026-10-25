-- Client presentation only. Inventory, purchases, digging, and rewards are server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("BrainrotShared")
local Config = require(shared:WaitForChild("Config"))
local CreatureFactory = require(shared:WaitForChild("CreatureFactory"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Notify = remotes:WaitForChild("Notify")

local C = {
	bg = Color3.fromRGB(13, 22, 31), panel = Color3.fromRGB(20, 33, 44),
	card = Color3.fromRGB(29, 46, 57), light = Color3.fromRGB(42, 63, 73),
	text = Color3.fromRGB(243, 249, 237), muted = Color3.fromRGB(166, 191, 190),
	lime = Color3.fromRGB(201, 242, 115), green = Color3.fromRGB(104, 215, 164),
	gold = Color3.fromRGB(255, 209, 116), red = Color3.fromRGB(255, 137, 135),
}
local state = nil
local activePage = nil
local selectedUid = nil
local gearTab = "Detectors"
local chosenQuantity = 1
local busy = false
local capture = nil
local capturePending = false
local viewports = {}
local renderPage
local renderedSignature = nil
local request
local openPage
local startDig
local tapDig

local screen = Instance.new("ScreenGui")
screen.Name = "BrainrotBloom"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 10
screen.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local obj = Instance.new(class)
	for key, value in pairs(props or {}) do obj[key] = value end
	obj.Parent = parent
	return obj
end
local function corner(obj, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, obj)
end
local function stroke(obj, color, transparency)
	make("UIStroke", {Color = color or C.light, Transparency = transparency or 0, Thickness = 1}, obj)
end
local function label(parent, text, size, color, props)
	local p = {
		BackgroundTransparency = 1, Text = text, TextColor3 = color or C.text,
		Font = Enum.Font.GothamMedium, TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in pairs(props or {}) do p[key] = value end
	return make("TextLabel", p, parent)
end
local function button(parent, text, onClick, props)
	local p = {
		Text = text, Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = C.text, BackgroundColor3 = C.light, BorderSizePixel = 0,
		Size = UDim2.new(0, 140, 0, 40), AutoButtonColor = true,
	}
	for key, value in pairs(props or {}) do p[key] = value end
	local b = make("TextButton", p, parent)
	corner(b, 10)
	if onClick then b.Activated:Connect(onClick) end
	return b
end
local function padding(parent, amount)
	make("UIPadding", {PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount)}, parent)
end
local function vertical(parent, gap)
	return make("UIListLayout", {Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder}, parent)
end
local function row(parent, height)
	return make("Frame", {Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1}, parent)
end
local function card(parent, height)
	local frame = make("Frame", {Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.card, BorderSizePixel = 0}, parent)
	corner(frame, 14)
	return frame
end
local function money(value)
	value = tonumber(value) or 0
	for _, unit in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do
		if value >= unit[1] then return string.format("%.1f%s", value / unit[1], unit[2]) end
	end
	return string.format("%d", math.floor(value))
end
local function seconds(value)
	value = math.max(0, math.ceil(value))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end
local function now() return workspace:GetServerTimeNow() end
local function find(list, id)
	for _, item in ipairs(list) do if item.id == id then return item end end
	return nil
end
local function contains(list, id)
	for _, item in ipairs(list or {}) do if item == id then return true end end
	return false
end
local function selected()
	for _, brainrot in ipairs(state and state.brainrots or {}) do
		if brainrot.uid == selectedUid then return brainrot end
	end
	return nil
end
local function rarity(id)
	return find(Config.Rarities, id) or {name = tostring(id), color = C.muted}
end

local hud = make("Frame", {Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 325, 0, 94),
	BackgroundColor3 = C.bg, BorderSizePixel = 0}, screen)
corner(hud, 16)
stroke(hud, C.light, 0.2)
label(hud, "BRAINROT  /  BLOOM", 11, C.lime, {Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -90, 0, 18)})
local coinsLabel = label(hud, "Loading...", 28, C.gold, {Position = UDim2.new(0, 16, 0, 30), Size = UDim2.new(1, -95, 0, 32), Font = Enum.Font.GothamBold})
local incomeLabel = label(hud, "Passive income grows with every level", 11, C.muted, {Position = UDim2.new(0, 16, 0, 65), Size = UDim2.new(1, -25, 0, 18)})
button(hud, "HOME", function() request("Teleport", {destination = "Home"}) end,
	{Position = UDim2.new(1, -74, 0, 14), Size = UDim2.new(0, 60, 0, 42), TextSize = 11})
local helpButton = button(screen, "?", function() openPage("Help") end,
	{AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = C.bg, TextSize = 21})

local nav = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.97, 0, 0, 62), BackgroundColor3 = C.bg, BorderSizePixel = 0}, screen)
make("UISizeConstraint", {MaxSize = Vector2.new(650, 62)}, nav)
corner(nav, 16)
padding(nav, 6)
make("UIGridLayout", {CellSize = UDim2.new(0.2, -5, 1, 0), CellPadding = UDim2.new(0, 6, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, nav)
local navButtons = {}
for index, page in ipairs({"Collection", "Food", "Sell", "Gear", "Worlds"}) do
	navButtons[page] = button(nav, page == "Collection" and "BAG" or string.upper(page), function()
		if page == "Food" or page == "Sell" or page == "Gear" then
			local result = request("Teleport", {destination = page})
			if not result or not result.ok then return end
		end
		openPage(page)
	end, {LayoutOrder = index, TextSize = 11})
end
local digButton = button(screen, "DETECT  [E]", function() startDig() end,
	{AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -86), Size = UDim2.new(0, 232, 0, 58),
		BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 20})
local detectorLabel = label(screen, "Walk into a sand pit to search", 12, C.text,
	{AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -148), Size = UDim2.new(0.95, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.45})

local shade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.4,
	Visible = false, BorderSizePixel = 0, Active = true}, screen)
local panel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.49),
	Size = UDim2.new(0.94, 0, 0.72, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0}, shade)
make("UISizeConstraint", {MaxSize = Vector2.new(820, 650)}, panel)
corner(panel, 20)
stroke(panel, C.light)
local title = label(panel, "COLLECTION", 23, C.text,
	{Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -88, 0, 30), Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd})
local subtitle = label(panel, "", 11, C.muted,
	{Position = UDim2.new(0, 20, 0, 47), Size = UDim2.new(1, -40, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd})
button(panel, "X", function() openPage(nil) end,
	{Position = UDim2.new(1, -53, 0, 17), Size = UDim2.new(0, 35, 0, 35), BackgroundColor3 = C.light})
local body = make("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 80), Size = UDim2.new(1, -24, 1, -92),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.lime,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y}, panel)
padding(body, 8)
vertical(body, 10)

local toast = label(screen, "", 15, C.text, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122),
	Size = UDim2.new(0.88, 0, 0, 52), BackgroundColor3 = C.bg, BackgroundTransparency = 0.05,
	TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Visible = false, ZIndex = 20})
make("UISizeConstraint", {MaxSize = Vector2.new(620, 70)}, toast)
corner(toast, 14)
padding(toast, 10)
local toastVersion = 0
local function notify(text, kind)
	toastVersion += 1
	local version = toastVersion
	toast.Text = tostring(text)
	toast.TextColor3 = kind == "error" and C.red or C.text
	toast.Visible = true
	task.delay(4, function() if version == toastVersion then toast.Visible = false end end)
end

local function viewport(parent, specId, size, pos)
	local spec = find(Config.Creatures, specId)
	if not spec then return end
	local frame = make("ViewportFrame", {Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(210, 221, 225), LightColor = Color3.fromRGB(255, 248, 219),
		LightDirection = Vector3.new(-1, -1, -2)}, parent)
	local world = make("WorldModel", {}, frame)
	local ok, model = pcall(CreatureFactory.create, spec, 1)
	if not ok or not model then return end
	model.Parent = world
	model:PivotTo(CFrame.new())
	local cf, bounds = model:GetBoundingBox()
	local radius = math.max(bounds.X, bounds.Y, bounds.Z)
	local camera = make("Camera", {FieldOfView = 35, CFrame = CFrame.lookAt(cf.Position + Vector3.new(radius * 1.25, radius * 0.6, -radius * 1.8), cf.Position)}, frame)
	frame.CurrentCamera = camera
	table.insert(viewports, {model = model, base = model:GetPivot()})
end

local function updateHud()
	if not state then return end
	coinsLabel.Text = "$ " .. money(state.coins)
	incomeLabel.Text = "+$" .. money(state.income) .. " / sec  •  " .. tostring(#(state.brainrots or {})) .. " brainrots"
	local d = find(Config.Detectors, state.detector)
	local w = find(Config.Worlds, state.world)
	detectorLabel.Text = (d and d.name or "Detector") .. "  /  " .. (w and w.name or "Meadow")
end

-- Coins tick continuously; rebuilding every card on each income tick would
-- interrupt touch input and needlessly recreate the 3D models.
local function pageSignature()
	if not state then return "loading" end
	local values = {tostring(state.detector), tostring(state.activeBrainrot), tostring(state.rotationEnds)}
	for _, id in ipairs(state.ownedDetectors or {}) do table.insert(values, id) end
	for _, id in ipairs(state.unlockedWorlds or {}) do table.insert(values, id) end
	for _, brainrot in ipairs(state.brainrots or {}) do
		table.insert(values, table.concat({brainrot.uid, brainrot.level, brainrot.xp, brainrot.income,
			brainrot.growthBoostUntil or 0, brainrot.incomeBoostUntil or 0,
			tostring((brainrot.growthBoostUntil or 0) > now()), tostring((brainrot.incomeBoostUntil or 0) > now())}, ":"))
	end
	for _, food in ipairs(Config.Foods) do table.insert(values, food.id .. ":" .. tostring((state.foods or {})[food.id] or 0)) end
	for _, slot in ipairs(state.stock or {}) do table.insert(values, slot.id .. ":" .. slot.remaining) end
	return table.concat(values, "|")
end

request = function(action, payload)
	local ok, result = pcall(function() return Action:InvokeServer(action, payload or {}) end)
	if not ok then notify("Connection interrupted. Please try again.", "error"); return nil end
	if type(result) ~= "table" then notify("The server could not complete that action.", "error"); return nil end
	if result.state then state = result.state; updateHud() end
	if result.message and action ~= "TapDig" then notify(result.message, result.ok and "success" or "error") end
	return result
end

local function perform(action, payload)
	if busy then return end
	busy = true
	local result = request(action, payload)
	busy = false
	if activePage then renderPage() end
	return result
end
local function empty(text)
	local f = card(body, 112)
	label(f, text, 15, C.muted, {Position = UDim2.new(0, 20, 0, 15), Size = UDim2.new(1, -40, 1, -30), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
end
local function smallTag(parent, text, color, pos, width)
	local tag = label(parent, text, 10, color or C.lime, {Position = pos, Size = UDim2.new(0, width or 100, 0, 22),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold})
	corner(tag, 6)
	return tag
end

local function collectionPage(sellMode)
	title.Text = sellMode and "SELL STATION" or "YOUR BRAINROTS"
	subtitle.Text = sellMode and "Select a creature to see its sale value. Selling is permanent." or "Every collected brainrot earns income, even when not displayed."
	if #(state.brainrots or {}) == 0 then
		empty("Your expedition starts in the Meadow sand pit. Tap DETECT, then complete the capture challenge!")
		button(body, "GO TO MEADOW", function() perform("Teleport", {destination = "Meadow"}); openPage(nil) end,
			{Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.lime, TextColor3 = C.bg})
		return
	end
	for _, brainrot in ipairs(state.brainrots) do
		local r = rarity(brainrot.rarity)
		local f = card(body, 140)
		viewport(f, brainrot.specId, UDim2.new(0, 96, 0, 108), UDim2.new(0, 0, 0, 4))
		label(f, brainrot.name, 16, C.text, {Position = UDim2.new(0, 102, 0, 12), Size = UDim2.new(1, -114, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd})
		label(f, r.name .. "  •  LV " .. brainrot.level, 12, r.color, {Position = UDim2.new(0, 102, 0, 39), Size = UDim2.new(1, -114, 0, 20)})
		label(f, "+$" .. money(brainrot.income) .. "/sec", 14, C.gold, {Position = UDim2.new(0, 102, 0, 63), Size = UDim2.new(1, -114, 0, 21)})
		local equipped = state.activeBrainrot == brainrot.uid
		button(f, sellMode and "SELL / DETAILS" or "FEED / DETAILS", function()
			selectedUid = brainrot.uid
			openPage(sellMode and "SellDetail" or "Detail")
		end, {Position = UDim2.new(0, 102, 0, 94), Size = UDim2.new(1, -114, 0, 34), BackgroundColor3 = sellMode and C.light or C.lime,
			TextColor3 = sellMode and C.text or C.bg, TextSize = 12})
		if equipped then smallTag(f, "DISPLAYED", C.green, UDim2.new(0, 8, 1, -29), 82) end
	end
end

local function detailPage(sellMode)
	local brainrot = selected()
	if not brainrot then selectedUid = nil; activePage = sellMode and "Sell" or "Collection"; collectionPage(sellMode); return end
	local r = rarity(brainrot.rarity)
	title.Text = brainrot.name
	subtitle.Text = r.name .. "  /  Level " .. brainrot.level .. "  /  +$" .. money(brainrot.income) .. " per second"
	button(body, "<  ALL BRAINROTS", function() openPage(sellMode and "Sell" or "Collection") end, {Size = UDim2.new(1, 0, 0, 32), TextSize = 11})
	local hero = card(body, 162)
	viewport(hero, brainrot.specId, UDim2.new(0, 132, 0, 150), UDim2.new(0, 0, 0, 2))
	label(hero, "LEVEL " .. brainrot.level, 18, r.color, {Position = UDim2.new(0, 140, 0, 16), Size = UDim2.new(1, -152, 0, 25), Font = Enum.Font.GothamBold})
	label(hero, tostring(math.floor(brainrot.xp or 0)) .. " / " .. tostring(brainrot.xpNeeded or Config.xpNeeded(brainrot.level)) .. " XP", 12, C.muted,
		{Position = UDim2.new(0, 140, 0, 47), Size = UDim2.new(1, -152, 0, 20)})
	local track = make("Frame", {Position = UDim2.new(0, 140, 0, 75), Size = UDim2.new(1, -154, 0, 8), BackgroundColor3 = C.bg, BorderSizePixel = 0}, hero)
	corner(track, 4)
	local fill = make("Frame", {Size = UDim2.new(math.clamp((brainrot.xp or 0) / math.max(1, brainrot.xpNeeded or Config.xpNeeded(brainrot.level)), 0, 1), 0, 1, 0), BackgroundColor3 = r.color, BorderSizePixel = 0}, track)
	corner(fill, 4)
	button(hero, state.activeBrainrot == brainrot.uid and "ON DISPLAY" or "DISPLAY", function() perform("EquipBrainrot", {uid = brainrot.uid}) end,
		{Position = UDim2.new(0, 140, 0, 102), Size = UDim2.new(1, -154, 0, 37), TextSize = 12})
	if sellMode then
		label(body, "Sold creatures and their levels cannot be recovered.", 12, C.muted, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		local sale = brainrot.sellValue or brainrot.value or Config.sellValue(brainrot.specId, brainrot.level)
		button(body, sale and ("SELL FOR $" .. money(sale)) or "SELL THIS BRAINROT", function()
			if activePage == "SellConfirm" then
				local result = perform("Sell", {uid = brainrot.uid})
				if result and result.ok then selectedUid = nil; openPage("Sell") end
			else activePage = "SellConfirm"; renderPage() end
		end, {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.red, TextColor3 = C.bg})
		if activePage == "SellConfirm" then
			label(body, "Tap SELL again to confirm this permanent sale.", 13, C.red, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		end
		return
	end
	local growthTime = (brainrot.growthBoostUntil or 0) - now()
	local incomeTime = (brainrot.incomeBoostUntil or 0) - now()
	if growthTime > 0 or incomeTime > 0 then
		local status = label(body, (growthTime > 0 and "2x growth: " .. seconds(growthTime) .. "   " or "") .. (incomeTime > 0 and "2x income: " .. seconds(incomeTime) or ""),
			12, C.lime, {Size = UDim2.new(1, 0, 0, 26)})
		status:SetAttribute("GrowthUntil", brainrot.growthBoostUntil or 0)
		status:SetAttribute("IncomeUntil", brainrot.incomeBoostUntil or 0)
	end
	label(body, "FEED TO GROW", 12, C.lime)
	local foodFound = false
	for _, food in ipairs(Config.Foods) do
		local owned = (state.foods or {})[food.id] or 0
		if owned > 0 then
			foodFound = true
			local f = card(body, 100)
			label(f, food.name .. "  x" .. owned, 15, C.text, {Position = UDim2.new(0, 13, 0, 9), Size = UDim2.new(1, -26, 0, 23)})
			label(f, "+" .. food.xp .. " XP each" .. (growthTime > 0 and "  (2x active!)" or ""), 11, C.muted,
				{Position = UDim2.new(0, 13, 0, 34), Size = UDim2.new(1, -26, 0, 18)})
			button(f, "FEED 1", function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = 1}) end,
				{Position = UDim2.new(0, 12, 0, 61), Size = UDim2.new(0.48, -12, 0, 29), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 11})
			local feedQuantity = math.min(owned, 100)
			button(f, owned > 100 and "FEED 100 MAX" or ("FEED ALL (" .. owned .. ")"), function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = feedQuantity}) end,
				{Position = UDim2.new(0.5, 1, 0, 61), Size = UDim2.new(0.5, -13, 0, 29), TextSize = 11})
		end
	end
	if not foodFound then empty("Your food bag is empty. Visit the rotating food shop to buy snacks.") end
	button(body, "VISIT FOOD SHOP", function() local result = perform("Teleport", {destination = "Food"}); if result and result.ok then openPage("Food") end end,
		{Size = UDim2.new(1, 0, 0, 40)})
	label(body, "FIVE-MINUTE BOOSTS  /  THIS BRAINROT", 11, C.lime)
	for _, kind in ipairs({"Growth", "Income"}) do
		local boost = Config.Boosts[kind]
		button(body, "2x " .. string.upper(kind) .. "  /  $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
			{Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.light})
	end
end

local function foodPage()
	title.Text = "THE SNACK SHACK"
	subtitle.Text = "Fresh random stock every 5 minutes. Shared rotation, personal stock."
	local qty = row(body, 44)
	label(qty, "BUY QUANTITY", 11, C.muted, {Size = UDim2.new(0.4, 0, 1, 0)})
	for index, amount in ipairs({1, 5, 10}) do
		button(qty, tostring(amount), function() chosenQuantity = amount; renderPage() end,
			{Position = UDim2.new(0.4 + (index - 1) * 0.2, 2, 0, 2), Size = UDim2.new(0.2, -5, 1, -4),
				BackgroundColor3 = chosenQuantity == amount and C.lime or C.light, TextColor3 = chosenQuantity == amount and C.bg or C.text})
	end
	local rotation = label(body, "Restocking...", 13, C.lime, {Size = UDim2.new(1, 0, 0, 28)})
	rotation.Name = "RotationCountdown"
	local stockMap = {}
	for _, slot in ipairs(state.stock or {}) do stockMap[slot.id] = slot.remaining end
	for _, food in ipairs(Config.Foods) do
		local remaining = stockMap[food.id]
		if remaining ~= nil then
			local f = card(body, 112)
			label(f, food.name, 17, C.text, {Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 0, 23)})
			label(f, "+" .. food.xp .. " XP  /  $" .. money(food.price) .. " each", 12, C.gold,
				{Position = UDim2.new(0, 14, 0, 37), Size = UDim2.new(1, -28, 0, 20)})
			label(f, "Stock " .. remaining .. "  •  In bag " .. ((state.foods or {})[food.id] or 0), 11, C.muted,
				{Position = UDim2.new(0, 14, 0, 76), Size = UDim2.new(0.5, -12, 0, 20)})
			local amount = math.min(chosenQuantity, remaining)
			button(f, remaining > 0 and ("BUY " .. amount .. "  /  $" .. money(food.price * amount)) or "SOLD OUT", function()
				if amount > 0 then perform("BuyFood", {id = food.id, quantity = amount}) end
			end, {Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.new(0.5, -12, 0, 34), TextSize = 11,
				BackgroundColor3 = remaining > 0 and C.lime or C.light, TextColor3 = remaining > 0 and C.bg or C.muted})
		end
	end
	if not next(stockMap) then empty("The shop is preparing today's snacks. Try again in a moment.") end
end

local function gearPage()
	title.Text = "FIELD EQUIPMENT"
	subtitle.Text = "Better detectors search faster and unlock rarer finds."
	local tabs = row(body, 42)
	for index, tab in ipairs({"Detectors", "Boosts"}) do
		button(tabs, string.upper(tab), function() gearTab = tab; renderPage() end,
			{Position = UDim2.new((index - 1) * 0.5, 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = gearTab == tab and C.lime or C.light, TextColor3 = gearTab == tab and C.bg or C.text})
	end
	if gearTab == "Boosts" then
		label(body, "Choose exactly which brainrot receives a boost.", 13, C.muted, {Size = UDim2.new(1, 0, 0, 36), TextWrapped = true})
		if #(state.brainrots or {}) == 0 then empty("Capture a brainrot first to use a growth or income boost."); return end
		for _, brainrot in ipairs(state.brainrots) do
			local f = card(body, 122)
			label(f, brainrot.name .. "  /  Lv " .. brainrot.level, 15, rarity(brainrot.rarity).color,
				{Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -24, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd})
			for index, kind in ipairs({"Growth", "Income"}) do
				local boost = Config.Boosts[kind]
				local untilTime = brainrot[string.lower(kind) .. "BoostUntil"] or 0
				local active = untilTime > now()
				button(f, "2x " .. kind .. " / $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
					{Position = UDim2.new((index - 1) * 0.5, 10, 0, 44), Size = UDim2.new(0.5, -15, 0, 39), TextSize = 11, BackgroundColor3 = C.light})
				local status = label(f, active and ("Active  " .. seconds(untilTime - now())) or "Lasts 5 minutes", 10, active and C.lime or C.muted,
					{Position = UDim2.new((index - 1) * 0.5, 12, 0, 88), Size = UDim2.new(0.5, -15, 0, 20)})
				if active then status:SetAttribute("BoostUntil", untilTime) end
			end
		end
		return
	end
	for _, detector in ipairs(Config.Detectors) do
		local owned = contains(state.ownedDetectors, detector.id)
		local equipped = state.detector == detector.id
		local f = card(body, 140)
		label(f, detector.name, 17, detector.color or C.text, {Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 0, 24)})
		local w = find(Config.Worlds, detector.world)
		label(f, "Power " .. detector.power .. "  •  " .. tostring(detector.speed) .. "s scan cooldown", 12, C.muted,
			{Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 20)})
		label(f, w and ("Available in " .. w.name) or "Expedition equipment", 11, C.muted,
			{Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 0, 19)})
		button(f, equipped and "EQUIPPED" or (owned and "EQUIP" or ("BUY  /  $" .. money(detector.price))), function()
			if not equipped then perform(owned and "EquipDetector" or "BuyDetector", {id = detector.id}) end
		end, {Position = UDim2.new(0, 12, 0, 94), Size = UDim2.new(1, -24, 0, 34),
			BackgroundColor3 = equipped and C.light or C.lime, TextColor3 = equipped and C.green or C.bg, TextSize = 12})
	end
end

local function worldsPage()
	title.Text = "PICK YOUR EXPEDITION"
	subtitle.Text = "Each world hides rarer brainrots. Upgrade your detector before moving on."
	for index, world in ipairs(Config.Worlds) do
		local unlocked = contains(state.unlockedWorlds, world.id)
		local f = card(body, 172)
		smallTag(f, "WORLD " .. index, world.color, UDim2.new(0, 14, 0, 12), 80)
		label(f, world.name, 21, C.text, {Position = UDim2.new(0, 14, 0, 42), Size = UDim2.new(1, -28, 0, 28), Font = Enum.Font.GothamBold})
		label(f, world.description or "Discover the creatures buried beneath the sand.", 12, C.muted,
			{Position = UDim2.new(0, 14, 0, 76), Size = UDim2.new(1, -28, 0, 34), TextWrapped = true})
		button(f, unlocked and "TELEPORT TO PIT" or ("UNLOCK  /  $" .. money(world.unlockCost)), function()
			local result = perform(unlocked and "Teleport" or "UnlockWorld", unlocked and {destination = world.id} or {id = world.id})
			if result and result.ok and unlocked then openPage(nil) end
		end, {Position = UDim2.new(0, 12, 1, -49), Size = UDim2.new(1, -24, 0, 36), BackgroundColor3 = unlocked and C.lime or C.light,
			TextColor3 = unlocked and C.bg or C.text, TextSize = 12})
	end
end

local function helpPage()
	title.Text = "WELCOME, EXPLORER"
	subtitle.Text = "Find something wonderfully weird. Help it grow. Build your collection."
	for index, entry in ipairs({
		{"DETECT", "Open WORLDS and teleport to the Meadow pit. Walk onto the sand, then press DETECT or E. Move between searches to explore."},
		{"CAPTURE", "When a brainrot appears, tap the big button or press Space enough times before the timer runs out. Rarer finds are harder!"},
		{"GROW", "Your entire collection earns coins every second. Buy food at the Snack Shack, then open BAG and select a brainrot to feed it."},
		{"UPGRADE", "Better metal detectors search faster and uncover rarer finds. Unlock the Dunes and Cosmic worlds to expand your collection."},
		{"BOOST", "The Gear Shop sells 5-minute 2x growth and income boosts. Choose a specific brainrot to receive each boost."},
		{"EXPLORE", "FOOD, SELL, and GEAR buttons teleport you straight to their shops. HOME returns to the hub. Day and night change as you play."},
	}) do
		local f = card(body, 118)
		label(f, string.format("0%d  /  %s", index, entry[1]), 12, C.lime, {Position = UDim2.new(0, 14, 0, 12), Size = UDim2.new(1, -28, 0, 22)})
		label(f, entry[2], 13, C.text, {Position = UDim2.new(0, 14, 0, 40), Size = UDim2.new(1, -28, 0, 65), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	end
	label(body, "RARITIES", 12, C.lime)
	for _, r in ipairs(Config.Rarities) do
		local f = card(body, 38)
		label(f, r.name, 14, r.color, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 1, 0)})
	end
end

renderPage = function()
	renderedSignature = pageSignature()
	for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	viewports = {}
	if not state then empty("Connecting to your expedition..."); return end
	if activePage == "Collection" or activePage == "Sell" then collectionPage(activePage == "Sell")
	elseif activePage == "Detail" or activePage == "SellDetail" or activePage == "SellConfirm" then detailPage(activePage ~= "Detail")
	elseif activePage == "Food" then foodPage()
	elseif activePage == "Gear" then gearPage()
	elseif activePage == "Worlds" then worldsPage()
	else helpPage() end
end
openPage = function(page)
	if capture then return end
	activePage = page
	shade.Visible = page ~= nil
	digButton.Visible = page == nil
	detectorLabel.Visible = page == nil
	for key, b in pairs(navButtons) do
		local on = key == page or (key == "Collection" and page == "Detail") or (key == "Sell" and (page == "SellDetail" or page == "SellConfirm"))
		b.BackgroundColor3 = on and C.lime or C.light
		b.TextColor3 = on and C.bg or C.text
	end
	if page then body.CanvasPosition = Vector2.zero; renderPage() end
end

-- The minigame reports taps to the server; the progress shown here never awards a creature.
local captureShade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.22,
	Visible = false, BorderSizePixel = 0, Active = true, ZIndex = 30}, screen)
local capturePanel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 410), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 31}, captureShade)
make("UISizeConstraint", {MaxSize = Vector2.new(480, 410)}, capturePanel)
corner(capturePanel, 22)
stroke(capturePanel, C.lime, 0.2)
label(capturePanel, "SIGNAL FOUND", 12, C.lime, {Position = UDim2.new(0, 20, 0, 22), Size = UDim2.new(1, -40, 0, 22), TextXAlignment = Enum.TextXAlignment.Center})
local captureName = label(capturePanel, "A brainrot!", 26, C.text, {Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextScaled = true})
make("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 15}, captureName)
local captureRarity = label(capturePanel, "COMMON", 13, C.muted, {Position = UDim2.new(0, 20, 0, 98), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center})
local timerLabel = label(capturePanel, "0:10", 38, C.gold, {Position = UDim2.new(0, 20, 0, 132), Size = UDim2.new(1, -40, 0, 52), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold})
local progressTrack = make("Frame", {Position = UDim2.new(0, 28, 0, 206), Size = UDim2.new(1, -56, 0, 12), BackgroundColor3 = C.bg, BorderSizePixel = 0}, capturePanel)
corner(progressTrack, 6)
local progressFill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.lime, BorderSizePixel = 0}, progressTrack)
corner(progressFill, 6)
local captureProgress = label(capturePanel, "0 / 0 taps", 14, C.text, {Position = UDim2.new(0, 20, 0, 226), Size = UDim2.new(1, -40, 0, 26), TextXAlignment = Enum.TextXAlignment.Center})
local tapButton = button(capturePanel, "TAP TO CAPTURE", function() tapDig() end,
	{Position = UDim2.new(0, 24, 0, 270), Size = UDim2.new(1, -48, 0, 72), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 22})
label(capturePanel, "Tap the button or press SPACE", 12, C.muted, {Position = UDim2.new(0, 20, 0, 358), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center})

local function endCapture(message, kind)
	capture = nil
	captureShade.Visible = false
	ContextActionService:UnbindAction("BrainrotCaptureTap")
	if message then notify(message, kind) end
end
local function celebrate(color)
	for index = 1, 20 do
		local particle = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0, index % 2 == 0 and 7 or 5, 0, 10), BackgroundColor3 = index % 3 == 0 and C.gold or color,
			BorderSizePixel = 0, Rotation = index * 18, ZIndex = 40}, screen)
		corner(particle, 2)
		TweenService:Create(particle, TweenInfo.new(0.8 + index * 0.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Position = UDim2.fromScale(0.12 + (index % 10) * 0.084, 0.55 + (index % 5) * 0.07),
				Rotation = index * 59, BackgroundTransparency = 1}):Play()
		task.delay(1.3, function() particle:Destroy() end)
	end
end
tapDig = function()
	if not capture or capturePending or capture.deadline <= os.clock() then return end
	if os.clock() - (capture.lastTap or 0) < 0.06 then return end
	capture.lastTap = os.clock()
	capturePending = true
	local session = capture
	local result = request("TapDig", {sessionId = session.id})
	capturePending = false
	if capture ~= session then return end
	if not result or not result.ok then
		endCapture(result and result.message or "Capture interrupted. Try another signal.", "error")
		return
	end
	session.taps = result.taps or result.count or (session.taps + 1)
	captureProgress.Text = session.taps .. " / " .. session.required .. " taps"
	TweenService:Create(progressFill, TweenInfo.new(0.08), {Size = UDim2.fromScale(math.clamp(session.taps / session.required, 0, 1), 1)}):Play()
	if result.complete then
		endCapture(result.message or ("Captured " .. session.name .. "! Open BAG to feed it."), "success")
		celebrate(rarity(session.rarity).color)
	end
end
startDig = function()
	if busy or capture or activePage then return end
	busy = true
	digButton.Text = "SCANNING..."
	digButton.BackgroundColor3 = C.gold
	local result = request("StartDig")
	busy = false
	digButton.Text = UserInputService.TouchEnabled and "DETECT" or "DETECT  [E]"
	digButton.BackgroundColor3 = C.lime
	if not result or not result.ok or not result.dig then return end
	local dig = result.dig
	capture = {id = dig.id, required = dig.required, duration = dig.duration, deadline = os.clock() + dig.duration, taps = 0, name = dig.name or "brainrot", rarity = dig.rarity}
	captureName.Text = capture.name
	local r = rarity(dig.rarity)
	captureRarity.Text = string.upper(r.name)
	captureRarity.TextColor3 = r.color
	progressFill.BackgroundColor3 = r.color
	progressFill.Size = UDim2.fromScale(0, 1)
	captureProgress.Text = "0 / " .. capture.required .. " taps"
	captureShade.Visible = true
	ContextActionService:BindActionAtPriority("BrainrotCaptureTap", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then task.spawn(tapDig) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space)
end

State.OnClientEvent:Connect(function(newState)
	if type(newState) ~= "table" then return end
	state = newState
	updateHud()
	-- Do not destroy an active button during a purchase response.
	if activePage and not busy and pageSignature() ~= renderedSignature then renderPage() end
end)
Notify.OnClientEvent:Connect(function(message, kind)
	if type(kind) == "string" and string.sub(kind, 1, 5) == "shop:" then
		openPage(string.sub(kind, 6))
		return
	end
	notify(message, kind)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then task.spawn(startDig)
	elseif input.KeyCode == Enum.KeyCode.B and not capture then
		if activePage then openPage(nil) else openPage("Collection") end
	elseif input.KeyCode == Enum.KeyCode.Escape and activePage then openPage(nil) end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer and triggeringPlayer ~= player then return end
	local shop = prompt:GetAttribute("Shop")
	if shop == "Food" or shop == "Sell" or shop == "Gear" then openPage(shop) end
	if prompt:GetAttribute("WorldId") then openPage("Worlds") end
end)

local animationTime = 0
local countdownAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	animationTime += dt
	countdownAccumulator += dt
	if activePage then
		for _, entry in ipairs(viewports) do
			if entry.model.Parent then entry.model:PivotTo(entry.base * CFrame.Angles(0, math.sin(animationTime * 0.55) * 0.3, 0)) end
		end
	end
	if capture then
		local remaining = capture.deadline - os.clock()
		timerLabel.Text = string.format("%.1fs", math.max(0, remaining))
		timerLabel.TextColor3 = remaining < 3 and C.red or C.gold
		if remaining <= 0 then endCapture("The signal faded! Tap faster on your next find.", "error") end
	end
	if countdownAccumulator >= 0.25 then
		countdownAccumulator = 0
		local countdown = body:FindFirstChild("RotationCountdown")
		if countdown and state then countdown.Text = "NEW ROTATION IN  " .. seconds((state.rotationEnds or now()) - now()) end
		if activePage then
			for _, item in ipairs(body:GetDescendants()) do
				if item:IsA("TextLabel") then
					local boostUntil = item:GetAttribute("BoostUntil")
					local growthUntil = item:GetAttribute("GrowthUntil")
					if boostUntil then
						local remaining = boostUntil - now()
						item.Text = remaining > 0 and ("Active  " .. seconds(remaining)) or "Boost expired"
						item.TextColor3 = remaining > 0 and C.lime or C.muted
					elseif growthUntil then
						local growth = growthUntil - now()
						local income = (item:GetAttribute("IncomeUntil") or 0) - now()
						item.Text = (growth > 0 and "2x growth: " .. seconds(growth) .. "   " or "") .. (income > 0 and "2x income: " .. seconds(income) or "")
						if growth <= 0 and income <= 0 then item.Text = "Boosts expired" end
					end
				end
			end
		end
	end
end)

local function resize()
	local size = screen.AbsoluteSize
	hud.Size = UDim2.new(0, math.min(325, math.max(250, size.X - 70)), 0, 94)
	helpButton.Position = UDim2.new(1, -12, 0, 12)
	panel.Size = UDim2.new(0.94, 0, size.Y < 500 and 0.87 or 0.72, 0)
	panel.Position = UDim2.fromScale(0.5, size.Y < 500 and 0.46 or 0.49)
	capturePanel.Size = UDim2.new(0.9, 0, 0, math.min(410, size.Y - 24))
	if size.Y < 450 then
		capturePanel.Size = UDim2.new(0.9, 0, 0, 410)
		local scale = capturePanel:FindFirstChildOfClass("UIScale") or make("UIScale", {}, capturePanel)
		scale.Scale = (size.Y - 24) / 410
	else
		local scale = capturePanel:FindFirstChildOfClass("UIScale")
		if scale then scale.Scale = 1 end
	end
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
resize()
if UserInputService.TouchEnabled then digButton.Text = "DETECT" end

task.spawn(function()
	-- Profile loading may outlast replication of the remotes, especially when
	-- Studio is waiting for DataStore retries. State events can resolve it too.
	for attempt = 1, 30 do
		if state then break end
		local ok, result = pcall(function() return Action:InvokeServer("GetState", {}) end)
		if ok and type(result) == "table" and result.ok and result.state then
			state = result.state
			break
		end
		task.wait(1)
	end
	if state then
		updateHud()
		if #(state.brainrots or {}) == 0 and not activePage and not capture then openPage("Help") end
	else
		notify("Could not load your collection. Rejoin if the connection does not recover.", "error")
	end
end)
