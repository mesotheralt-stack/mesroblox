local assertions=0
local function check(condition,message) assertions+=1;assert(condition,message) end
local Action=ReplicatedStorage:WaitForChild("BrainrotRemotes"):WaitForChild("Action")
local function call(player,action,payload,delay)
	advance(delay or 0.2)
	return Action.OnServerInvoke(player,action,payload)
end
local function state(player) local result=call(player,"GetState");check(result.ok,"GetState must work");return result.state end
local function remaining(data,id) for _,item in data.stock do if item.id==id then return item.remaining end end return nil end
local starter=makePlayer(100)
Players.PlayerAdded:Fire(starter)
local fresh=state(starter)
check(fresh.coins==Config.StartCoins and fresh.income==0,"New player must start with coins and no passive income")
check(#fresh.brainrots==0 and fresh.foods.crumb==3,"New players need an empty collection and starter food")
check(#fresh.stock==6 and remaining(fresh,"crumb")~=nil,"Every rotation must stock six foods including affordable crumbs")
check(not call(starter,"MadeUp").ok,"Unknown actions must fail")
check(not call(starter,"BuyFood","invalid").ok,"Non-table payloads must fail")
check(not call(starter,"BuyDetector",{id="made-up"}).ok,"Unknown detector purchases must fail")
check(not call(starter,"EquipDetector",{id="void"}).ok,"Unowned detectors cannot be equipped")
check(not call(starter,"Teleport",{destination="Cosmic"}).ok,"Locked world teleport must fail")
check(not call(starter,"Feed",{uid="stolen",foodId="crumb",quantity=1}).ok,"Other players' brainrots cannot be fed")
check(not call(starter,"Sell",{uid="stolen"}).ok,"Other players' brainrots cannot be sold")
local buy=call(starter,"BuyFood",{id="crumb",quantity=2})
check(buy.ok and buy.state.coins==Config.StartCoins-30 and buy.state.foods.crumb==5,"Food purchase must charge correct cost and add inventory")
check(remaining(buy.state,"crumb")==Config.Foods[1].stock-2,"Purchase must consume current rotation stock")
for _, quantity in {0/0,math.huge,-math.huge,-1000000000,1000000000} do
	local beforeMalicious=state(starter)
	local malicious=call(starter,"BuyFood",{id="crumb",quantity=quantity})
	local afterMalicious=malicious.state
	check(afterMalicious.coins==afterMalicious.coins and afterMalicious.coins>=0 and afterMalicious.coins<=beforeMalicious.coins,"Non-finite/negative quantities cannot mint coins")
	check(afterMalicious.foods.crumb>=beforeMalicious.foods.crumb and afterMalicious.foods.crumb<=beforeMalicious.foods.crumb+100,"Malformed quantities must stay within purchase caps")
end
local before=state(starter).coins
local excessive=call(starter,"BuyFood",{id="crumb",quantity=100})
check(not excessive.ok and excessive.state.coins==before,"Stock failure must not charge money")
check(not call(starter,"StartDig").ok,"Digging outside the sand pit must fail")
check(call(starter,"Teleport",{destination="Meadow"}).ok,"Starter world teleport must work")
local capture=call(starter,"StartDig")
check(capture.ok and capture.dig and capture.dig.required>0,"A valid dig must start a timed capture")
check(not call(starter,"TapDig",{sessionId="spoof"}).ok,"Spoofed capture IDs must fail")
local progress
for _=1,capture.dig.required do progress=call(starter,"TapDig",{sessionId=capture.dig.id},0.1) end
check(progress.ok and progress.complete,"Enough timely taps must capture exactly one creature")
check(#progress.state.brainrots==1 and progress.state.discoveryCount==1,"Successful capture must add collection and discovery count")
check(not call(starter,"TapDig",{sessionId=capture.dig.id}).ok,"Replaying a completed capture cannot duplicate rewards")
local first=state(starter)
advance(2)
local after=state(starter)
check(after.coins>first.coins and after.income>0,"Owned brainrots must produce passive coins")
advance(5)
local timeout=call(starter,"StartDig")
check(timeout.ok,"Detector must recharge for another search")
advance(Config.DigDuration+0.5)
check(not call(starter,"TapDig",{sessionId=timeout.dig.id}).ok,"Expired captures must not award creatures")
check(#state(starter).brainrots==1,"A failed capture must leave the collection unchanged")
local restarted=call(starter,"StartDig")
check(restarted.ok,"A timed-out capture can be replaced")
check(call(starter,"Teleport",{destination="Home"}).ok,"Home teleport must work")
check(not call(starter,"TapDig",{sessionId=restarted.dig.id}).ok,"Teleporting must cancel the capture")

-- Seed a legitimate rich save to exercise purchases, boosts, growth and persistence.
records.Player_200={data={coins=1000000,brainrots={{uid="pet-a",specId="sprout",level=1,xp=0},{uid="pet-b",specId="toast",level=1,xp=0}},foods={crumb=100},activeBrainrot="pet-a",ownedDetectors={"twig"},unlockedWorlds={"Meadow"}}}
local rich=makePlayer(200)
Players.PlayerAdded:Fire(rich)
local loaded=state(rich)
check(#loaded.brainrots==2 and loaded.activeBrainrot=="pet-a","Saved collection must load")
local baseA=loaded.brainrots[1].income
local baseB=loaded.brainrots[2].income
local growth=call(rich,"BuyBoost",{uid="pet-a",kind="Growth"})
check(growth.ok and growth.state.brainrots[1].growthBoostUntil-growth.state.serverTime==300,"Growth boost must target chosen brainrot for five minutes")
local feed=call(rich,"Feed",{uid="pet-a",foodId="crumb",quantity=1})
check(feed.ok and feed.state.brainrots[1].xp==Config.Foods[1].xp*2,"Growth boost must double feeding XP")
check(feed.state.brainrots[2].xp==0,"Feeding one brainrot must not grow another")
local fedAgain=call(rich,"Feed",{uid="pet-a",foodId="crumb",quantity=1})
check(fedAgain.ok and fedAgain.state.brainrots[1].level>1,"Feeding enough XP must advance levels")
check(fedAgain.state.brainrots[1].income>baseA,"Growing must improve passive income")
local otherUID=state(starter).brainrots[1].uid
check(not call(rich,"Feed",{uid=otherUID,foodId="crumb",quantity=1}).ok,"A valid UID belonging to another player cannot be fed")
check(not call(rich,"Sell",{uid=otherUID}).ok,"A valid UID belonging to another player cannot be sold")
check(not call(rich,"BuyBoost",{uid=otherUID,kind="Income"}).ok,"A valid UID belonging to another player cannot be boosted")
local income=call(rich,"BuyBoost",{uid="pet-b",kind="Income"})
check(income.ok and income.state.brainrots[2].income==baseB*2,"Income boost must double only the selected brainrot income")
check(income.state.income==income.state.brainrots[1].income+income.state.brainrots[2].income,"All collected brainrots must contribute income")
local duplicate=call(rich,"BuyBoost",{uid="pet-b",kind="Income"},0.001)
check(not duplicate.ok,"Active boosts must not stack")
check(duplicate.state.coins==income.state.coins,"Duplicate boost failure must not charge money")
check(not call(rich,"UnlockWorld",{id="Cosmic"}).ok,"Worlds cannot be unlocked out of order")
check(call(rich,"BuyDetector",{id="clover"}).ok,"Accessible detector purchase must succeed")
check(call(rich,"UnlockWorld",{id="Dunes"}).ok,"Second world must unlock and teleport")
local inDunes=state(rich)
check(inDunes.world=="Dunes" and table.find(inDunes.unlockedWorlds,"Dunes")~=nil,"Unlock must persist and enter the new world")
check(call(rich,"BuyDetector",{id="prism"}).ok,"World unlock must grant access to its detectors")
check(call(rich,"UnlockWorld",{id="Cosmic"}).ok,"Third world must become reachable")
check(call(rich,"BuyDetector",{id="moon"}).ok,"Final world must provide a Secret-capable detector")
local maxDetector=state(rich)
check(maxDetector.detector=="moon","Purchased detector must be equipped")
local beforeSale=#maxDetector.brainrots
local sold=call(rich,"Sell",{uid="pet-a"})
check(sold.ok and #sold.state.brainrots==beforeSale-1 and sold.state.activeBrainrot=="pet-b","Selling active creature must award coins and select remaining companion")
check(not call(rich,"Sell",{uid="pet-a"}).ok,"A sold creature cannot be sold twice")
advance(301)
local expired=state(rich)
check(expired.brainrots[1].income==Config.income("toast",1),"Income boost must expire after five minutes")
local refreshed=state(starter)
check(remaining(refreshed,"crumb")==Config.Foods[1].stock,"Five-minute rotation must replenish a player's food stock")
local saved=state(rich)
Players.PlayerRemoving:Fire(rich)
local rejoined=makePlayer(200)
Players.PlayerAdded:Fire(rejoined)
local restored=state(rejoined)
check(#restored.brainrots==#saved.brainrots and restored.brainrots[1].uid=="pet-b","Collection must survive save and reload")
check(restored.detector=="moon" and table.find(restored.unlockedWorlds,"Cosmic")~=nil,"Gear and world progress must survive save and reload")
check(restored.foods.crumb==saved.foods.crumb,"Food counts must survive save and reload")
check(#warnings==0,"Unexpected server warnings: "..table.concat(warnings,"; "))
-- Physical movement into a locked pit must not bypass the world gate.
starter.Character.Root.Position=map.pits.Cosmic.center
check(not call(starter,"StartDig").ok,"Walking or exploiting into a locked pit must not bypass unlocks")
-- Inventory capacity is enforced before a new capture session is issued.
local fullPets={}
for i=1,Config.MaxBrainrots do table.insert(fullPets,{uid="full-"..i,specId="sprout",level=1,xp=0}) end
records.Player_250={data={coins=1000,brainrots=fullPets}}
local full=makePlayer(250);Players.PlayerAdded:Fire(full)
call(full,"Teleport",{destination="Meadow"})
check(not call(full,"StartDig").ok and #state(full).brainrots==Config.MaxBrainrots,"Full collections must not start new captures")
-- Saved corruption must be contained rather than propagated into client/economy.
records.Player_260={data={coins=0/0,foods={crumb=-999},detector="void",ownedDetectors={"made-up"},brainrots={{uid="same",specId="sprout",level=math.huge,xp=math.huge},{uid="same",specId="toast",level=1},{uid="invalid",specId="missing"}},activeBrainrot="missing"}}
local corrupt=makePlayer(260);Players.PlayerAdded:Fire(corrupt)
local clean=state(corrupt)
check(clean.coins==Config.StartCoins and clean.foods.crumb==0,"Invalid saved numbers must be sanitized")
check(#clean.brainrots==1 and clean.brainrots[1].level==1 and clean.brainrots[1].xp==0,"Invalid/duplicate species and malformed saved levels must be sanitized")
check(clean.detector==Config.Detectors[1].id and #clean.ownedDetectors==1,"Saved unknown/unowned gear must be discarded")
check(clean.activeBrainrot=="same","Missing saved companion must fall back to an owned brainrot")
-- Existing live session locks must prevent loading and all writes.
records.Player_300={data={coins=987654},session={id="other-server",expires=os.time()+100}}
local lockedRecord=records.Player_300
local locked=makePlayer(300);Players.PlayerAdded:Fire(locked)
check(type(locked.KickMessage)=="string","A live foreign session lock must deny joining")
check(records.Player_300==lockedRecord and writes.Player_300==nil,"A foreign locked profile must never be overwritten")
check(not call(locked,"GetState").ok,"Rejected profiles must not gain playable state")
-- Studio load failures allow a temporary game, but never write new default data.
failures.Player_400=true
local temporary=makePlayer(400)
task.spawn(function() Players.PlayerAdded:Fire(temporary) end)
advance(4)
local transient=state(temporary)
check(transient.persistenceEnabled==false and transient.coins==Config.StartCoins,"Studio outage must visibly use temporary progress")
failures.Player_400=nil
advance(61)
Players.PlayerRemoving:Fire(temporary)
check(records.Player_400==nil and writes.Player_400==nil,"Failed loads must never save temporary default data")
check(#warnings==2,"Only expected Studio persistence warnings should be emitted")
print("PASS authoritative server actions with Roblox service mocks ("..assertions.." assertions)")
