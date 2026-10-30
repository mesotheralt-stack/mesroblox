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
				if string.match(part.Name,"Iris$") then assert(part.CastShadow==false,"Layered eyes must not cast small striping shadows across the face") end
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
		elseif spec.shape=="shark" then
			local ankle=model:FindFirstChild("SharkAnkle")
			local slipper=model:FindFirstChild("SlipperUpper")
			assert(ankle and ankle.CFrame.Y-ankle.Size.Y/2<slipper.CFrame.Y+slipper.Size.Y/2,"Shark legs must join its slippers instead of floating above them")
			assert(ankle.CFrame.Y+ankle.Size.Y/2>1.4 and model:FindFirstChild("SlipperTongue"),"Slipper ankles must reach the body and finish the upper shoe")
		elseif spec.shape=="wizard" then
			assert(model:FindFirstChild("RobeHem").Shape==Enum.PartType.Ball and model:FindFirstChild("HatRibbon").Shape==Enum.PartType.Cylinder,"Wizard cloth and hat trim need rounded silhouettes")
			local beard=0
			for _,piece in model:GetChildren() do if piece.Name=="PointedBeard" then assert(piece.ClassName=="WedgePart");beard+=1 end end
			assert(beard==2,"Wizard beard needs a continuous triangular face")
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
			for _,piece in model:GetChildren() do
				if piece.Name=="ShellMosaic" then
					local surface=1.7+0.9*math.sqrt(1-(piece.CFrame.X/1.625)^2-((piece.CFrame.Z-0.45)/1.55)^2)
					assert(piece.CFrame.Y-surface>0.05,"Shell mosaic plates must clear the curved shell surface")
				end
			end
		elseif spec.shape=="koi" then
			assert(model:FindFirstChild("KoiFanTail") and model:FindFirstChild("KoiWhisker") and model:FindFirstChild("FinRay"),"Koi needs fan tail, barbels and patterned fins")
			local tail=model:FindFirstChild("KoiTailPeduncle")
			assert(tail and tail.CFrame.Z-tail.Size.Z/2<2.065 and tail.CFrame.Z+tail.Size.Z/2>2.48,"Koi tail must overlap the body and tail fan")
			local scales={}
			for _,piece in model:GetChildren() do if piece.Name=="KoiSideScale" then table.insert(scales,piece) end end
			assert(math.abs(scales[1].CFrame.X)>math.abs(scales[3].CFrame.X),"Koi scales must taper with the body rather than float off its sides")
		elseif spec.shape=="clock" then
			assert(model:FindFirstChild("ClockMinuteHand") and model:FindFirstChild("ClockHourHand") and model:FindFirstChild("WatchBow"),"Pocketwatch needs separate hands and winding bow")
		elseif spec.shape=="manta" then
			assert(model:FindFirstChild("SweptRayWing") and model:FindFirstChild("CephalicFin") and model:FindFirstChild("CometRayTail") and model:FindFirstChild("RayConstellationStar"),"Manta needs broad ray wings, forward fins and celestial details")
			assert(model:FindFirstChild("RayWingShoulder"),"Ray wings need a smooth shoulder transition into their body")
		end
		checks+=4
	end
	print("PASS all "..#content.Creatures.." detailed creature factories ("..checks.." model assertions plus per-part safety checks)")
end
