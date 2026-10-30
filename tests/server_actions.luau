local assertions=0
local function check(condition,message) assertions+=1;assert(condition,message) end
local Action=ReplicatedStorage:WaitForChild("BrainrotRemotes"):WaitForChild("Action")
local function call(player,action,payload,delay)
	advance(delay or 0.2)
	local result,finished
	task.spawn(function() result=Action.OnServerInvoke(player,action,payload);finished=true end)
	if action=="StartDig" then advance(Config.SearchSeconds+0.001) end
	assert(finished,"Remote action did not finish in its expected time: "..action)
	return result
end
local function search(player,unit)
	table.insert(forcedRandomNumbers,unit or 0)
	return call(player,"StartDig")
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
local capture=search(starter,0)
check(capture.ok and capture.dig and capture.dig.required>0,"A valid dig must start a timed capture")
check(not call(starter,"TapDig",{sessionId="spoof"}).ok,"Spoofed capture IDs must fail")
local progress
for _=1,capture.dig.required do progress=call(starter,"TapDig",{sessionId=capture.dig.id},0.1) end
check(progress.ok and progress.complete,"Enough timely taps must capture exactly one creature")
check(#progress.state.brainrots==1 and progress.state.discoveryCount==1,"Successful capture must add collection and discovery count")
check(table.find(progress.state.discoveredIds,progress.state.brainrots[1].specId)~=nil and progress.state.uniqueDiscovered==1,"Captured species must unlock its persistent index entry")
check(progress.state.garden.slots[1]==progress.state.brainrots[1].uid,"First captured creature must populate the first garden slot")
check(not call(starter,"TapDig",{sessionId=capture.dig.id}).ok,"Replaying a completed capture cannot duplicate rewards")
local first=state(starter)
advance(2)
local after=state(starter)
check(after.coins>first.coins and after.income>0,"Owned brainrots must produce passive coins")
advance(5)
local timeout=search(starter,0)
check(timeout.ok,"Detector must recharge for another search")
advance(Config.DigDuration+0.5)
check(not call(starter,"TapDig",{sessionId=timeout.dig.id}).ok,"Expired captures must not award creatures")
check(#state(starter).brainrots==1,"A failed capture must leave the collection unchanged")
local restarted=search(starter,0)
check(restarted.ok,"A timed-out capture can be replaced")
check(call(starter,"Teleport",{destination="Home"}).ok,"Home teleport must work")
check(not call(starter,"TapDig",{sessionId=restarted.dig.id}).ok,"Teleporting must cancel the capture")

-- Seed a legitimate rich save to exercise purchases, boosts, growth and persistence.
records.Player_200={data={coins=1000000,brainrots={{uid="pet-a",specId="sprout",level=1,xp=0},{uid="pet-b",specId="toast",level=1,xp=0}},foods={crumb=100},activeBrainrot="pet-a",ownedDetectors={"twig"},unlockedWorlds={"Meadow"}}}
local rich=makePlayer(200)
Players.PlayerAdded:Fire(rich)
local loaded=state(rich)
check(#loaded.brainrots==2 and loaded.activeBrainrot=="pet-a","Saved collection must load")
check(loaded.uniqueDiscovered==2 and table.find(loaded.discoveredIds,"sprout") and table.find(loaded.discoveredIds,"toast"),"Legacy owned species must migrate into index history")
check(loaded.brainrots[1].variant=="Normal" and loaded.discoveredVariants.sprout.Normal and loaded.discoveredVariants.toast.Normal,"Legacy creatures and index entries must migrate to Normal finishes")
check(loaded.garden.slots[1]=="pet-a" and loaded.garden.slots[2]=="pet-b","Legacy saves must receive inviting owned-creature garden placements")
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
check(sold.state.uniqueDiscovered==2 and table.find(sold.state.discoveredIds,"sprout"),"Selling a creature must retain its index discovery")
check(sold.state.garden.slots[1]=="" and sold.state.garden.slots[2]=="pet-b","Selling must remove the sold creature from its garden only")
local movedGarden=call(rich,"GardenAssign",{uid="pet-b",slot=6})
check(movedGarden.ok and movedGarden.state.garden.slots[2]=="" and movedGarden.state.garden.slots[6]=="pet-b","Assigning an existing display moves its unique UID")
check(movedGarden.state.income==sold.state.income,"Moving garden displays must not duplicate passive income")
check(call(rich,"GardenClear",{slot=6}).ok,"Owner must be able to clear an occupied slot")
check(call(rich,"GardenAssign",{uid="pet-b",slot=6}).ok,"Cleared slots can be assigned again")
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
check(restored.uniqueDiscovered==2 and table.find(restored.discoveredIds,"sprout"),"Sold-species discovery history must survive rejoining")
check(restored.garden.slots[6]=="pet-b" and restored.garden.slots[2]=="","Garden UID placements must survive rejoining")
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
check(records.Player_260.data.coins==Config.StartCoins and clean.coins>=Config.StartCoins and clean.foods.crumb==0,"Invalid saved numbers must be sanitized")
check(#clean.brainrots==1 and clean.brainrots[1].level==1 and clean.brainrots[1].xp==0,"Invalid/duplicate species and malformed saved levels must be sanitized")
check(clean.detector==Config.Detectors[1].id and #clean.ownedDetectors==1,"Saved unknown/unowned gear must be discarded")
check(clean.activeBrainrot=="same","Missing saved companion must fall back to an owned brainrot")

-- Permanent finishes remain authoritative through growth, boosts, sales,
-- captured rewards, private discovery snapshots and a real save/reload.
local finishPets={}
for _,variant in Config.Variants do
	table.insert(finishPets,{uid="finish-"..variant.id,specId="sprout",variant=variant.id,level=10,xp=0,multiplier=100000})
end
table.insert(finishPets,{uid="legacy-finish",specId="toast",level=1})
table.insert(finishPets,{uid="bad-finish",specId="pebble",variant="Rainbow",variantMultiplier=100000,level=1})
records.Player_270={data={coins=1000000,brainrots=finishPets,foods={crumb=100},activeBrainrot="finish-Gold",
	discoveredVariants={toast={Diamond=true,Gold=false,Silver="true",Rainbow=true},dragon={Gold=true},missing={Gold=true},frog="Diamond"}}}
local finishPlayer=makePlayer(270);Players.PlayerAdded:Fire(finishPlayer)
local finishes=state(finishPlayer)
for index,variant in Config.Variants do
	local brainrot=finishes.brainrots[index]
	check(brainrot.variant==variant.id and brainrot.variantMultiplier==variant.multiplier,"Saved finish identity must load without trusting saved multipliers")
	check(brainrot.income==Config.income("sprout",10,variant.id) and brainrot.sellValue==Config.sellValue("sprout",10,variant.id),"Income and sale quotes must include each permanent finish")
	check(finishes.discoveredVariants.sprout[variant.id],"Owned finishes must seed their permanent index entries")
end
check(finishes.brainrots[6].variant=="Normal" and finishes.brainrots[7].variant=="Normal","Missing and unknown saved finishes must fall back safely to Normal")
check(finishes.discoveredVariants.toast.Diamond and not finishes.discoveredVariants.toast.Gold and not finishes.discoveredVariants.toast.Silver
	and not finishes.discoveredVariants.toast.Rainbow and not finishes.discoveredVariants.missing and not finishes.discoveredVariants.frog,"Only known species and true known-finish discovery flags may load")
local companion=workspace:FindFirstChild("Player270's Gold Sproutini Spaghetti")
check(companion and companion.AppliedVariant=="Gold","The server must create the selected companion with its saved finish")
local totalFinishIncome=0
for _,brainrot in finishes.brainrots do totalFinishIncome+=brainrot.income end
check(finishes.income==totalFinishIncome,"The wallet income rate must sum the variant-aware collection")
advance(2)
local finishTick=state(finishPlayer)
check(finishTick.coins>=finishes.coins+totalFinishIncome*2,"Passive payout ticks must pay the permanent finish bonuses")
local grownFinish=call(finishPlayer,"Feed",{uid="finish-Bronze",foodId="crumb",quantity=20,variant="Diamond",variantMultiplier=100000})
check(grownFinish.ok and grownFinish.state.brainrots[2].variant=="Bronze" and grownFinish.state.brainrots[2].level>10,"Feeding may grow a creature but cannot accept a client finish change")
check(grownFinish.state.brainrots[2].income==Config.income("sprout",grownFinish.state.brainrots[2].level,"Bronze"),"Level growth must retain and apply the permanent multiplier")
local diamondIncome=finishes.brainrots[5].income
local boostedFinish=call(finishPlayer,"BuyBoost",{uid="finish-Diamond",kind="Income",variant="Normal"})
check(boostedFinish.ok and boostedFinish.state.brainrots[5].income==diamondIncome*2,"Temporary income boosts must multiply the permanent finish payout")
check(boostedFinish.state.brainrots[5].sellValue==finishes.brainrots[5].sellValue,"Temporary income boosts must not inflate sale quotes")
local saleQuote=finishes.brainrots[4].sellValue
local preFinishSale=state(finishPlayer)
local finishSale=Action.OnServerInvoke(finishPlayer,"Sell",{uid="finish-Gold",variant="Diamond",sellValue=1e12})
check(finishSale.ok and finishSale.state.coins==preFinishSale.coins+saleQuote,"Selling must award the server's permanent-finish value and ignore forged values")
check(finishSale.state.discoveredVariants.sprout.Gold,"Selling the only owned copy must retain its finish discovery")
finishes.discoveredVariants.toast.Diamond=false;finishes.discoveredVariants.sprout.Rainbow=true
local privateFinishes=state(finishPlayer)
check(privateFinishes.discoveredVariants.toast.Diamond and not privateFinishes.discoveredVariants.sprout.Rainbow,"Returned finish history must be a deep copy, never a writable profile reference")
local rollUnits={0,0.8,0.92,0.97,0.995}
for index,variant in Config.Variants do
	check(call(finishPlayer,"Teleport",{destination="Meadow"}).ok,"Finish roll test requires the unlocked starter pit")
	advance(Config.SearchSeconds+Config.Detectors[1].speed+0.1)
	table.insert(forcedRandomNumbers,0);table.insert(forcedRandomNumbers,0);table.insert(forcedRandomNumbers,rollUnits[index]);table.insert(forcedRandomIntegers,1)
	local rolled=call(finishPlayer,"StartDig",{variant="Diamond",variantMultiplier=100000})
	check(rolled.ok and rolled.dig.specId=="sprout" and rolled.dig.variant==variant.id and rolled.dig.variantMultiplier==variant.multiplier,"Each finish must roll independently of species rarity on the server")
	local finishCaught
	for _=1,rolled.dig.required do finishCaught=call(finishPlayer,"TapDig",{sessionId=rolled.dig.id,variant="Diamond",variantMultiplier=100000},0.1) end
	local award=finishCaught.state.brainrots[#finishCaught.state.brainrots]
	check(finishCaught.complete and award.variant==variant.id and award.income==Config.income("sprout",1,variant.id),"Completed captures must award the server session's finish, ignoring client overrides")
end
check(#forcedRandomNumbers==0 and #forcedRandomIntegers==0,"Finish roll queues must be fully consumed")
Players.PlayerRemoving:Fire(finishPlayer);finishPlayer.Parent=nil
local finishRejoin=makePlayer(270);Players.PlayerAdded:Fire(finishRejoin)
local restoredFinishes=state(finishRejoin)
check(restoredFinishes.discoveredVariants.sprout.Gold and restoredFinishes.discoveredVariants.toast.Diamond,"Sold and historical finishes must survive save and rejoin")
check(restoredFinishes.discoveredVariants.dragon.Gold and not restoredFinishes.discoveredVariants.dragon.Normal,"Reloading a variant-only historical discovery must not invent a Normal discovery")
check(restoredFinishes.brainrots[2].variant=="Bronze" and restoredFinishes.brainrots[2].level==grownFinish.state.brainrots[2].level,"Feeding and saving must preserve a creature's permanent finish")
check(records.Player_270.data.brainrots[2].variant=="Bronze" and records.Player_270.data.discoveredVariants.sprout.Diamond,"Serialized profiles must retain owned finishes and nested history")
Players.PlayerRemoving:Fire(finishRejoin);finishRejoin.Parent=nil

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
-- Searches must really wait, miss without rewards, and revalidate after yielding.
records.Player_700={data={coins=1000000,brainrots={},ownedDetectors={"twig"},unlockedWorlds={"Meadow"}}}
local scanner=makePlayer(700);Players.PlayerAdded:Fire(scanner)
local function startPending(player)
	local box={}
	task.spawn(function() box.result=Action.OnServerInvoke(player,"StartDig",{});box.done=true end)
	return box
end
local function prepare(player)
	call(player,"Teleport",{destination="Meadow"})
	advance(Config.SearchSeconds+Config.Detectors[1].speed+0.1)
end
prepare(scanner)
local scanStartCoins=state(scanner).coins
local scanStart=clock
local drawsBeforeScan=randomNumberDraws
-- Exactly 0.5 is outside the successful half of the random interval.
table.insert(forcedRandomNumbers,0.5)
local empty=startPending(scanner)
check(not empty.done,"A search must not reveal its result immediately")
advance(Config.SearchSeconds-0.01)
check(not empty.done,"The search must remain pending for the full scan duration")
check(randomNumberDraws==drawsBeforeScan,"Chance must be determined after the scan delay, not before it")
check(not Action.OnServerInvoke(scanner,"StartDig",{}).ok,"Parallel searches must be rejected")
check(not Action.OnServerInvoke(scanner,"EquipDetector",{id="twig"}).ok,"Detector equipping must be rejected during a pending search")
check(not Action.OnServerInvoke(scanner,"BuyDetector",{id="clover"}).ok,"Detector purchases must be rejected during a pending search")
local pendingState=Action.OnServerInvoke(scanner,"GetState",{}).state
check(#pendingState.brainrots==0 and pendingState.discoveryCount==0,"Pending searches must not grant creatures or discovery progress")
check(pendingState.coins==scanStartCoins and #pendingState.ownedDetectors==1,"Rejected detector requests must not charge or equip new gear")
advance(0.011)
check(empty.done and empty.result.ok and empty.result.found==false and empty.result.dig==nil,"An empty search must resolve successfully without a capture session")
check(clock-scanStart>=Config.SearchSeconds,"A result must arrive only after the scan delay")
check(#empty.result.state.brainrots==0 and empty.result.state.discoveryCount==0,"Empty searches must not award collection progress")
check(not Action.OnServerInvoke(scanner,"TapDig",{sessionId="empty-search"}).ok,"An empty search cannot be tapped into a reward")
check(not Action.OnServerInvoke(scanner,"StartDig",{}).ok,"An empty search must still consume detector cooldown")
-- A unit draw just below 0.5 succeeds. Force the next rarity draw to Common
-- so completing near the deadline tests the whole ten-second capture window.
prepare(scanner)
table.insert(forcedRandomNumbers,0.499999)
table.insert(forcedRandomNumbers,0)
local found=startPending(scanner)
advance(Config.SearchSeconds+0.001)
check(found.done and found.result.ok and found.result.found==true and found.result.dig,"A draw below the 50% boundary must start a capture")
check(found.result.dig.duration==Config.DigDuration,"The scan must preserve the full capture duration")
advance(Config.DigDuration-0.5)
local caught
for _=1,found.result.dig.required do
	advance(0.06)
	caught=Action.OnServerInvoke(scanner,"TapDig",{sessionId=found.result.dig.id})
end
check(caught.ok and caught.complete,"Capture deadline must begin after search resolution, not at scan start")
check(#caught.state.brainrots==1 and caught.state.discoveryCount==1,"A delayed found result still grants exactly one completed capture")
prepare(scanner)
local countBeforeMiss=#state(scanner).brainrots
table.insert(forcedRandomNumbers,0.999999)
local miss=startPending(scanner);advance(Config.SearchSeconds+0.001)
check(miss.result.ok and miss.result.found==false and #miss.result.state.brainrots==countBeforeMiss,"A high random draw must miss without changing an existing collection")
-- Leaving the pit before the result must cancel rather than rolling a find.
local drawsBeforeCanceledScans=randomNumberDraws
prepare(scanner)
local moved=startPending(scanner);advance(0.4)
scanner.Character.Root.Position=vec(0,5,-100)
advance(Config.SearchSeconds)
check(moved.done and not moved.result.ok and moved.result.dig==nil,"Leaving the pit during a scan must cancel the pending search")
-- Even teleporting back into the same pit invalidates the original scan token.
prepare(scanner)
local warped=startPending(scanner);advance(0.4)
check(Action.OnServerInvoke(scanner,"Teleport",{destination="Meadow"}).ok,"Teleport during a scan must remain usable")
advance(Config.SearchSeconds)
check(warped.done and not warped.result.ok and warped.result.dig==nil,"Teleport must cancel a scan even if its final pit is unchanged")
-- A new character positioned in the same pit must not inherit an old scan.
prepare(scanner)
local respawned=startPending(scanner);advance(0.4)
scanner.Character=makePlayer(701).Character
scanner.CharacterAdded:Fire(scanner.Character)
scanner.Character:PivotTo(map.destinations.Meadow)
advance(Config.SearchSeconds)
check(respawned.done and not respawned.result.ok and respawned.result.dig==nil,"Respawning must invalidate an in-flight search")
-- Unloading a player while InvokeServer waits must not mutate its saved profile.
prepare(scanner)
local departed=startPending(scanner);advance(0.4)
Players.PlayerRemoving:Fire(scanner);scanner.Parent=nil
advance(Config.SearchSeconds)
check(departed.done and not departed.result.ok and departed.result.dig==nil,"A departed player cannot finish a pending search")
check(#records.Player_700.data.brainrots==1 and records.Player_700.data.discoveryCount==1,"Pending scans must never award after the final save")
check(#forcedRandomNumbers==0,"Scripted search random draws must all be consumed")
check(randomNumberDraws==drawsBeforeCanceledScans,"Canceled scans must not roll a new chance or species after invalidation")
-- Garden ownership stays tied to server profiles, never a client-supplied plot.
local own=state(rejoined)
local other=state(starter)
check(own.garden.id~=other.garden.id,"Concurrent players must receive distinct gardens")
for _,slot in {0,7,-1,1.5,0/0,math.huge,"1",false} do
	check(not call(rejoined,"GardenAssign",{uid="pet-b",slot=slot}).ok,"Garden assignments require a finite integer slot")
	check(not call(rejoined,"GardenClear",{slot=slot}).ok,"Garden clearing requires a finite integer slot")
end
check(not call(rejoined,"GardenAssign",{uid=other.brainrots[1].uid,slot=1}).ok,"Foreign inventory UIDs cannot be displayed")
check(call(rejoined,"GardenAssign",{uid="pet-b",slot=3,gardenId=other.garden.id}).ok,"Client plot IDs must not redirect an owned assignment")
check(state(starter).garden.slots[1]==other.brainrots[1].uid and state(rejoined).garden.slots[3]=="pet-b","A forged garden ID must never edit another player's garden")
check(call(rejoined,"Teleport",{destination="Garden",gardenId=other.garden.id}).ok,"Own-garden teleport should work")
local homeFrame=map.gardens[own.garden.id].spawnCFrame
check(rejoined.Character.Root.Position==homeFrame,"Garden teleport must resolve the caller's plot, ignoring supplied IDs")
-- Invalid saved discoveries and repeated/foreign saved slot IDs are discarded.
records.Player_810={data={coins=1000,brainrots={{uid="one",specId="sprout",level=1},{uid="two",specId="toast",level=1}},discovered={void=true,missing=true,dragon="true"},gardenSlots={"one","one","foreign","two"}}}
local migration=makePlayer(810);Players.PlayerAdded:Fire(migration)
local migrated=state(migration)
check(migrated.uniqueDiscovered==3 and table.find(migrated.discoveredIds,"void") and not table.find(migrated.discoveredIds,"missing"),"Index migration accepts only known true discovery flags and owned species")
check(migrated.discoveredVariants.void.Normal,"A species sold before variants existed must migrate its legacy index entry to Normal")
check(migrated.garden.slots[1]=="one" and migrated.garden.slots[2]=="" and migrated.garden.slots[3]=="" and migrated.garden.slots[4]=="two","Saved duplicate and foreign garden IDs must be sanitized")
check(call(migration,"Teleport",{destination="Meadow"}).ok,"Book test needs a valid digging position")
table.insert(forcedRandomNumbers,0);table.insert(forcedRandomNumbers,0);table.insert(forcedRandomIntegers,1)
local repeatSpecies=call(migration,"StartDig")
check(repeatSpecies.dig and repeatSpecies.dig.specId=="sprout","Scripted duplicate capture must target an already discovered species")
local duplicateCaught
for _=1,repeatSpecies.dig.required do duplicateCaught=call(migration,"TapDig",{sessionId=repeatSpecies.dig.id},0.1) end
check(duplicateCaught.complete and duplicateCaught.state.uniqueDiscovered==3,"Repeated species captures must not increase unique index progress")
Players.PlayerRemoving:Fire(migration);migration.Parent=nil
-- Exercise six real GardenService claims, then deny a seventh before any save
-- acquisition. Releasing a plot must clear render models and allow re-use.
for _,player in {starter,rejoined,full,corrupt} do Players.PlayerRemoving:Fire(player);player.Parent=nil end
local occupants={}
local plotIds={}
for index=1,Config.MaxPlayers do
	local id=900+index
	records["Player_"..id]={data={coins=1000,brainrots={{uid="garden-"..index,specId="sprout",level=1}},gardenSlots={"garden-"..index}}}
	local person=makePlayer(id);Players.PlayerAdded:Fire(person);occupants[index]=person
	local data=state(person)
	check(data.garden.id and not plotIds[data.garden.id],"Six admitted players must hold unique garden plots")
	plotIds[data.garden.id]=true
end
local seventh=makePlayer(9999);Players.PlayerAdded:Fire(seventh)
check(type(seventh.KickMessage)=="string" and not call(seventh,"GetState").ok,"A seventh player must not receive a playable profile")
check(writes.Player_9999==nil and records.Player_9999==nil,"Full-server admission must not open a seventh DataStore session")
local releasedId=state(occupants[1]).garden.id
local displayFolder=map.gardens[releasedId].displays
check(#displayFolder:GetChildren()>0,"An occupied garden must have a physical creature display")
Players.PlayerRemoving:Fire(occupants[1]);occupants[1].Parent=nil
check(#displayFolder:GetChildren()==0,"Leaving must clear all garden display models")
local replacement=makePlayer(10000);Players.PlayerAdded:Fire(replacement)
check(state(replacement).garden.id==releasedId,"A newly joining player must reuse the released plot")
check(#displayFolder:GetChildren()==0,"A reused empty garden must not inherit another player's creatures")
Players.PlayerRemoving:Fire(replacement);replacement.Parent=nil
-- Studio fallback load can yield. Leaving during it releases its reserved plot
-- immediately, and late acquisition cannot claim a replacement's garden.
failures.Player_10001=true
local pending=makePlayer(10001)
task.spawn(function() Players.PlayerAdded:Fire(pending) end)
advance(0.2)
local blocked=makePlayer(10002);Players.PlayerAdded:Fire(blocked)
check(type(blocked.KickMessage)=="string" and writes.Player_10002==nil,"A loading profile must reserve the final garden")
Players.PlayerRemoving:Fire(pending);pending.Parent=nil
local nextPlayer=makePlayer(10003);Players.PlayerAdded:Fire(nextPlayer)
local nextPlot=state(nextPlayer).garden.id
advance(4)
check(state(nextPlayer).garden.id==nextPlot,"A canceled late load must not release another player's claim")
check(records.Player_10001==nil and writes.Player_10001==nil,"A departed failed load must not save temporary data")
Players.PlayerRemoving:Fire(nextPlayer);nextPlayer.Parent=nil
updateDelays.Player_10004=1
local late=makePlayer(10004)
task.spawn(function() Players.PlayerAdded:Fire(late) end)
advance(0.2)
Players.PlayerRemoving:Fire(late);late.Parent=nil
local afterLate=makePlayer(10005);Players.PlayerAdded:Fire(afterLate)
local afterLatePlot=state(afterLate).garden.id
advance(1.1)
check(records.Player_10004 and records.Player_10004.session==nil,"A canceled successful late load must release its acquired save session")
check(state(afterLate).garden.id==afterLatePlot,"Late save release must not clear a replacement's garden")
check(not call(late,"GetState").ok,"A departed late load must not become a playable profile")

-- A departing save may yield between failed retries. Reserve that user ID
-- for the entire retry lifecycle: this server's global lease ID alone cannot
-- distinguish an old departure from a new player object with the same user ID.
Players.PlayerRemoving:Fire(afterLate);afterLate.Parent=nil
records.Player_10006={data={coins=8765,brainrots={{uid="retry-pet",specId="sprout",level=8}},discovered={void=true},gardenSlots={"retry-pet"}}}
local retrying=makePlayer(10006);Players.PlayerAdded:Fire(retrying)
check(call(retrying,"GardenAssign",{uid="retry-pet",slot=6}).ok,"Departure regression requires unsaved garden changes")
local retrySnapshot=state(retrying)
local writesBeforeDeparture=writes.Player_10006
failures.Player_10006=true
local departureDone=false
task.spawn(function() Players.PlayerRemoving:Fire(retrying);departureDone=true end)
retrying.Parent=nil
check(not departureDone,"A failed final save must enter its retry backoff")
-- Storage recovers while the old departure is asleep. A new Player object
-- could acquire its predecessor's global-session lease without this guard.
failures.Player_10006=nil
local tooSoon=makePlayer(10006);Players.PlayerAdded:Fire(tooSoon)
check(type(tooSoon.KickMessage)=="string" and not call(tooSoon,"GetState").ok,"Same-user rejoins must be denied during the first save backoff")
check(writes.Player_10006==writesBeforeDeparture,"Rejected rejoin must not acquire or overwrite a departing save")
Players.PlayerRemoving:Fire(tooSoon);tooSoon.Parent=nil
failures.Player_10006=true
advance(1.01)
check(not departureDone,"A second failed departure save must remain guarded through its longer backoff")
failures.Player_10006=nil
local stillTooSoon=makePlayer(10006);Players.PlayerAdded:Fire(stillTooSoon)
check(type(stillTooSoon.KickMessage)=="string" and not call(stillTooSoon,"GetState").ok,"Same-user rejoins must also be denied during the second save backoff")
check(writes.Player_10006==writesBeforeDeparture,"Backoff retries must never open a replacement profile session")
advance(2.1)
check(departureDone and records.Player_10006.session==nil,"Successful final retry must finish and release the departure's lease")
check(records.Player_10006.data.gardenSlots[6]=="retry-pet" and records.Player_10006.data.gardenSlots[1]=="","Final retry must preserve latest garden changes")
local afterRetry=makePlayer(10006);Players.PlayerAdded:Fire(afterRetry)
local resumed=state(afterRetry)
check(afterRetry.KickMessage==nil and resumed.garden.slots[6]=="retry-pet","Rejoining must become available after the old save lifecycle completes")
check(resumed.uniqueDiscovered==retrySnapshot.uniqueDiscovered and table.find(resumed.discoveredIds,"void"),"Completed retries must preserve index history")
check(records.Player_10006.session~=nil,"The replacement profile must hold its own active save lease")
advance(2.1)
check(records.Player_10006.session~=nil and state(afterRetry).garden.slots[6]=="retry-pet","No stale departure retry may release or overwrite the replacement profile")

print("PASS authoritative server actions with Roblox service mocks ("..assertions.." assertions)")
