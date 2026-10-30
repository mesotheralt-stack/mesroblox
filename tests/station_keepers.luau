-- Uses the actual factory with the normal scene fixture. The NPCs present shop
-- actions but never own inventory, currency, or reward logic.
local function verifyStationKeepers(Factory)
	local parent=Instance.new("Folder")
	local roles={Food={"ChefApron","ChefHatPuff"},Gear={"GoggleLens","SpannerHandle"},Sell={"LedgerCover","TraderScarf"}}
	local count=0
	for role,details in roles do
		local keeper=Factory.create(parent,CFrame.new(100,2,-40),role)
		assert(keeper.Name=="StationKeeper" and keeper:GetAttribute("ShopRole")==role,"Keeper must identify its existing shop role")
		assert(keeper.PrimaryPart and keeper.PrimaryPart.Name=="Root","Keeper must have a placement root")
		assert(keeper:FindFirstChild("Head") and keeper:FindFirstChild("Torso") and keeper:FindFirstChild("LeftArm") and keeper:FindFirstChild("RightLeg"),"Keeper needs a recognizable classic character silhouette")
		assert(not keeper:FindFirstChildOfClass("Humanoid"),"Stationary attendants must not add AI or character spawn behavior")
		for _,name in details do assert(keeper:FindFirstChild(name),role.." needs its own station costume") end
		local parts=0
		for _,part in keeper:GetDescendants() do
			assert(not part:IsA("BillboardGui"),"Keeper labels must remain physical plaques")
			if part:IsA("BasePart") then
				parts+=1
				assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"Attendants must never obstruct the counter or player movement")
				assert(part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0,"Attendant parts need finite positive dimensions")
			end
		end
		assert(parts>=40 and parts<=70,"Keeper detail budget outside 40–70 parts: "..role.." / "..parts)
		local plaque=keeper:FindFirstChild("KeeperNamePlaque")
		assert(plaque and plaque.Size.X<=1.7 and plaque.Size.Y<=0.45,"Name plaques must fit the clothing instead of spanning the arms")
		assert(keeper:FindFirstChild("NameBadgeFrame"),"Keeper name badge needs its fitted frame")
		local detailsCount={BootToe=0,Thumb=0,SleeveShoulder=0,EyeIris=0,Sideburn=0}
		for _,piece in keeper:GetChildren() do if detailsCount[piece.Name] then detailsCount[piece.Name]+=1 end end
		for name,pieces in detailsCount do assert(pieces==2,"Each attendant needs paired fitted "..name.." details") end
		if role=="Food" then assert(keeper:FindFirstChild("ChefHatPleat"),"Chef's hat needs shaped fabric pleats")
		elseif role=="Gear" then assert(keeper:FindFirstChild("GoggleReflection"),"Mechanic's lenses need separate glass reflections")
		elseif role=="Sell" then assert(keeper:FindFirstChild("TraderHairBun"),"Trader needs a distinct finished hairstyle") end
		local prompt=plaque and plaque:FindFirstChildOfClass("ProximityPrompt")
		assert(prompt and prompt:GetAttribute("Shop")==role and prompt.KeyboardKeyCode==Enum.KeyCode.F,"Keeper prompt must route to its real station using F")
		assert(prompt.ObjectText==keeper:GetAttribute("KeeperName") and prompt.RequiresLineOfSight==false,"Friendly name and reachable interaction must survive placement behind a counter")
		count+=1
	end
	assert(#parent:GetChildren()==3,"Every buy/sell station needs a distinct attendant")
	assert(not pcall(Factory.create,parent,CFrame.new(),"Unknown"),"Unrecognized station roles must fail before creating a model")
	print("PASS three actual station keepers: role costumes, safe geometry, physical names and existing shop prompts")
end
