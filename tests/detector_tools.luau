-- Exercise the real held-tool factory, including its replacement lifecycle.
local function verifyDetectorTools(Factory,content)
	local player=makePlayer(7788)
	local backpack=Instance.new("Backpack");backpack.Parent=player
	local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
	function humanoid:EquipTool(tool) tool.Parent=player.Character end
	local unrelated=Instance.new("Tool");unrelated.Name="Unrelated";unrelated.Parent=backpack
	local previous=nil
	for _,spec in content.Detectors do
		local tool=Factory.equip(player,spec)
		assert(tool and tool.Parent==player.Character and tool.Name==spec.name,"Every detector must still equip in the character")
		assert(tool:GetAttribute("BrainrotDetector")==true and tool.RequiresHandle and not tool.CanBeDropped,"Refined tools must preserve equipment identification and grip behavior")
		local handle=tool:FindFirstChild("Handle")
		assert(handle and not handle.Anchored,"Held tools must remain physical welded tools")
		local coils,pieces=0,0
		for _,piece in tool:GetChildren() do
			if piece:IsA("BasePart") then
				pieces+=1
				assert(piece.Massless and not piece.CanCollide and not piece.CanTouch and not piece.CanQuery,"Detector details must not push or obstruct the character")
				assert(piece.Size.X>0 and piece.Size.Y>0 and piece.Size.Z>0,"Detector pieces must have positive dimensions")
				if piece~=handle then
					local weld=piece:FindFirstChildOfClass("WeldConstraint")
					assert(weld and weld.Part0==handle and weld.Part1==piece,"All cosmetic pieces must follow the held handle")
				end
				if piece.Name=="SearchCoil" then coils+=1 end
			end
		end
		assert(coils>=8 and not tool:FindFirstChild("CoilInset"),"Search head must have an open loop rather than a filled disc")
		assert(pieces<=45 and tool:FindFirstChild("SignalDisplay") and tool:FindFirstChild("GripRib"),"Detector must stay bounded and recognizable")
		assert(not previous or previous.Destroyed,"Equipping another detector must remove the previous held tool")
		assert(not unrelated.Destroyed,"Detector upgrades must retain unrelated backpack tools")
		previous=tool
	end
	previous.Parent=backpack
	local replacement=Factory.equip(player,content.Detectors[1])
	assert(previous.Destroyed and replacement.Parent==player.Character,"Replacing an unequipped detector must clean the backpack too")
	print("PASS seven real detector tools: open coils, safe welded details, equipment identity and upgrade cleanup")
end
