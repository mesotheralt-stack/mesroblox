-- Execute every real procedural model branch, including the uncommon species
-- that the seven-specimen world gallery does not instantiate.
vectorMeta.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
CFrame.lookAt=function(position,_target) return position end
CFrame.fromMatrix=function(position) return position end
local modelNew=Instance.new
Instance.new=function(class)
	local object=modelNew(class)
	function object:ScaleTo(value) self.AppliedScale=value end
	function object:GetPivot() return self.Frame or vec(0,0,0) end
	function object:GetBoundingBox() return {Position=vec(0,2.5,0)},vec(5,6,5) end
	return object
end
local function verifyModels(Factory, content)
	local checks=0
	for _,spec in content.Creatures do
		local model=Factory.create(spec,1.2)
		assert(model.PrimaryPart and model.PrimaryPart.Name=="Root",spec.id.." needs a root")
		assert(model.Name==spec.name,spec.id.." name changed")
		assert(model.AppliedScale==1.2,spec.id.." must support growth")
		local parts=0
		for _,part in model:GetChildren() do
			if part:IsA("Part") or part:IsA("WedgePart") then
				assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"Preview geometry must be inert")
				assert(part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0,"No zero-size model pieces")
				parts+=1
			end
		end
		assert(parts>=30 and parts<=125,spec.id.." detail budget outside 30–125 pieces: "..parts)
		if spec.shape=="mushroom" then
			local spots=0
			for _,piece in model:GetChildren() do
				if piece.Name=="CreamCapSpot" then
					spots+=1
					assert(piece.CFrame.Y>4.05,"Cap spots must sit on the crown surface instead of being buried")
				end
			end
			assert(spots==7 and model:FindFirstChild("CrownCapSpot"),"Mushroom needs a readable patterned cap")
		elseif spec.shape=="bee" then
			local bands={}
			for _,piece in model:GetChildren() do if piece.Name=="AbdomenBand" then table.insert(bands,piece) end end
			assert(#bands==48 and bands[1].Size.Z<bands[17].Size.Z,"Bee stripes must wrap the surface and taper with the abdomen")
		elseif spec.shape=="moon" then
			local crescent={}
			for _,piece in model:GetChildren() do if piece.Name=="CrescentRibbon" then table.insert(crescent,piece) end end
			assert(#crescent>=32 and #crescent<=64 and crescent[1].ClassName=="WedgePart","Moon crescent needs a filled continuous ribbon instead of overlapping beads")
		elseif spec.shape=="jelly" then
			assert(model:FindFirstChild("ClearSpaceHelmet").Material==Enum.Material.Glass and model:FindFirstChild("HelmetReflection"),"Astronaut helmet must have a distinct glass finish")
		elseif spec.shape=="capybara" or spec.shape=="lion" or spec.shape=="dragon" then
			local soles=0
			for _,piece in model:GetChildren() do if piece.Name=="PawSole" then soles+=1 end end
			assert(soles==4,"Quadrupeds need four grounded, layered paws")
		end
		checks+=4
	end
	print("PASS all 21 detailed creature factories ("..checks.." model assertions plus per-part safety checks)")
end
