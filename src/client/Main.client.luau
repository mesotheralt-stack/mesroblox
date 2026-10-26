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

-- A warm field-journal palette keeps the new sculptures in focus.
local C = {
	bg = Color3.fromRGB(27, 44, 39), panel = Color3.fromRGB(245, 242, 232),
	card = Color3.fromRGB(255, 254, 249), light = Color3.fromRGB(229, 233, 220),
	text = Color3.fromRGB(35, 51, 45), muted = Color3.fromRGB(102, 116, 105),
	lime = Color3.fromRGB(186, 216, 164), green = Color3.fromRGB(74, 118, 90),
	gold = Color3.fromRGB(139, 98, 42), red = Color3.fromRGB(168, 75, 65),
	paper = Color3.fromRGB(255, 254, 246), honey = Color3.fromRGB(238, 206, 141),
	line = Color3.fromRGB(204, 212, 196), alert = Color3.fromRGB(243, 161, 153),
}

local state = nil
local activePage = nil
local selectedUid = nil
local gearTab = "Detectors"
local chosenQuantity = 1
local collectionSort = "Income"
local collectionFilter = "All"
local collectionQuery = ""
local collectionPageIndex = 1
local collectionPageSize = 12
local panelRestPosition = UDim2.fromScale(0.5, 0.49)
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
	return make("UIStroke", {Color = color or C.line, Transparency = transparency or 0, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, obj)
end
local function label(parent, text, size, color, props)
	local p = {
		BackgroundTransparency = 1, Text = text, TextColor3 = color or C.text,
		Font = Enum.Font.BuilderSans, TextSize = math.max(13, size or 16),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in pairs(props or {}) do p[key] = value end
	return make("TextLabel", p, parent)
end
local function button(parent, text, onClick, props)
	local p = {
		Text = text, Font = Enum.Font.BuilderSansMedium, TextSize = 14,
		TextColor3 = C.text, BackgroundColor3 = C.light, BorderSizePixel = 0,
		Size = UDim2.new(0, 140, 0, 44), AutoButtonColor = false,
	}
	for key, value in pairs(props or {}) do p[key] = value end
	if p.Size.Y.Scale==0 and p.Size.Y.Offset<44 then p.Size=UDim2.new(p.Size.X.Scale,p.Size.X.Offset,0,44) end
	local b = make("TextButton", p, parent)
	corner(b, 10)
	local border=stroke(b,C.bg,0.9)
	b.MouseEnter:Connect(function() TweenService:Create(border,TweenInfo.new(0.12),{Transparency=0.6}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(border,TweenInfo.new(0.12),{Transparency=0.9}):Play() end)
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
	corner(frame, 12)
	stroke(frame,C.line,0.45)
	return frame
end
local function readable(tint)
	return tint:Lerp(C.text,0.64)
end
local function badge(parent, text, tint, position, size)
	local field=label(parent,text,13,readable(tint),{Position=position,Size=size,
		BackgroundColor3=tint:Lerp(C.paper,0.82),TextXAlignment=Enum.TextXAlignment.Center,
		Font=Enum.Font.BuilderSansMedium})
	corner(field,8)
	return field
end
local function icon(parent, kind, tint, position, size)
	local root=make("Frame",{Position=position,Size=size,BackgroundTransparency=1},parent)
	local function mark(x,y,w,h,round,rotation)
		local bit=make("Frame",{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),
			BackgroundColor3=tint,BorderSizePixel=0,Rotation=rotation or 0},root)
		bit:SetAttribute("TintIcon",true)
		if round then corner(bit,round) end
		return bit
	end
	if kind=="Collection" then
		mark(0.18,0.28,0.64,0.63,4);mark(0.32,0.08,0.36,0.12,3)
	elseif kind=="Food" then
		mark(0.2,0.32,0.62,0.6,8);mark(0.52,0.09,0.12,0.26,2,-20);mark(0.65,0.09,0.24,0.13,4,-24)
	elseif kind=="Sell" then
		mark(0.12,0.64,0.76,0.19,5);mark(0.2,0.39,0.6,0.18,5);mark(0.31,0.14,0.39,0.18,5)
	elseif kind=="Gear" then
		mark(0.46,0.07,0.12,0.6,3,-28);mark(0.17,0.65,0.64,0.2,8);mark(0.54,0.1,0.25,0.12,2,-28)
	else
		mark(0.19,0.19,0.62,0.62,10);mark(0.42,0.04,0.16,0.25,2);mark(0.42,0.71,0.16,0.25,2)
	end
	return root
end
local function previewStage(parent,tint,position,size)
	local stage=make("Frame",{Position=position,Size=size,BackgroundColor3=tint:Lerp(C.paper,0.86),BorderSizePixel=0,ClipsDescendants=true},parent)
	corner(stage,12)
	local halo=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.62,0.86),BackgroundColor3=tint,BackgroundTransparency=0.8,BorderSizePixel=0},stage)
	corner(halo,200)
	local ground=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.86),Size=UDim2.fromScale(0.48,0.07),BackgroundColor3=C.bg,BackgroundTransparency=0.9,BorderSizePixel=0},stage)
	corner(ground,100)
	return stage
end
local function landscape(parent,world,position,size)
	local stage=make("Frame",{Position=position,Size=size,BackgroundColor3=world.color:Lerp(C.paper,0.68),BorderSizePixel=0,ClipsDescendants=true},parent)
	corner(stage,12)
	local function block(x,y,w,h,color,radius,rotation)
		local piece=make("Frame",{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,BorderSizePixel=0,Rotation=rotation or 0},stage)
		if radius then corner(piece,radius) end
		return piece
	end
	block(0.72,0.12,0.14,0.2,world.id=="Cosmic" and C.paper or C.honey,100)
	local distant=world.color:Lerp(C.green,0.45)
	block(-0.15,0.42,0.82,0.9,distant,100,-8)
	block(0.45,0.3,0.82,0.95,world.color:Lerp(C.green,0.6),100,12)
	local ground=world.id=="Meadow" and Color3.fromRGB(159,188,127) or world.id=="Dunes" and Color3.fromRGB(216,175,116) or Color3.fromRGB(144,149,172)
	block(0,0.7,1,0.4,ground)
	block(0.25,0.77,0.5,0.17,world.id=="Cosmic" and Color3.fromRGB(204,185,224) or Color3.fromRGB(238,215,166),6)
	if world.id=="Meadow" then
		for i=1,3 do
			local x=0.05+(i-1)*0.1
			block(x+0.035,0.56,0.025,0.23,C.gold,2)
			block(x,0.4,0.1,0.25,C.green,20)
		end
	elseif world.id=="Dunes" then
		for _,x in ipairs({0.09,0.8}) do
			block(x,0.4,0.04,0.4,Color3.fromRGB(172,130,86),2)
			block(x-0.04,0.36,0.14,0.05,C.green,3,-18)
			block(x-0.05,0.34,0.14,0.05,C.green,3,18)
		end
		block(0.58,0.42,0.04,0.25,C.paper,1);block(0.7,0.42,0.04,0.25,C.paper,1);block(0.58,0.39,0.16,0.05,C.paper,1)
	else
		for i=1,4 do block(0.07+i*0.07,0.58-(i%2)*0.12,0.035,0.23,Color3.fromRGB(226,216,255),2,22) end
		block(0.73,0.56,0.18,0.2,Color3.fromRGB(104,111,147),100)
	end
	return stage
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

local hud = make("Frame", {Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 290, 0, 86),
	BackgroundColor3 = C.panel, BorderSizePixel = 0}, screen)
corner(hud, 16)
stroke(hud, C.light, 0.2)
label(hud, "Brainrot Bloom", 12, C.green, {Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -90, 0, 18)})
icon(hud,"Sell",C.gold,UDim2.fromOffset(16,33),UDim2.fromOffset(15,18))
local coinsLabel = label(hud, "Loading…", 25, C.gold, {Position = UDim2.new(0, 39, 0, 27), Size = UDim2.new(1, -118, 0, 28), Font = Enum.Font.BuilderSansBold})
local incomeLabel = label(hud, "Passive income grows with every level", 11, C.muted, {Position = UDim2.new(0, 16, 0, 62), Size = UDim2.new(1, -25, 0, 18)})
button(hud, "Home", function() request("Teleport", {destination = "Home"}) end,
	{Position = UDim2.new(1, -74, 0, 14), Size = UDim2.new(0, 60, 0, 40), TextSize = 13})
local helpButton = button(screen, "?", function() openPage("Help") end,
	{AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = C.panel, TextSize = 21, ZIndex=10})

local nav = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.97, 0, 0, 62), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex=10}, screen)
make("UISizeConstraint", {MaxSize = Vector2.new(720, 62)}, nav)
corner(nav, 16)
padding(nav, 6)
make("UIGridLayout", {CellSize = UDim2.new(0.2, -5, 1, 0), CellPadding = UDim2.new(0, 6, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, nav)
local navButtons = {}
local navIcons = {}
for index, page in ipairs({"Collection", "Food", "Sell", "Gear", "Worlds"}) do
	navButtons[page] = button(nav, page == "Collection" and "Collection" or page, function()
		if page == "Food" or page == "Sell" or page == "Gear" then
			local result = request("Teleport", {destination = page})
			if not result or not result.ok then return end
		end
		openPage(page)
	end, {LayoutOrder = index, TextSize = 13, TextYAlignment=Enum.TextYAlignment.Bottom, BackgroundColor3=C.panel})
	make("UIPadding",{PaddingBottom=UDim.new(0,5)},navButtons[page])
	navIcons[page]=icon(navButtons[page],page,C.muted,UDim2.new(0.5,-9,0,3),UDim2.fromOffset(18,18))
end
local digButton = button(screen, "Dig  ·  E", function() startDig() end,
	{AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -86), Size = UDim2.new(0, 176, 0, 48),
		BackgroundColor3 = C.bg, TextColor3 = C.paper, TextSize = 17})
local detectorLabel = label(screen, "Walk into a sand pit to search", 12, C.paper,
	{AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -142), Size = UDim2.new(0.95, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.45})

local shade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.55,
	Visible = false, BorderSizePixel = 0, Active = true, ZIndex=5}, screen)
local panel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.49),
	Size = UDim2.new(0.94, 0, 0.72, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0}, shade)
make("UISizeConstraint", {MaxSize = Vector2.new(900, 720)}, panel)
corner(panel, 20)
stroke(panel, C.light)
label(panel,"FIELD JOURNAL",11,C.green,{Position=UDim2.fromOffset(22,12),Size=UDim2.new(1,-100,0,18),Font=Enum.Font.BuilderSansMedium})
local title = label(panel, "Collection", 24, C.text,
	{Position = UDim2.new(0, 22, 0, 31), Size = UDim2.new(1, -100, 0, 30), Font = Enum.Font.BuilderSansBold, TextTruncate = Enum.TextTruncate.AtEnd})
local subtitle = label(panel, "", 13, C.muted,
	{Position = UDim2.new(0, 22, 0, 64), Size = UDim2.new(1, -44, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd})
button(panel, "×", function() openPage(nil) end,
	{Position = UDim2.new(1, -62, 0, 22), Size = UDim2.new(0, 42, 0, 42), BackgroundColor3 = C.light})
make("Frame",{Position=UDim2.new(0,22,0,94),Size=UDim2.new(1,-44,0,1),BackgroundColor3=C.line,BorderSizePixel=0},panel)
local body = make("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 104), Size = UDim2.new(1, -24, 1, -116),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.green,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y}, panel)
padding(body, 8)
vertical(body, 10)

local toast = label(screen, "", 15, C.paper, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102),
	Size = UDim2.new(0.88, 0, 0, 52), BackgroundColor3 = C.bg, BackgroundTransparency = 0.05,
	TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Visible = false, ZIndex = 20})
make("UISizeConstraint", {MaxSize = Vector2.new(540, 70)}, toast)
corner(toast, 14)
padding(toast, 10)
local toastVersion = 0
local function notify(text, kind)
	toastVersion += 1
	local version = toastVersion
	toast.Text = tostring(text)
	toast.TextColor3 = kind == "error" and C.alert or C.paper
	toast.Visible = true
	task.delay(4, function() if version == toastVersion then toast.Visible = false end end)
end

local function viewport(parent, specId, size, pos)
	local spec = find(Config.Creatures, specId)
	if not spec then return end
	local frame = make("ViewportFrame", {Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(205, 220, 210), LightColor = Color3.fromRGB(255, 248, 219),
		LightDirection = Vector3.new(-1, -1, -2)}, parent)
	local world = make("WorldModel", {}, frame)
	local ok, model = pcall(CreatureFactory.create, spec, 1)
	if not ok or not model then return end
	model.Parent = world
	model:PivotTo(CFrame.new())
	local cf, bounds = model:GetBoundingBox()
	local camera=make("Camera",{FieldOfView=35},frame)
	local direction=Vector3.new(0.65,0.35,-1.75)
	direction=direction/direction.Magnitude
	local function fitCamera()
		local pixels=frame.AbsoluteSize
		local aspect=math.max(0.2,pixels.X/math.max(1,pixels.Y))
		local halfFov=math.atan(math.tan(math.rad(35/2))*math.min(1,aspect))
		local distance=(bounds.Magnitude/2)/math.sin(halfFov)*1.05
		camera.CFrame=CFrame.lookAt(cf.Position+direction*distance,cf.Position)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
	fitCamera()
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
	local tag = label(parent, text, 10, readable(color or C.green), {Position = pos, Size = UDim2.new(0, width or 100, 0, 22),
		BackgroundColor3 = C.light, BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold})
	corner(tag, 6)
	return tag
end

local function collectionPage(sellMode)
	title.Text = sellMode and "Sell a brainrot" or "Your collection"
	subtitle.Text = sellMode and "Choose a creature to review its value before selling." or "Every brainrot earns coins. Pick one to feed and grow."
	if #(state.brainrots or {}) == 0 then
		empty("Your first discovery is waiting beneath the sand. Head to Clover Commons to start collecting.")
		button(body, "Find my first brainrot", function() local result=perform("Teleport",{destination="Meadow"}); if result and result.ok then openPage(nil) end end,
			{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.lime,TextColor3=C.bg})
		return
	end
	local controls=row(body,44)
	local search=make("TextBox",{Size=UDim2.new(0.56,-6,1,0),BackgroundColor3=C.card,TextColor3=C.text,
		PlaceholderText="Search your collection…",PlaceholderColor3=C.muted,Text=collectionQuery,ClearTextOnFocus=false,
		Font=Enum.Font.BuilderSans,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},controls)
	corner(search,10); padding(search,10)
	search.FocusLost:Connect(function()
		if search.Text~=collectionQuery then
			collectionQuery=search.Text; collectionPageIndex=1
			task.defer(renderPage)
		end
	end)
	button(controls,"Sort: "..collectionSort,function()
		local options={"Income","Rarity","Level"}
		collectionSort=options[(table.find(options,collectionSort) or 1)%#options+1]
		collectionPageIndex=1; renderPage()
	end,{Position=UDim2.new(0.56,6,0,0),Size=UDim2.new(0.44,-6,1,0),TextSize=13})
	local filters=make("ScrollingFrame",{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,BorderSizePixel=0,
		AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=0,
		ScrollingDirection=Enum.ScrollingDirection.X},body)
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},filters)
	local categories={"All"}
	for _,r in ipairs(Config.Rarities) do table.insert(categories,r.id) end
	for index,id in ipairs(categories) do
		local chosen=collectionFilter==id
		button(filters,id,function() collectionFilter=id; collectionPageIndex=1; renderPage() end,
			{Size=UDim2.new(0,(id=="Uncommon" or id=="Legendary") and 100 or 86,0,38),LayoutOrder=index,
				BackgroundColor3=chosen and C.lime or C.card,TextColor3=chosen and C.bg or C.muted,TextSize=13})
	end
	local list={}
	local ranks={}
	for index,r in ipairs(Config.Rarities) do ranks[r.id]=index end
	for _,b in ipairs(state.brainrots) do
		if (collectionFilter=="All" or b.rarity==collectionFilter) and string.find(string.lower(b.name),string.lower(collectionQuery),1,true) then table.insert(list,b) end
	end
	table.sort(list,function(a,b)
		local av=collectionSort=="Rarity" and ranks[a.rarity] or collectionSort=="Level" and a.level or a.income
		local bv=collectionSort=="Rarity" and ranks[b.rarity] or collectionSort=="Level" and b.level or b.income
		if av==bv then return a.uid<b.uid end
		return av>bv
	end)
	if #list==0 then empty("No matches. Try a different name or rarity."); return end
	local pages=math.max(1,math.ceil(#list/collectionPageSize))
	collectionPageIndex=math.clamp(collectionPageIndex,1,pages)
	local first=(collectionPageIndex-1)*collectionPageSize+1
	local last=math.min(#list,first+collectionPageSize-1)
	label(body,string.format("%d brainrots  ·  %d/%d collected",#list,#state.brainrots,Config.MaxBrainrots),13,C.muted)
	local columns=body.AbsoluteSize.X>=660 and 3 or 2
	local gap=12
	local grid=row(body,math.ceil((last-first+1)/columns)*296-gap)
	make("UIGridLayout",{CellSize=UDim2.new(1/columns,-gap*(columns-1)/columns,0,284),CellPadding=UDim2.fromOffset(gap,gap),SortOrder=Enum.SortOrder.LayoutOrder},grid)
	for index=first,last do
		local b=list[index]
		local r=rarity(b.rarity)
		local tile=card(grid,284)
		tile.LayoutOrder=index
		previewStage(tile,r.color,UDim2.fromOffset(10,10),UDim2.new(1,-20,0,126))
		viewport(tile,b.specId,UDim2.new(1,-12,0,126),UDim2.fromOffset(6,8))
		label(tile,b.name,15,C.text,{Position=UDim2.fromOffset(12,143),Size=UDim2.new(1,-24,0,38),TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,Font=Enum.Font.BuilderSansBold})
		label(tile,r.name.." · Lv "..b.level,12,readable(r.color),{Position=UDim2.fromOffset(12,183),Size=UDim2.new(1,-24,0,18)})
		label(tile,"+$"..money(b.income).." / sec",14,C.gold,{Position=UDim2.fromOffset(12,207),Size=UDim2.new(1,-24,0,20),Font=Enum.Font.BuilderSansMedium})
		button(tile,sellMode and "Review sale" or "Feed & grow",function() selectedUid=b.uid; openPage(sellMode and "SellDetail" or "Detail") end,
			{Position=UDim2.new(0,10,1,-52),Size=UDim2.new(1,-20,0,44),TextSize=13,BackgroundColor3=C.light})
		if state.activeBrainrot==b.uid then smallTag(tile,"Following",C.green,UDim2.fromOffset(16,16),76) end
	end
	if pages>1 then
		local paging=row(body,44)
		button(paging,"Previous",function() collectionPageIndex=math.max(1,collectionPageIndex-1); renderPage(); body.CanvasPosition=Vector2.zero end,
			{Size=UDim2.new(0.32,0,1,0),TextSize=13})
		label(paging,collectionPageIndex.." / "..pages,13,C.muted,{Position=UDim2.new(0.33,0,0,0),Size=UDim2.new(0.34,0,1,0),TextXAlignment=Enum.TextXAlignment.Center})
		button(paging,"Next",function() collectionPageIndex=math.min(pages,collectionPageIndex+1); renderPage(); body.CanvasPosition=Vector2.zero end,
			{Position=UDim2.new(0.68,0,0,0),Size=UDim2.new(0.32,0,1,0),TextSize=13})
	end
end

local function detailPage(sellMode)
	local brainrot = selected()
	if not brainrot then selectedUid = nil; activePage = sellMode and "Sell" or "Collection"; collectionPage(sellMode); return end
	local r = rarity(brainrot.rarity)
	title.Text = brainrot.name
	subtitle.Text = r.name .. "  ·  Level " .. brainrot.level .. "  /  +$" .. money(brainrot.income) .. " per second"
	button(body, "‹ Back to collection", function() openPage(sellMode and "Sell" or "Collection") end, {Size = UDim2.new(1, 0, 0, 32), TextSize = 13})
	local hero = card(body, 204)
	previewStage(hero,r.color,UDim2.fromOffset(12,12),UDim2.new(0.48,-12,1,-24))
	viewport(hero,brainrot.specId,UDim2.new(0.48,-8,1,-16),UDim2.fromOffset(8,8))
	label(hero,"Level "..brainrot.level.." / "..Config.MaxLevel,18,C.text,{Position=UDim2.new(0.5,8,0,17),Size=UDim2.new(0.5,-24,0,28),Font=Enum.Font.BuilderSansBold})
	local maxed=brainrot.level>=Config.MaxLevel
	label(hero,maxed and "Fully grown" or (tostring(math.floor(brainrot.xp or 0)).." / "..tostring(brainrot.xpNeeded or Config.xpNeeded(brainrot.level)).." XP"),13,C.muted,
		{Position=UDim2.new(0.5,8,0,49),Size=UDim2.new(0.5,-24,0,21)})
	local track=make("Frame",{Position=UDim2.new(0.5,8,0,79),Size=UDim2.new(0.5,-24,0,7),BackgroundColor3=C.light,BorderSizePixel=0},hero)
	corner(track,4)
	local fill=make("Frame",{Size=UDim2.new(maxed and 1 or math.clamp((brainrot.xp or 0)/math.max(1,brainrot.xpNeeded or Config.xpNeeded(brainrot.level)),0,1),0,1,0),BackgroundColor3=readable(r.color),BorderSizePixel=0},track)
	corner(fill,4)
	local incomeFactor=(brainrot.incomeBoostUntil or 0)>now() and 2 or 1
	local nextIncome=Config.income(brainrot.specId,math.min(Config.MaxLevel,brainrot.level+1))*incomeFactor
	label(hero,maxed and "A perfect little earner." or ("Next level: $"..money(nextIncome).." / sec"),13,C.gold,
		{Position=UDim2.new(0.5,8,0,98),Size=UDim2.new(0.5,-24,0,34),TextWrapped=true})
	button(hero,state.activeBrainrot==brainrot.uid and "Following you" or "Set as companion",function() perform("EquipBrainrot",{uid=brainrot.uid}) end,
		{Position=UDim2.new(0.5,8,0,145),Size=UDim2.new(0.5,-24,0,44),TextSize=13,BackgroundColor3=C.light})
	if sellMode then
		label(body, "Sold creatures and their levels cannot be recovered.", 12, C.muted, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		local sale = brainrot.sellValue or brainrot.value or Config.sellValue(brainrot.specId, brainrot.level)
		button(body, sale and ("Sell for $" .. money(sale)) or "Sell this brainrot", function()
			if activePage == "SellConfirm" then
				local result = perform("Sell", {uid = brainrot.uid})
				if result and result.ok then selectedUid = nil; openPage("Sell") end
			else activePage = "SellConfirm"; renderPage() end
		end, {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.red, TextColor3 = C.paper})
		if activePage == "SellConfirm" then
			label(body, "Tap SELL again to confirm this permanent sale.", 13, C.red, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		end
		return
	end
	local growthTime = (brainrot.growthBoostUntil or 0) - now()
	local incomeTime = (brainrot.incomeBoostUntil or 0) - now()
	if growthTime > 0 or incomeTime > 0 then
		local status = label(body, (growthTime > 0 and "2x growth: " .. seconds(growthTime) .. "   " or "") .. (incomeTime > 0 and "2x income: " .. seconds(incomeTime) or ""),
			12, C.green, {Size = UDim2.new(1, 0, 0, 26)})
		status:SetAttribute("GrowthUntil", brainrot.growthBoostUntil or 0)
		status:SetAttribute("IncomeUntil", brainrot.incomeBoostUntil or 0)
	end
	label(body, "Feed to grow", 12, C.green)
	local foodFound = false
	for _, food in ipairs(Config.Foods) do
		local owned = (state.foods or {})[food.id] or 0
		if owned > 0 then
			foodFound = true
			local f = card(body, 126)
			label(f, food.name .. "  x" .. owned, 15, C.text, {Position = UDim2.new(0, 13, 0, 9), Size = UDim2.new(1, -26, 0, 23)})
			label(f, "+" .. food.xp .. " XP each" .. (growthTime > 0 and "  (2x active!)" or ""), 11, C.muted,
				{Position = UDim2.new(0, 13, 0, 34), Size = UDim2.new(1, -26, 0, 18)})
			button(f, "Feed one", function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = 1}) end,
				{Position = UDim2.new(0, 12, 0, 61), Size = UDim2.new(0.48, -12, 0, 44), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 13})
			local feedQuantity = math.min(owned, 100)
			button(f, owned > 100 and "Feed 100" or ("Feed all (" .. owned .. ")"), function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = feedQuantity}) end,
				{Position = UDim2.new(0.5, 1, 0, 61), Size = UDim2.new(0.5, -13, 0, 44), TextSize = 13})
		end
	end
	if not foodFound then empty("Your food bag is empty. Visit the rotating food shop to buy snacks.") end
	button(body, "Visit food shop", function() local result = perform("Teleport", {destination = "Food"}); if result and result.ok then openPage("Food") end end,
		{Size = UDim2.new(1, 0, 0, 40)})
	label(body, "Five-minute boosts · this brainrot", 11, C.green)
	for _, kind in ipairs({"Growth", "Income"}) do
		local boost = Config.Boosts[kind]
		button(body, "2x " .. kind .. "  /  $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
			{Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.light})
	end
end

local function foodPage()
	title.Text = "Food market"
	subtitle.Text = "Fresh random stock every 5 minutes. Shared rotation, personal stock."
	local qty = row(body, 44)
	label(qty, "Buy quantity", 11, C.muted, {Size = UDim2.new(0.4, 0, 1, 0)})
	for index, amount in ipairs({1, 5, 10}) do
		button(qty, tostring(amount), function() chosenQuantity = amount; renderPage() end,
			{Position = UDim2.new(0.4 + (index - 1) * 0.2, 2, 0, 2), Size = UDim2.new(0.2, -5, 1, -4),
				BackgroundColor3 = chosenQuantity == amount and C.lime or C.light, TextColor3 = chosenQuantity == amount and C.bg or C.text})
	end
	local rotation=label(body,"Restocking…",13,C.green,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.light,TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.BuilderSansMedium})
	rotation.Name="RotationCountdown"
	corner(rotation,10)
	local stockMap = {}
	for _, slot in ipairs(state.stock or {}) do stockMap[slot.id] = slot.remaining end
	for _, food in ipairs(Config.Foods) do
		local remaining = stockMap[food.id]
		if remaining ~= nil then
			local f=card(body,148)
			local token=make("Frame",{Position=UDim2.fromOffset(14,14),Size=UDim2.fromOffset(58,58),BackgroundColor3=C.light,BorderSizePixel=0},f)
			corner(token,16)
			label(token,food.emoji or "•",30,C.text,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
			label(f,food.name,16,C.text,{Position=UDim2.fromOffset(84,13),Size=UDim2.new(1,-98,0,36),TextWrapped=true,Font=Enum.Font.BuilderSansMedium})
			badge(f,"+"..food.xp.." XP",C.green,UDim2.fromOffset(84,51),UDim2.fromOffset(116,21))
			label(f,"$"..money(food.price).." each",13,C.gold,{Position=UDim2.fromOffset(84,73),Size=UDim2.new(1,-98,0,20)})
			label(f,remaining.." in stock",13,C.muted,{Position=UDim2.fromOffset(14,99),Size=UDim2.new(0.5,-20,0,18)})
			label(f,"Pantry: "..((state.foods or {})[food.id] or 0),13,C.muted,{Position=UDim2.fromOffset(14,120),Size=UDim2.new(0.5,-20,0,18)})
			local amount=math.min(chosenQuantity,remaining)
			button(f,remaining>0 and ("Buy "..amount.." · $"..money(food.price*amount)) or "Sold out",function()
				if amount>0 then perform("BuyFood",{id=food.id,quantity=amount}) end
			end,{Position=UDim2.new(0.5,0,1,-56),Size=UDim2.new(0.5,-14,0,44),TextSize=13,
				BackgroundColor3=remaining>0 and C.lime or C.light,TextColor3=remaining>0 and C.bg or C.muted})
		end
	end
	if not next(stockMap) then empty("The shop is preparing today's snacks. Try again in a moment.") end
end

local function gearPage()
	title.Text = "Gear workshop"
	subtitle.Text = "Better detectors search faster and unlock rarer finds."
	local tabs = row(body, 42)
	for index, tab in ipairs({"Detectors", "Boosts"}) do
		button(tabs, tab, function() gearTab = tab; renderPage() end,
			{Position = UDim2.new((index - 1) * 0.5, 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = gearTab == tab and C.lime or C.light, TextColor3 = gearTab == tab and C.bg or C.text})
	end
	if gearTab == "Boosts" then
		label(body, "Choose exactly which brainrot receives a boost.", 13, C.muted, {Size = UDim2.new(1, 0, 0, 36), TextWrapped = true})
		if #(state.brainrots or {}) == 0 then empty("Capture a brainrot first to use a growth or income boost."); return end
		for _, brainrot in ipairs(state.brainrots) do
			local f = card(body, 122)
			label(f, brainrot.name .. "  /  Lv " .. brainrot.level, 15, readable(rarity(brainrot.rarity).color),
				{Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -24, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd})
			for index, kind in ipairs({"Growth", "Income"}) do
				local boost = Config.Boosts[kind]
				local untilTime = brainrot[string.lower(kind) .. "BoostUntil"] or 0
				local active = untilTime > now()
				button(f, "2x " .. kind .. " / $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
					{Position = UDim2.new((index - 1) * 0.5, 10, 0, 44), Size = UDim2.new(0.5, -15, 0, 39), TextSize = 13, BackgroundColor3 = C.light})
				local status = label(f, active and ("Active  " .. seconds(untilTime - now())) or "Lasts 5 minutes", 10, active and C.green or C.muted,
					{Position = UDim2.new((index - 1) * 0.5, 12, 0, 88), Size = UDim2.new(0.5, -15, 0, 20)})
				if active then status:SetAttribute("BoostUntil", untilTime) end
			end
		end
		return
	end
	for _,detector in ipairs(Config.Detectors) do
		local owned=contains(state.ownedDetectors,detector.id)
		local equipped=state.detector==detector.id
		local f=card(body,206)
		local tint=detector.color or C.green
		local token=make("Frame",{Position=UDim2.fromOffset(14,16),Size=UDim2.fromOffset(74,90),BackgroundColor3=tint:Lerp(C.paper,0.78),BorderSizePixel=0},f)
		corner(token,12)
		icon(token,"Gear",readable(tint),UDim2.fromOffset(13,15),UDim2.fromOffset(48,56))
		label(f,detector.name,17,C.text,{Position=UDim2.fromOffset(102,13),Size=UDim2.new(1,-116,0,38),TextWrapped=true,Font=Enum.Font.BuilderSansBold})
		local ceiling=Config.Rarities[math.min(detector.power,#Config.Rarities)]
		label(f,"Finds through "..ceiling.name,13,readable(ceiling.color),{Position=UDim2.fromOffset(102,56),Size=UDim2.new(1,-116,0,21)})
		label(f,tostring(detector.speed).."s between scans",13,C.muted,{Position=UDim2.fromOffset(102,80),Size=UDim2.new(1,-116,0,21)})
		local w=find(Config.Worlds,detector.world)
		local available=contains(state.unlockedWorlds,detector.world)
		label(f,available and ("Power "..detector.power.." / "..#Config.Rarities) or ("Requires "..(w and w.name or detector.world)),13,available and C.muted or C.red,
			{Position=UDim2.fromOffset(14,116),Size=UDim2.new(1,-28,0,19),TextTruncate=Enum.TextTruncate.AtEnd})
		for rank=1,#Config.Rarities do
			local segment=make("Frame",{Position=UDim2.new((rank-1)/#Config.Rarities,14-(rank-1)*22/#Config.Rarities,0,140),Size=UDim2.new(1/#Config.Rarities,-(28+6*(#Config.Rarities-1))/#Config.Rarities,0,5),
				BackgroundColor3=rank<=detector.power and readable(tint) or C.light,BorderSizePixel=0},f)
			corner(segment,3)
		end
		button(f,equipped and "Equipped" or (owned and "Equip" or ("Buy · $"..money(detector.price))),function()
			if not equipped then perform(owned and "EquipDetector" or "BuyDetector",{id=detector.id}) end
		end,{Position=UDim2.new(0,14,1,-56),Size=UDim2.new(1,-28,0,44),BackgroundColor3=equipped and C.light or C.lime,
			TextColor3=equipped and C.green or C.bg,TextSize=14})
	end
end

local function worldsPage()
	title.Text="Choose a world"
	subtitle.Text="A new landscape, new discoveries. Your next adventure starts here."
	local wide=body.AbsoluteSize.X>=620
	local detector=find(Config.Detectors,state.detector)
	for index,world in ipairs(Config.Worlds) do
		local unlocked=contains(state.unlockedWorlds,world.id)
		local f=card(body,wide and 212 or 302)
		landscape(f,world,UDim2.fromOffset(12,12),wide and UDim2.new(0.36,-12,1,-24) or UDim2.new(1,-24,0,104))
		local xScale,xOffset=wide and 0.38 or 0,wide and 0 or 16
		local top=wide and 16 or 126
		label(f,"EXPEDITION 0"..index,12,C.green,{Position=UDim2.new(xScale,xOffset,0,top),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,18),Font=Enum.Font.BuilderSansMedium})
		label(f,world.name,21,C.text,{Position=UDim2.new(xScale,xOffset,0,top+22),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,30),Font=Enum.Font.BuilderSansBold,TextTruncate=Enum.TextTruncate.AtEnd})
		label(f,world.description or "A landscape of strange little discoveries.",13,C.muted,{Position=UDim2.new(xScale,xOffset,0,top+56),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,36),TextWrapped=true})
		local canDig=detector and detector.power>=world.minPower
		label(f,"Power "..world.minPower.."+ · Up to "..Config.Rarities[world.maxRarity].name,13,canDig and C.green or C.red,
			{Position=UDim2.new(xScale,xOffset,0,top+98),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,20)})
		button(f,unlocked and "Travel to sand pit" or ("Unlock · $"..money(world.unlockCost)),function()
			local result=perform(unlocked and "Teleport" or "UnlockWorld",unlocked and {destination=world.id} or {id=world.id})
			if result and result.ok then openPage(nil) end
		end,{Position=UDim2.new(xScale,xOffset,1,-56),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,44),
			BackgroundColor3=unlocked and C.lime or C.light,TextColor3=C.bg,TextSize=14})
	end
end

local function helpPage()
	title.Text="A little guide"
	subtitle.Text="Find something weird. Feed it. Watch your garden grow."
	button(body,"Take me to the sand pit",function()
		local result=perform("Teleport",{destination="Meadow"})
		if result and result.ok then openPage(nil) end
	end,{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.lime,TextColor3=C.bg})
	for _,entry in ipairs({
		{"Find & collect","Stand on the sand and choose Dig (E). A scan takes one second, with a 50% chance to find a signal. Tap or press Space to capture it."},
		{"Feed & grow","Open Collection, choose a brainrot, and feed it from your pantry. Every creature earns coins while you play."},
		{"Upgrade your kit","Food, Sell, and Gear take you straight to their shops. Stronger detectors uncover higher rarities; boosts last five minutes."},
		{"Explore further","Worlds lets you unlock and travel to larger hunting grounds. Your coins, creatures, and upgrades are saved when saving is available."},
	}) do
		local f=card(body,112)
		label(f,entry[1],16,C.text,{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,24),Font=Enum.Font.BuilderSansMedium})
		label(f,entry[2],14,C.muted,{Position=UDim2.fromOffset(16,39),Size=UDim2.new(1,-32,0,65),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	end
end

renderPage = function()
	renderedSignature = pageSignature()
	local scrollPosition = body.CanvasPosition
	for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	viewports = {}
	if not state then empty("Connecting to your expedition..."); return end
	if activePage == "Collection" or activePage == "Sell" then collectionPage(activePage == "Sell")
	elseif activePage == "Detail" or activePage == "SellDetail" or activePage == "SellConfirm" then detailPage(activePage ~= "Detail")
	elseif activePage == "Food" then foodPage()
	elseif activePage == "Gear" then gearPage()
	elseif activePage == "Worlds" then worldsPage()
	else helpPage() end
	body.CanvasPosition = scrollPosition
end
openPage = function(page)
	if capture then return end
	local previousPage = activePage
	activePage = page
	shade.Visible = page ~= nil
	digButton.Visible = page == nil
	detectorLabel.Visible = page == nil
	for key, b in pairs(navButtons) do
		local on = key == page or (key == "Collection" and page == "Detail") or (key == "Sell" and (page == "SellDetail" or page == "SellConfirm"))
		b.BackgroundColor3 = on and C.bg or C.panel
		b.TextColor3 = on and C.paper or C.muted
		for _,piece in ipairs(navIcons[key]:GetDescendants()) do
			if piece:GetAttribute("TintIcon") then piece.BackgroundColor3=on and C.paper or C.muted end
		end
	end
	if page then
		body.CanvasPosition=Vector2.zero; renderPage()
		if previousPage~=page then
			panel.Position=panelRestPosition+UDim2.fromOffset(0,8)
			TweenService:Create(panel,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=panelRestPosition}):Play()
		end
	end
end

-- The minigame reports taps to the server; the progress shown here never awards a creature.
local captureShade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.22,
	Visible = false, BorderSizePixel = 0, Active = true, ZIndex = 30}, screen)
local capturePanel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 410), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 31}, captureShade)
make("UISizeConstraint", {MaxSize = Vector2.new(440, 410)}, capturePanel)
corner(capturePanel, 22)
stroke(capturePanel, C.lime, 0.2)
label(capturePanel, "You found a signal", 12, C.green, {Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 22), TextXAlignment = Enum.TextXAlignment.Center})
local captureName = label(capturePanel, "A brainrot!", 26, C.text, {Position = UDim2.new(0, 20, 0, 43), Size = UDim2.new(1, -40, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold, TextScaled = true})
make("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 15}, captureName)
local captureRarity = label(capturePanel, "COMMON", 13, C.muted, {Position = UDim2.new(0, 20, 0, 79), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center})
local timerLabel = label(capturePanel, "0:10", 24, C.gold, {Position = UDim2.new(0, 20, 0, 234), Size = UDim2.new(1, -40, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold})
local progressTrack = make("Frame", {Position = UDim2.new(0, 28, 0, 274), Size = UDim2.new(1, -56, 0, 8), BackgroundColor3 = C.bg, BorderSizePixel = 0}, capturePanel)
corner(progressTrack, 6)
local progressFill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.lime, BorderSizePixel = 0}, progressTrack)
corner(progressFill, 6)
local captureProgress = label(capturePanel, "0 / 0 taps", 14, C.text, {Position = UDim2.new(0, 20, 0, 289), Size = UDim2.new(1, -40, 0, 26), TextXAlignment = Enum.TextXAlignment.Center})
local tapButton = button(capturePanel, "Tap to collect", function() tapDig() end,
	{Position = UDim2.new(0, 24, 0, 326), Size = UDim2.new(1, -48, 0, 48), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 17})
label(capturePanel, "Tap the button or press Space", 12, C.muted, {Position = UDim2.new(0, 20, 0, 380), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center})

local capturePreview=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,104),Size=UDim2.fromOffset(180,126)},capturePanel)

local function endCapture(message, kind)
	capture = nil
	captureShade.Visible = false
	for _,child in capturePreview:GetChildren() do child:Destroy() end
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
		endCapture(result.message or ("Captured " .. session.name .. "! Open your collection to feed it."), "success")
		celebrate(rarity(session.rarity).color)
	end
end
startDig = function()
	if busy or capture or activePage then return end
	busy = true
	digButton.Text = "Scanning…"
	digButton.BackgroundColor3 = C.honey
	digButton.TextColor3=C.bg
	-- The server waits for the scan and rolls the find chance; this UI stays busy until it resolves.
	local result = request("StartDig")
	busy = false
	digButton.Text = UserInputService.TouchEnabled and "Dig" or "Dig  ·  E"
	digButton.BackgroundColor3 = C.bg
	digButton.TextColor3=C.paper
	if not result or not result.ok or not result.dig then return end
	local dig = result.dig
	capture = {id = dig.id, required = dig.required, duration = dig.duration, deadline = os.clock() + dig.duration, taps = 0, name = dig.name or "brainrot", rarity = dig.rarity}
	captureName.Text = capture.name
	local r = rarity(dig.rarity)
	captureRarity.Text = r.name
	captureRarity.TextColor3 = readable(r.color)
	progressFill.BackgroundColor3 = r.color
	progressFill.Size = UDim2.fromScale(0, 1)
	captureProgress.Text = "0 / " .. capture.required .. " taps"
	for _,child in capturePreview:GetChildren() do child:Destroy() end
	previewStage(capturePreview,r.color,UDim2.new(),UDim2.fromScale(1,1))
	viewport(capturePreview,dig.specId,UDim2.fromScale(1,1))
	captureShade.Visible = true
	capturePanel.Position=UDim2.new(0.5,0,0.5,6)
	TweenService:Create(capturePanel,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromScale(0.5,0.5)}):Play()
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
		if countdown and state then countdown.Text = "Restocks in " .. seconds((state.rotationEnds or now()) - now()) end
		if activePage then
			for _, item in ipairs(body:GetDescendants()) do
				if item:IsA("TextLabel") then
					local boostUntil = item:GetAttribute("BoostUntil")
					local growthUntil = item:GetAttribute("GrowthUntil")
					if boostUntil then
						local remaining = boostUntil - now()
						item.Text = remaining > 0 and ("Active  " .. seconds(remaining)) or "Boost expired"
						item.TextColor3 = remaining > 0 and C.green or C.muted
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
	if size.X<1 or size.Y<1 then return end
	hud.Size = UDim2.new(0, math.min(290, math.max(230, size.X - 70)), 0, 86)
	helpButton.Position = UDim2.new(1, -12, 0, 12)
	panel.Size = UDim2.new(0.94,0,0,math.min(660,math.max(180,size.Y-108)))
	panelRestPosition=UDim2.new(0.5,0,0,(size.Y-76)/2)
	panel.Position=panelRestPosition
	for name,b in pairs(navButtons) do
		b.Text=name=="Collection" and (size.X<500 and "Bag" or "Collection") or name
		b.TextSize=size.X<500 and 12 or 13
	end
	if activePage=="Collection" or activePage=="Sell" then renderPage() end
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
if UserInputService.TouchEnabled then digButton.Text = "Dig" end

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
