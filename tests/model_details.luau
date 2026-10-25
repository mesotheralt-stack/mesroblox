-- Execute every real procedural model branch, including the uncommon species
-- that the seven-specimen world gallery does not instantiate.
vectorMeta.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
CFrame.lookAt=function(position,_target) return position end
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
				assert(part.Anchored and not part.CanCollide and not part.CanTouch,"Preview geometry must be inert")
				assert(part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0,"No zero-size model pieces")
				parts+=1
			end
		end
		assert(parts>=30 and parts<=110,spec.id.." detail budget outside 30–110 pieces: "..parts)
		checks+=4
	end
	print("PASS all 21 detailed creature factories ("..checks.." model assertions plus per-part safety checks)")
end
