-- Execute every real procedural model branch, including species not owned by
-- the current player. The public specimen showcase has been removed.
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
		assert(parts>=30 and parts<=150,spec.id.." detail budget outside 30–150 pieces: "..parts)
		assert(not model:FindFirstChild("UnknownBud"),"Every catalogue species needs an authored sculpture")
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
		elseif spec.shape=="croissant" then
			assert(model:FindFirstChild("PastryFold") and model:FindFirstChild("CurledPastryTip") and model:FindFirstChild("BakerScarf"),"Croissant needs pastry anatomy and its baker scarf")
		elseif spec.shape=="snail" then
			assert(model:FindFirstChild("SnailFoot") and model:FindFirstChild("ShellSpiral") and model:FindFirstChild("SnailEyeStalk"),"Snail needs a low foot, coiled shell and raised eyes")
		elseif spec.shape=="teapot" then
			assert(model:FindFirstChild("CurvedSpout") and model:FindFirstChild("TeapotHandle") and model:FindFirstChild("PorcelainLid"),"Teapot needs spout, open handle and lid")
		elseif spec.shape=="turtle" then
			local soles=0
			for _,piece in model:GetChildren() do if piece.Name=="PawSole" then soles+=1 end end
			assert(soles==4 and model:FindFirstChild("ShellMosaic") and model:FindFirstChild("ShellGardenBud"),"Terrapin needs four feet, a plated shell and living garden")
		elseif spec.shape=="koi" then
			assert(model:FindFirstChild("KoiFanTail") and model:FindFirstChild("KoiWhisker") and model:FindFirstChild("FinRay"),"Koi needs fan tail, barbels and patterned fins")
		elseif spec.shape=="clock" then
			assert(model:FindFirstChild("ClockMinuteHand") and model:FindFirstChild("ClockHourHand") and model:FindFirstChild("WatchBow"),"Pocketwatch needs separate hands and winding bow")
		elseif spec.shape=="manta" then
			assert(model:FindFirstChild("SweptRayWing") and model:FindFirstChild("CephalicFin") and model:FindFirstChild("CometRayTail") and model:FindFirstChild("RayConstellationStar"),"Manta needs broad ray wings, forward fins and celestial details")
		end
		checks+=4
	end
	print("PASS all "..#content.Creatures.." detailed creature factories ("..checks.." model assertions plus per-part safety checks)")
end
