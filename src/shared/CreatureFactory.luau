-- Original collectible sculptures. Every species has its own anatomy, proportions,
-- and face placement. Anchored geometry is shared by companions and ViewportFrames.
local CreatureFactory = {}
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BrainrotShared"):WaitForChild("Config"))
local V = Vector3.new
local A = CFrame.Angles
local ballShape = Enum.PartType.Ball

local function part(model, name, size, position, color, shape, rotation)
	local object = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = CFrame.new(position) * (rotation or CFrame.new())
	object.Color = color
	object.Material = Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape and shape ~= "Wedge" then object.Shape = shape end
	object.Parent = model
	return object
end

function CreatureFactory.create(spec, scale, variantId)
	local model = Instance.new("Model")
	model.Name = spec.name or "Brainrot"
	local variant = Config.variant(variantId)
	model:SetAttribute("Variant", variant.id)
	local base = spec.color or Color3.fromRGB(156, 215, 133)
	local trim = spec.accent or Color3.fromRGB(255, 217, 132)
	local ivory = Color3.fromRGB(255, 248, 226)
	local ink = Color3.fromRGB(30, 39, 43)
	local blush = Color3.fromRGB(247, 153, 147)
	local pale = base:Lerp(ivory, 0.43)
	local dark = base:Lerp(ink, 0.28)
	local shape = string.lower(spec.shape or "sprout")
	local function piece(name, size, position, color, kind, rotation)
		return part(model,name,size,position,color or base,kind,rotation)
	end
	local function orb(name, size, position, color, rotation)
		return piece(name,size,position,color,ballShape,rotation)
	end
	local function dot(name, position, radius, color)
		return orb(name,V(radius,radius,radius),position,color)
	end
	local function rod(name, a, b, width, color)
		local delta = b-a
		local length = delta.Magnitude
		if length < 0.001 then return dot(name,a,width,color) end
		-- A vertical segment needs a different up vector; a parallel default
		-- up vector produces a degenerate basis in CFrame implementations.
		local up = math.abs(delta.Y / length) > 0.98 and V(0,0,1) or V(0,1,0)
		return piece(name,V(width,width,length), (a+b)/2,color,nil,CFrame.lookAt(Vector3.zero,delta,up))
	end
	local function tube(name, points, width, color)
		for i=1,#points-1 do
			local thickness=width*(1-(i-1)/#points*0.52)
			rod(name,points[i],points[i+1],thickness,color)
			dot(name.."Joint",points[i],thickness*1.12,color)
		end
		dot(name.."Tip",points[#points],width*0.38,color)
	end
	local function ring(name, center, radius, thickness, color, plane, count)
		count = count or 12
		for i=1,count do
			local function at(t)
				if plane=="front" then return center+V(math.cos(t)*radius,math.sin(t)*radius,0) end
				return center+V(math.cos(t)*radius,0,math.sin(t)*radius)
			end
			rod(name,at((i-1)*math.pi*2/count),at(i*math.pi*2/count),thickness,color)
		end
	end
	local function flatTriangle(name,a,b,c,depth,color)
		-- Two right-triangle prisms fill a planar triangle exactly. Used for the
		-- moon's continuous crescent surface, with no scalloped overlapping balls.
		local ab=(b-a).Magnitude
		if (c-b).Magnitude>ab and (c-b).Magnitude>(c-a).Magnitude then a,b,c=b,c,a
		elseif (c-a).Magnitude>ab then a,b,c=c,a,b end
		local edge=b-a
		local length=edge.Magnitude
		if length<0.001 then return end
		local ux,uy=edge.X/length,edge.Y/length
		local projection=(c.X-a.X)*ux+(c.Y-a.Y)*uy
		local p=V(a.X+projection*ux,a.Y+projection*uy,a.Z)
		local height=(c-p).Magnitude
		if height<0.001 then return end
		local y=V((c.X-p.X)/height,(c.Y-p.Y)/height,0)
		for _,tip in {a,b} do
			local width=(p-tip).Magnitude
			if width>0.001 then
				local z=V((p.X-tip.X)/width,(p.Y-tip.Y)/width,0)
				local x=V(0,0,y.X*z.Y-y.Y*z.X)
				local center=p+y*(height/2)-z*(width/2)
				piece(name,V(depth,height,width),center,color,"Wedge",CFrame.fromMatrix(Vector3.zero,x,y,z))
			end
		end
	end
	local function eye(name, position, size, color)
		orb(name.."White",V(size,size*1.14,size*0.48),position,ivory)
		-- A coloured iris stays distinct from the pupil at collection-card sizes.
		local iris=orb(name.."Iris",V(size*0.62,size*0.73,size*0.17),position+V(0.025,-0.01,-size*0.25),color or base:Lerp(ink,0.58))
		iris.Material=Enum.Material.Glass
		iris.Reflectance=0.06
		orb(name.."Pupil",V(size*0.28,size*0.49,size*0.11),position+V(0.035,-0.01,-size*0.33),ink)
		dot(name.."Catchlight",position+V(-size*0.08,size*0.17,-size*0.4),size*0.17,ivory)
		-- A soft upper rim and second reflection add depth without changing
		-- the species' face placement or adding expensive effects.
		orb(name.."UpperLid",V(size*1.08,size*0.16,size*0.27),position+V(0,size*0.49,size*0.06),dark)
		dot(name.."SoftReflection",position+V(size*0.15,-size*0.17,-size*0.4),size*0.075,ivory)
	end
	local function face(position, separation, size, happy)
		for _,side in {-1,1} do
			eye(side<0 and "LeftEye" or "RightEye",position+V(side*separation,0,0),size)
			orb("Cheek",V(size*0.48,size*0.21,0.1),position+V(side*(separation+size*0.32),-size*0.54,0.05),blush)
		end
		if happy then
			orb("HappyMouth",V(size*0.48,size*0.35,0.15),position+V(0,-size*0.65,-0.1),ink)
			orb("Tongue",V(size*0.3,size*0.11,0.07),position+V(0,-size*0.74,-0.19),blush)
		else
			orb("Smile",V(size*0.5,0.09,0.12),position+V(0,-size*0.65,-0.1),ink)
		end
	end
	local function foot(position, size, color, claws)
		orb("Paw",size,position,color or trim)
		orb("PawSole",V(size.X*0.94,size.Y*0.24,size.Z*0.96),position+V(0,-size.Y*0.32,0), (color or trim):Lerp(ink,0.17))
		if claws then
			for i=-1,1 do
				orb("Toe",V(size.X*0.19,size.Y*0.32,size.Z*0.3),position+V(i*size.X*0.24,-size.Y*0.12,-size.Z*0.37),ivory)
			end
		end
	end
	local root=piece("Root",V(0.15,0.15,0.15),Vector3.zero,base)
	root.Transparency=1
	root:SetAttribute("Variant", variant.id)
	model.PrimaryPart=root

	if shape=="toast" then
		-- A broad bread slice, with a true double-lobed crust and inset crumb.
		local crust=Color3.fromRGB(171,108,57)
		piece("CrustSlice",V(3.0,2.8,0.82),V(0,2.1,0),crust)
		for _,side in {-1,1} do
			orb("CrustLobe",V(1.75,1.25,0.84),V(side*0.67,3.42,0),crust)
			orb("BreadLobe",V(1.47,1.0,0.12),V(side*0.64,3.4,-0.47),ivory:Lerp(trim,0.16))
			foot(V(side*0.75,0.4,-0.08),V(0.87,0.5,1.15),trim,false)
			orb("Mitten",V(0.55,0.7,0.5),V(side*1.7,1.9,-0.05),trim)
		end
		piece("SoftCrumb",V(2.62,2.65,0.14),V(0,2.11,-0.48),ivory:Lerp(trim,0.15))
		for i=1,9 do
			local x=((i*5)%11-5)*0.22
			dot("ToastPore",V(x,1.1+(i%4)*0.61,-0.58),0.08+(i%2)*0.04,crust:Lerp(ivory,0.39))
		end
		face(V(0,2.55,-0.61),0.58,0.55,true)
		piece("ButterPat",V(0.87,0.19,0.64),V(0.38,3.96,0),trim,nil,A(0,0.18,0.06))
		orb("MeltedButter",V(0.5,0.65,0.11),V(0.75,3.5,-0.6),trim)
		for i=1,3 do rod("BreadScoring",V(-0.93+(i-1)*0.31,3.35,-0.56),V(-0.72+(i-1)*0.31,3.6,-0.56),0.055,crust:Lerp(ivory,0.7)) end
	elseif shape=="sprout" then
		-- A ceramic pasta planter carrying a leaf-headed noodle creature.
		local pot=Color3.fromRGB(197,132,91)
		piece("PlanterBase",V(1.65,0.27,1.65),V(0,0.24,0),pot)
		piece("PlanterBowl",V(1.95,1.02,1.75),V(0,0.85,0),pot)
		piece("PlanterRim",V(2.2,0.23,1.98),V(0,1.41,0),pot:Lerp(ivory,0.15))
		piece("PotSoil",V(1.78,0.12,1.5),V(0,1.56,0),Color3.fromRGB(93,73,49))
		for i=1,7 do
			local a=i*math.pi*2/7
			tube("PastaCurl",{V(math.cos(a)*0.6,1.65,math.sin(a)*0.5),V(math.cos(a)*0.78,2.05,math.sin(a)*0.62),V(math.cos(a)*0.44,2.45,math.sin(a)*0.42)},0.2,trim)
		end
		orb("SproutHead",V(1.8,1.6,1.3),V(0,2.87,0),base)
		face(V(0,3.05,-0.64),0.38,0.47,false)
		tube("SproutStalk",{V(0,3.52,0),V(-0.12,4.0,0.05),V(0.07,4.4,0)},0.17,dark)
		for _,side in {-1,1} do
			orb("LeafBlade",V(1.65,0.34,0.88),V(side*0.72,4.32,0),base,nil)
			rod("LeafVein",V(side*0.1,4.5,-0.02),V(side*1.35,4.48,-0.02),0.05,pale)
			orb("PlanterHandle",V(0.34,0.65,0.55),V(side*1.12,1.05,0),pot)
		end
		piece("PotLabel",V(0.66,0.38,0.09),V(0,0.85,-0.91),ivory)
	elseif shape=="rock" then
		orb("LowStone",V(2.8,1.15,2.1),V(0,0.69,0),dark,A(0,0.12,0.1))
		orb("MiddleStone",V(2.55,1.8,2.0),V(-0.22,1.72,0),base,A(0,0,-0.12))
		orb("CrowningStone",V(1.9,1.15,1.65),V(0.15,2.85,0),pale,A(0,0,0.15))
		face(V(-0.1,2.05,-0.98),0.48,0.57,false)
		for i=1,7 do
			local x=((i*3)%7-3)*0.29
			piece("EmbeddedQuartz",V(0.14,0.25,0.11),V(x,0.7+(i%3)*0.5,-0.88),trim,nil,A(0,0,i*0.37))
		end
		for _,side in {-1,1} do
			foot(V(side*0.88,0.25,-0.25),V(0.86,0.35,0.95),dark,false)
			orb("MossPatch",V(0.75,0.2,0.5),V(side*0.82,2.83,0.45),Color3.fromRGB(121,160,97))
			rod("StoneFracture",V(side*0.7,2.8,-0.58),V(side*0.9,2.51,-0.82),0.055,dark)
		end
		for i=1,4 do dot("TinyMoss",V(-0.45+i*0.18,3.33,-0.1),0.18,Color3.fromRGB(143,176,106)) end
	elseif shape=="frog" then
		orb("FrogBody",V(3.15,1.8,2.65),V(0,1.25,0.3),base)
		orb("FrogBelly",V(2.5,1.35,0.4),V(0,1.22,-0.95),pale)
		orb("WideFrogHead",V(3.3,1.6,1.9),V(0,2.18,-0.38),base)
		for _,side in {-1,1} do
			orb("EyeTurret",V(1.0,1.1,0.95),V(side*0.98,2.98,-0.58),base)
			eye("FrogEye",V(side*0.98,3.03,-1.0),0.69,trim:Lerp(ink,0.5))
			orb("RearHaunch",V(1.35,1.2,1.7),V(side*1.35,0.9,0.95),dark)
			rod("FrontShin",V(side*1.1,1.4,-0.45),V(side*1.25,0.36,-1.05),0.34,base)
			for toe=1,3 do
				foot(V(side*1.24+(toe-2)*0.27,0.19,-1.24),V(0.37,0.22,0.82),trim,false)
			end
			for i=1,3 do dot("BackSpot",V(side*(0.7+i*0.16),1.92,0.55+i*0.2),0.21,dark) end
			for web=1,2 do
				orb("ToeWebbing",V(0.36,0.11,0.38),V(side*1.24+(web-1.5)*0.27,0.16,-1.06),trim:Lerp(base,0.28))
			end
		end
		orb("WideSmile",V(1.55,0.12,0.13),V(0,1.93,-1.35),ink)
		for _,side in {-1,1} do dot("Nostril",V(side*0.28,2.35,-1.3),0.11,dark) end
	elseif shape=="mushroom" then
		orb("StemBody",V(1.55,2.4,1.55),V(0,1.7,0),ivory)
		orb("MushroomBell",V(4.2,1.4,3.5),V(0,3.35,0),base)
		orb("CapCrown",V(3.5,1.3,3.0),V(0,3.6,0),base)
		orb("CapUnderside",V(3.7,0.22,3.05),V(0,2.99,0),trim:Lerp(ivory,0.53))
		for i=1,10 do
			local a=i*math.pi/5
			rod("CapGill",V(math.cos(a)*0.7,2.83,math.sin(a)*0.55),V(math.cos(a)*1.7,2.83,math.sin(a)*1.4),0.07,dark)
		end
		for i=1,7 do
			local a=i*math.pi*2/7
			local x,z=math.cos(a)*1.12,math.sin(a)*0.96
			local top=math.sqrt(1-(x/1.75)^2-(z/1.5)^2)
			local normal=V(x/(1.75*1.75),top/0.65,z/(1.5*1.5))
			local surface=V(x,3.6+0.65*top+0.025,z)
			orb("CreamCapSpot",V(0.49,0.08,0.43),surface,ivory,CFrame.lookAt(Vector3.zero,normal,V(0,0,1))*A(math.pi/2,0,0))
		end
		orb("CrownCapSpot",V(0.55,0.07,0.48),V(-0.16,4.26,-0.06),ivory)
		face(V(0,2.1,-0.79),0.34,0.44,true)
		for _,side in {-1,1} do foot(V(side*0.47,0.27,-0.17),V(0.65,0.4,0.95),trim,false) end
		tube("LittleWalkingStick",{V(1.35,0.2,-0.2),V(1.4,1.9,-0.2),V(1.15,2.25,-0.2)},0.13,Color3.fromRGB(146,108,69))
		for i=1,3 do orb("StemPleat",V(0.08,0.65,0.1),V((i-2)*0.3,0.98,-0.75),trim:Lerp(ivory,0.55)) end
	elseif shape=="bee" then
		orb("Abdomen",V(2.2,2.05,2.8),V(0,2.0,0.65),base)
		-- Match each stripe to the curved abdomen instead of pushing full-width
		-- discs through its tapered ends.
		for i=1,3 do
			local z=-0.1+(i-1)*0.63
			local section=math.sqrt(1-((z-0.65)/1.4)^2)
			for segment=1,16 do
				local function at(angle)
					return V(math.cos(angle)*(1.1*section+0.04),2+math.sin(angle)*(1.025*section+0.04),z)
				end
				rod("AbdomenBand",at((segment-1)*math.pi/8),at(segment*math.pi/8),0.14,trim)
			end
		end
		orb("Thorax",V(1.75,1.8,1.65),V(0,2.4,-0.75),base)
		orb("BeeHead",V(2.25,1.95,1.7),V(0,2.8,-1.35),base)
		face(V(0,2.95,-2.14),0.5,0.56,true)
		for _,side in {-1,1} do
			for j=1,2 do
				local wing=orb("GlassWing",V(2.1,0.16,1.3),V(side*(1.45+(j-1)*0.19),3.0,0.15+(j-1)*0.9),ivory,A(0,side*0.4,side*0.12))
				wing.Transparency=0.35
				rod("WingVein",V(side*0.8,3.12,0.3+(j-1)*0.7),V(side*2.23,3.12,0.0+(j-1)*0.8),0.055,pale)
			end
			tube("Antenna",{V(side*0.6,3.61,-1.4),V(side*0.76,4.1,-1.35),V(side*0.98,4.3,-1.55)},0.11,trim)
			dot("AntennaBulb",V(side*0.98,4.3,-1.55),0.25,base)
			for j=1,2 do rod("BeeLeg",V(side*0.63,1.4,0.35+(j-1)*0.8),V(side*0.95,0.6,0.35+(j-1)*0.8),0.16,trim) end
			foot(V(side*0.95,0.43,0.35),V(0.55,0.3,0.76),trim,false)
			dot("PollenBasket",V(side*0.95,0.8,1.15),0.32,base:Lerp(ivory,0.12))
		end
		piece("Stinger",V(0.45,0.6,0.85),V(0,1.9,2.13),trim,"Wedge",A(math.pi/2,0,0))
	elseif shape=="shark" then
		orb("SharkTorso",V(2.6,2.2,4.45),V(0,2.2,0.15),base)
		orb("SharkSnout",V(2.45,1.65,2.1),V(0,2.08,-1.7),base)
		orb("WhiteJaw",V(2.2,0.68,2.55),V(0,1.6,-1.25),ivory)
		piece("DorsalFin",V(0.35,1.55,1.9),V(0,3.75,0.6),dark,"Wedge",A(0,math.pi,0))
		piece("TailStem",V(0.65,0.75,1.9),V(0,2.2,2.55),base)
		for _,side in {-1,1} do
			piece("TailFluke",V(1.3,1.1,0.4),V(side*0.5,2.3,3.42),dark,"Wedge",A(0,0,side*0.65))
			piece("SideFlipper",V(1.7,0.3,1.5),V(side*1.55,1.93,0.0),base,"Wedge",A(0,side*0.25,0))
			eye("SharkEye",V(side*0.76,2.72,-1.96),0.48)
			for i=1,3 do rod("GillSlit",V(side*1.22,2.3,-0.4+i*0.29),V(side*1.12,1.86,-0.4+i*0.29),0.06,dark) end
			orb("SharkAnkle",V(0.5,0.8,0.72),V(side*0.79,1.08,-0.45),base)
			orb("SlipperUpper",V(1.1,0.62,1.75),V(side*0.79,0.61,-0.45),trim)
			orb("SlipperSole",V(1.16,0.2,1.83),V(side*0.79,0.26,-0.45),ivory)
			orb("SlipperTongue",V(0.55,0.1,0.77),V(side*0.79,0.9,-0.29),trim:Lerp(ivory,0.25))
			for lace=1,3 do rod("SlipperLace",V(side*0.79-0.3,0.9,-0.7+lace*0.21),V(side*0.79+0.3,0.9,-0.7+lace*0.21),0.055,ivory) end
		end
		orb("SharkSmile",V(1.28,0.1,0.1),V(0,1.87,-2.75),ink)
		for i=-2,2 do piece("TinyTooth",V(0.17,0.24,0.1),V(i*0.22,1.76,-2.74),ivory,"Wedge") end
	elseif shape=="cactus" then
		piece("TerracottaPot",V(1.8,1.0,1.65),V(0,0.6,0),Color3.fromRGB(192,125,96))
		piece("PotLip",V(2.1,0.25,1.9),V(0,1.2,0),trim)
		orb("CactusColumn",V(1.7,2.9,1.5),V(0,2.55,0),base)
		for _,side in {-1,1} do
			rod("CactusElbow",V(side*0.57,2.05,0),V(side*1.55,2.05,0),0.52,base)
			orb("RaisedCactusArm",V(0.67,1.65,0.65),V(side*1.55,2.65,0),base)
			for i=1,4 do piece("CactusSpine",V(0.08,0.17,0.12),V(side*0.72,1.65+i*0.39,-0.43),ivory,nil,A(0,0,side*0.6)) end
		end
		for i=-1,1 do rod("CactusRib",V(i*0.4,1.3,-0.72),V(i*0.4,3.45,-0.72),0.045,pale) end
		face(V(0,2.65,-0.77),0.35,0.43,false)
		for i=1,6 do local a=i*math.pi/3; orb("PinkPetal",V(0.75,0.23,0.48),V(math.cos(a)*0.38,4.0,math.sin(a)*0.32),trim,A(0,-a,0)) end
		dot("FlowerPollen",V(0,4.14,0),0.36,ivory)
		for i=-1,1 do piece("PotEngraving",V(0.17,0.17,0.06),V(i*0.35,0.6,-0.86),ivory,nil,A(0,0,math.pi/4)) end
	elseif shape=="cloud" then
		for i=-2,2 do orb("CloudBillow",V(1.8,1.55+(2-math.abs(i))*0.35,1.7),V(i*0.65,2.3+(2-math.abs(i))*0.24,0),i%2==0 and base or pale) end
		for i=-1,1 do orb("CloudFrontCurl",V(1.2,0.84,0.72),V(i*0.95,1.72,-0.65),ivory) end
		face(V(0,2.67,-0.99),0.5,0.5,false)
		for _,side in {-1,1} do
			foot(V(side*0.64,0.43,-0.02),V(0.75,0.45,0.95),trim,false)
			tube("DanglingRain",{V(side*1.59,1.8,0),V(side*1.59,1.3,0),V(side*1.7,1.05,0)},0.08,trim)
			orb("Raindrop",V(0.33,0.52,0.33),V(side*1.7,0.84,0),trim)
		end
		for i=1,6 do dot("CloudFoam",V(-1.2+i*0.35,3.45+(i%2)*0.2,-0.2),0.28,ivory) end
	elseif shape=="octopus" or shape=="jelly" then
		local jelly=shape=="jelly"
		orb(jelly and "JellyBell" or "OctopusMantle",V(2.65,2.7,2.25),V(0,2.55,0),base)
		orb("MantleSkirt",V(2.85,0.6,2.45),V(0,1.65,0),pale)
		for i=1,8 do
			local a=i*math.pi/4
			local x,z=math.sin(a),math.cos(a)
			local points={V(x*0.8,1.4,z*0.7),V(x*1.4,0.71,z*1.22),V(x*1.88,0.36,z*1.65),V(x*2.07,0.62,z*1.81)}
			tube(jelly and "JellyTendril" or "CurledTentacle",points,jelly and 0.23 or 0.47,i%2==0 and base or pale)
			for j=1,2 do dot("SuctionCup",V(x*(1.35+j*0.22),0.53,z*(1.15+j*0.2)),0.2,trim) end
		end
		face(V(0,2.7,-1.08),0.55,0.56,true)
		if jelly then
			local helmet=orb("ClearSpaceHelmet",V(3.2,3.25,2.85),V(0,2.7,0),ivory)
			helmet.Transparency=0.79
			local reflection=orb("HelmetReflection",V(0.34,0.89,0.08),V(-0.89,3.49,-1.05),ivory,A(0,0,-0.36))
			reflection.Transparency=0.45
			ring("HelmetSeal",V(0,1.35,0),1.37,0.13,trim,"horizontal",12)
			piece("AirPack",V(1.4,1.5,0.6),V(0,2.45,1.3),trim)
			for i=1,3 do piece("AirPackVent",V(0.85,0.08,0.05),V(0,2.1+i*0.22,1.62),dark) end
			for _,side in {-1,1} do piece("HelmetLatch",V(0.35,0.35,0.45),V(side*1.35,1.4,0),ivory) end
		else
			for i=1,5 do dot("MantleFreckle",V((i-3)*0.34,3.52+(i%2)*0.15,-0.55),0.14,trim) end
		end
	elseif shape=="bird" or shape=="phoenix" then
		local phoenix=shape=="phoenix"
		orb("BirdBelly",V(2.35,2.55,2.3),V(0,1.95,0.35),base)
		orb("BirdBreast",V(1.7,1.8,0.5),V(0,2.02,-0.7),pale)
		orb("BirdNeck",V(1.2,1.25,1.2),V(0,3.15,-0.3),base)
		orb("BirdHead",V(1.9,1.65,1.65),V(0,3.72,-0.45),base)
		orb("UpperBeak",V(1.08,0.53,1.24),V(0,3.43,-1.4),trim)
		orb("LowerBeak",V(0.97,0.26,1.06),V(0,3.12,-1.36),trim:Lerp(ink,0.13))
		for _,side in {-1,1} do
			eye("BirdEye",V(side*0.47,3.92,-1.15),0.44)
			rod("BirdShin",V(side*0.62,1.2,0.2),V(side*0.67,0.3,0.0),0.22,trim)
			for toe=1,3 do rod("BirdToe",V(side*0.67,0.22,0.05),V(side*0.67+(toe-2)*0.3,0.15,-0.73),0.14,trim) end
			for feather=1,4 do
				local wing=orb("LayeredWingFeather",V(0.62,2.0-feather*0.19,0.65),V(side*(1.1+feather*0.27),2.8-feather*0.12,0.45),feather%2==0 and trim or base,A(0,0,side*-0.59))
				if phoenix and feather==4 then wing.Material=Enum.Material.Neon end
			end
		end
		for i=-1,1 do
			orb("TailPlume",V(0.45,0.5,phoenix and 3.2 or 1.8),V(i*0.35,1.9,phoenix and 2.1 or 1.5),i==0 and base or trim,A(0,i*0.25,0))
			orb("HeadCrest",V(0.34,phoenix and 1.4 or 0.9,0.35),V(i*0.34,4.68,0),trim,nil)
		end
		for _,side in {-1,1} do
			rod("WingQuill",V(side*1.12,2.77,0.12),V(side*1.85,2.34,0.15),0.055,pale)
		end
		if not phoenix then
			for i=-1,1 do piece("DiscoChestTile",V(0.29,0.29,0.1),V(i*0.42,2.03,-1.01),trim,nil,A(0,0,math.pi/4)) end
			piece("DiscoHeadBand",V(1.5,0.18,0.19),V(0,4.12,-1.0),trim)
		end
	elseif shape=="wizard" then
		orb("RobeHem",V(2.7,0.55,2.0),V(0,0.48,0),dark)
		orb("RobeBody",V(2.35,2.65,1.9),V(0,1.8,0),base)
		for i=-2,2 do rod("RobePleat",V(i*0.38,0.58,-0.86),V(i*0.26,1.65,-0.9),0.075,pale) end
		orb("WizardHead",V(1.8,1.65,1.5),V(0,3.07,-0.1),pale)
		face(V(0,3.22,-0.84),0.37,0.47,false)
		orb("MoustacheLeft",V(0.58,0.24,0.2),V(-0.24,2.84,-0.98),ivory,A(0,0,-0.12))
		orb("MoustacheRight",V(0.58,0.24,0.2),V(0.24,2.84,-0.98),ivory,A(0,0,0.12))
		flatTriangle("PointedBeard",V(-0.45,2.88,-1.0),V(0.45,2.88,-1.0),V(0,1.9,-1.0),0.24,ivory)
		for i=-1,1 do rod("BeardStrand",V(i*0.24,2.69,-1.13),V(i*0.08,2.09,-1.13),0.035,ivory:Lerp(trim,0.18)) end
		piece("HatBrim",V(0.19,3.15,2.8),V(0,3.85,-0.05),dark,Enum.PartType.Cylinder,A(0,0,math.pi/2))
		for i=1,4 do orb("TaperedHatTier",V(2.1-i*0.33,0.56,1.8-i*0.26),V(i*0.07,3.92+i*0.39,-0.05),base) end
		tube("BentHatTip",{V(0.27,5.4,-0.05),V(0.6,5.69,-0.05),V(0.96,5.5,-0.08)},0.23,base)
		piece("HatRibbon",V(0.18,1.85,1.6),V(0,4.19,-0.05),trim,Enum.PartType.Cylinder,A(0,0,math.pi/2))
		piece("HatBrooch",V(0.31,0.31,0.13),V(0,4.08,-0.92),ivory,nil,A(0,0,math.pi/4))
		for _,side in {-1,1} do orb("WideSleeve",V(0.82,1.3,0.86),V(side*1.18,2.0,0),base,A(0,0,side*0.38)) end
		rod("Wand",V(1.66,0.75,-0.1),V(1.91,3.5,-0.1),0.15,dark)
		dot("WandCrystal",V(1.91,3.7,-0.1),0.48,trim)
		for i=1,3 do piece("RobeStar",V(0.15,0.15,0.06),V((i-2)*0.38,1.9+(i%2)*0.38,-0.98),trim,nil,A(0,0,math.pi/4)) end
	elseif shape=="lion" or shape=="capybara" or shape=="dragon" then
		local capy=shape=="capybara"
		local dragon=shape=="dragon"
		orb("BarrelBody",V(capy and 2.65 or 2.2,1.85,capy and 3.45 or 3.1),V(0,1.52,0.6),base)
		for _,side in {-1,1} do
			for _,z in {-0.35,1.57} do
				orb("Leg",V(0.65,1.05,0.74),V(side*0.79,0.8,z),base)
				foot(V(side*0.79,0.27,z-0.16),V(0.77,0.4,1.0),capy and dark or trim,not capy)
			end
		end
		if capy then
			orb("CapyHead",V(2.2,1.7,2.02),V(0,2.35,-1.05),base)
			orb("LongCapyMuzzle",V(1.85,1.2,1.8),V(0,2.03,-1.8),pale)
			for _,side in {-1,1} do
				eye("CapyEye",V(side*0.68,2.8,-1.58),0.39)
				orb("RoundedEar",V(0.62,0.72,0.52),V(side*0.83,3.19,-0.67),base)
				orb("EarVelvet",V(0.34,0.39,0.12),V(side*0.83,3.22,-0.94),trim)
				dot("CapyNostril",V(side*0.39,2.22,-2.6),0.14,dark)
				rod("CapyWhisker",V(side*0.63,1.93,-2.44),V(side*1.17,1.97,-2.37),0.045,ivory)
			end
			orb("CapyLip",V(0.71,0.1,0.13),V(0,1.77,-2.64),dark)
			orb("SatellitePlanet",V(0.75,0.75,0.75),V(-0.55,3.73,0.7),trim)
			ring("PlanetRing",V(-0.55,3.73,0.7),0.63,0.09,ivory,"horizontal",10)
			piece("ExplorerSatchel",V(0.65,0.89,0.98),V(1.27,1.65,0.66),trim)
			piece("SatchelFlap",V(0.68,0.22,1.02),V(1.27,1.96,0.66),trim:Lerp(ivory,0.22))
			piece("SatchelBuckle",V(0.1,0.22,0.23),V(1.63,1.72,0.64),ivory)
			rod("SatchelStrap",V(0.35,2.5,-0.2),V(1.26,1.8,0.18),0.11,trim)
		elseif dragon then
			orb("DragonNeck",V(1.45,1.7,1.3),V(0,2.4,-0.65),base)
			orb("DragonSkull",V(1.75,1.55,1.65),V(0,3.2,-1.1),base)
			orb("DragonSnout",V(1.45,0.84,1.45),V(0,2.92,-1.97),pale)
			for _,side in {-1,1} do
				eye("DragonEye",V(side*0.55,3.5,-1.68),0.44,trim:Lerp(ink,0.3))
				tube("SweptHorn",{V(side*0.59,3.81,-0.83),V(side*0.8,4.25,-0.52),V(side*0.88,4.51,-0.13)},0.24,ivory)
				for panel=1,3 do
					piece("WingMembrane",V(1.12,0.18,1.45),V(side*(1.1+panel*0.54),2.75+panel*0.19,0.4+panel*0.21),trim,"Wedge",A(0,side*0.24,side*-0.28))
					rod("WingRib",V(side*0.8,2.6,0.1),V(side*(1.4+panel*0.6),3.0+panel*0.17,0.15+panel*0.55),0.09,pale)
				end
				dot("DragonNostril",V(side*0.28,3.1,-2.62),0.11,dark)
				piece("DragonFang",V(0.12,0.21,0.1),V(side*0.37,2.63,-2.64),ivory,"Wedge")
			end
			orb("DragonSmile",V(0.88,0.085,0.1),V(0,2.74,-2.65),ink)
			tube("LongDragonTail",{V(0,1.58,1.8),V(0.38,1.39,2.5),V(0.9,1.16,3.1),V(1.52,1.37,3.35),V(1.86,1.63,3.1)},0.53,base)
			for i=1,5 do piece("BackSpine",V(0.3,0.48,0.47),V(0,2.57,0.0+i*0.4),trim,"Wedge") end
		else
			orb("LionHead",V(2.0,1.8,1.75),V(0,2.61,-1.04),base)
			for _,side in {-1,1} do
				orb("LionEar",V(0.64,0.7,0.46),V(side*0.74,3.54,-0.65),base)
				orb("LionEarVelvet",V(0.36,0.4,0.09),V(side*0.74,3.57,-0.89),blush:Lerp(base,0.35))
			end
			for i=1,14 do
				local a=i*math.pi*2/14
				orb("LayeredManeLock",V(0.61,0.91,0.61),V(math.sin(a)*1.18,2.61+math.cos(a)*1.18,-0.65),i%2==0 and trim or trim:Lerp(ink,0.13),A(0,0,-a))
			end
			for _,side in {-1,1} do
				eye("LionEye",V(side*0.47,2.95,-1.86),0.44)
				orb("LionMuzzle",V(0.69,0.57,0.43),V(side*0.3,2.35,-1.9),ivory)
				for i=1,2 do rod("Whisker",V(side*0.56,2.31,-2.1),V(side*1.0,2.23+i*0.15,-2.01),0.04,dark) end
			end
			orb("LionNose",V(0.35,0.27,0.2),V(0,2.56,-2.2),dark)
			tube("LionTail",{V(0,1.63,1.95),V(0.55,1.83,2.5),V(0.78,2.24,2.7)},0.18,base)
			orb("TailTuft",V(0.45,0.69,0.45),V(0.79,2.42,2.69),trim)
		end
	elseif shape=="sun" then
		-- A sculpted sun disc with layered flame rays, rather than a ball with a hat.
		orb("SunDisc",V(2.9,2.9,0.95),V(0,2.6,0),base)
		orb("SunInnerDisc",V(2.42,2.42,0.18),V(0,2.6,-0.53),pale)
		for i=1,12 do
			local a=i*math.pi/6
			piece("FlameRay",V(0.43,1.04,0.38),V(math.sin(a)*1.86,2.6+math.cos(a)*1.86,0),i%2==0 and trim or base,"Wedge",A(0,0,-a))
			orb("RayTip",V(0.2,0.36,0.18),V(math.sin(a)*2.2,2.6+math.cos(a)*2.2,0),pale,A(0,0,-a))
		end
		face(V(0,2.84,-0.67),0.51,0.57,true)
		for _,side in {-1,1} do foot(V(side*0.55,0.31,0),V(0.7,0.38,0.85),trim,false) end
	elseif shape=="moon" then
		-- A filled crescent ribbon has a clean silhouette and continuous front
		-- surface. The inner edge stays hollow and both horns taper to a point.
		local outer,inner={},{}
		for i=0,16 do
			local t=i/16
			local a=(0.3+t*1.4)*math.pi
			local thickness=0.045+math.sin(t*math.pi)^0.8*0.96
			local center=V(math.cos(a)*1.43,2.5+math.sin(a)*1.6,0)
			local normal=V(math.cos(a),math.sin(a),0)
			outer[i+1]=center+normal*(thickness/2)
			inner[i+1]=center-normal*(thickness/2)
		end
		for i=1,16 do
			flatTriangle("CrescentRibbon",outer[i],outer[i+1],inner[i],0.72,base)
			flatTriangle("CrescentRibbon",inner[i],outer[i+1],inner[i+1],0.72,base)
		end
		orb("MochiFace",V(1.35,1.55,0.95),V(-0.57,2.65,-0.12),pale)
		face(V(-0.57,2.82,-0.59),0.28,0.35,false)
		for i=1,5 do dot("MoonCrater",V(-1.4+(i%2)*0.23,1.8+i*0.27,-0.43),0.15+(i%2)*0.1,dark) end
		for _,side in {-1,1} do foot(V(side*0.45,0.35,0),V(0.6,0.35,0.8),trim,false) end
		for i=1,4 do
			local a=i*math.pi/2
			local sparkle=piece("MoonStar",V(0.22,0.22,0.17),V(math.cos(a)*2.05,2.7+math.sin(a)*1.8,0),trim,nil,A(0,0,math.pi/4))
			sparkle.Material=Enum.Material.Neon
		end
	elseif shape=="void" then
		orb("ObsidianCore",V(1.8,2.55,1.3),V(0,2.67,0),base)
		for i=1,5 do
			piece("FloatingArmorScale",V(1.7-i*0.16,0.36,1.25-i*0.08),V(0,1.5+i*0.38,-0.04),i%2==0 and base or dark,nil,A(0,i*0.2,0))
		end
		for _,side in {-1,1} do
			local pupil=orb("VoidEye",V(0.36,0.19,0.12),V(side*0.39,2.99,-0.75),trim,A(0,0,side*-0.15))
			pupil.Material=Enum.Material.Neon
			tube("CrescentShoulder",{V(side*0.85,2.7,0),V(side*1.22,2.9,0),V(side*1.46,3.35,0)},0.26,dark)
		end
		for i=1,18 do
			local a=i*math.pi/9
			local b=(i+1)*math.pi/9
			local halo=rod("TiltedVoidHalo",V(math.cos(a)*2.15,2.7+math.sin(a)*1.65,math.sin(a)*0.75),V(math.cos(b)*2.15,2.7+math.sin(b)*1.65,math.sin(b)*0.75),0.1,trim)
			halo.Material=Enum.Material.Neon
		end
		for i=1,6 do
			local a=i*math.pi/3
			piece("OrbitShard",V(0.35,0.65,0.25),V(math.cos(a)*2.15,2.7+math.sin(a)*1.65,math.sin(a)*0.75),base,"Wedge",A(0,0,-a))
		end
		ring("LowerOrbit",V(0,0.65,0),0.86,0.07,trim,"horizontal",10)
	elseif shape=="crown" then
		-- An emperor made of folded noodles, with a separate robe and royal regalia.
		orb("RoyalRobe",V(2.7,2.25,1.95),V(0,1.4,0),base)
		piece("CapePanel",V(2.8,2.5,0.23),V(0,1.9,0.99),dark)
		for i=-2,2 do tube("NoodlePleat",{V(i*0.4,0.55,-0.78),V(i*0.3,1.2,-0.95),V(i*0.22,1.95,-0.82)},0.17,trim) end
		orb("NoodleHead",V(1.85,1.65,1.4),V(0,3.0,0),pale)
		face(V(0,3.15,-0.68),0.38,0.46,false)
		piece("CrownBand",V(2.15,0.4,1.72),V(0,3.92,0),trim)
		for i=-2,2 do
			piece("CrownProng",V(0.26,0.62+(i%2)*0.24,0.3),V(i*0.43,4.37,-0.12),trim,"Wedge")
			dot("CrownPearl",V(i*0.43,4.72+(i%2)*0.12,-0.12),0.18,ivory)
		end
		for i=-1,1 do piece("CrownJewel",V(0.24,0.25,0.11),V(i*0.57,3.95,-0.91),i==0 and base or blush,nil,A(0,0,math.pi/4)) end
		for _,side in {-1,1} do
			orb("RoyalSleeve",V(0.82,1.15,0.8),V(side*1.17,2.05,0),base,A(0,0,side*0.4))
			foot(V(side*0.57,0.25,-0.15),V(0.68,0.36,1.0),trim,false)
		end
		rod("RoyalScepter",V(1.63,0.5,-0.1),V(1.63,3.17,-0.1),0.16,trim)
		dot("ScepterGem",V(1.63,3.4,-0.1),0.45,base)
	elseif shape=="croissant" then
		-- An arched pastry with layered folds, tapered tips and a baker's scarf.
		orb("PastryBelly",V(1.65,1.75,1.1),V(0,1.41,0.02),base:Lerp(ivory,0.17))
		for i=0,8 do
			local a=math.pi*(0.12+i*0.095)
			local t=0.63+math.sin(i/8*math.pi)*0.68
			orb("PastryFold",V(t,1.04,1.25),V(math.cos(a)*1.42,1.76+math.sin(a)*0.66,0),i%2==0 and base or base:Lerp(ivory,0.14),A(0,0,a-math.pi/2))
			rod("ToastedFold",V(math.cos(a)*1.42-0.16,1.93+math.sin(a)*0.66,-0.53),V(math.cos(a)*1.42+0.06,2.17+math.sin(a)*0.66,-0.47),0.055,dark)
		end
		for _,side in {-1,1} do
			orb("CurledPastryTip",V(0.59,0.8,0.9),V(side*1.57,1.49,-0.1),base,A(0,0,side*0.38))
			foot(V(side*0.63,0.33,0),V(0.7,0.43,1.05),trim,false)
		end
		orb("PastryFace",V(1.4,1.03,0.35),V(0,2.07,-0.65),pale)
		face(V(0,2.23,-0.83),0.33,0.42,true)
		piece("BakerScarf",V(1.65,0.22,0.45),V(0,1.38,-0.48),trim)
		piece("ScarfTail",V(0.34,0.7,0.14),V(0.54,1.02,-0.7),trim,nil,A(0,0,-0.19))
		for i=1,3 do dot("FlourDust",V((i-2)*0.35,2.88+(i%2)*0.08,-0.18),0.1,ivory) end
	elseif shape=="snail" then
		-- A low foot, raised head and a genuinely coiled shell make this a snail.
		orb("SnailFoot",V(2.2,0.43,3.65),V(0,0.43,0.12),base)
		orb("SnailBody",V(1.54,0.9,2.92),V(0,0.83,0.1),pale)
		orb("SnailNeck",V(1.25,1.38,1.02),V(0,1.2,-1.13),base)
		orb("SnailHead",V(1.6,1.04,1.03),V(0,1.8,-1.27),base)
		orb("SnailMuzzle",V(1.1,0.55,0.38),V(0,1.53,-1.64),pale)
		orb("CoiledShell",V(2.4,2.35,1.5),V(0,1.98,0.6),trim)
		local previous=nil
		for i=0,18 do
			local t=i/18
			local a=t*math.pi*3.8
			local p=V(math.cos(a)*(0.13+t*0.9),1.98+math.sin(a)*(0.13+t*0.89),-0.17)
			if previous then rod("ShellSpiral",previous,p,0.1,trim:Lerp(ink,0.22)) end
			previous=p
		end
		for _,side in {-1,1} do
			rod("SnailEyeStalk",V(side*0.45,2.07,-1.38),V(side*0.64,2.9,-1.37),0.13,dark)
			eye("SnailEye",V(side*0.64,2.93,-1.48),0.43,trim:Lerp(ink,0.5))
			for i=1,3 do dot("FootFreckle",V(side*(0.84-i*0.05),0.52,-0.8+i*0.57),0.12,trim) end
		end
		orb("SnailSmile",V(0.48,0.1,0.09),V(0,1.43,-1.84),ink)
		orb("SnailCheek",V(0.27,0.12,0.08),V(-0.36,1.5,-1.84),blush)
	elseif shape=="teapot" then
		orb("GlazedTeapot",V(2.6,2.25,2.1),V(0,1.77,0),base)
		orb("TeapotFootRing",V(1.85,0.28,1.55),V(0,0.7,0),trim)
		orb("PorcelainLid",V(2.05,0.35,1.79),V(0,2.94,0),pale)
		orb("LidFinial",V(0.45,0.48,0.45),V(0,3.3,0),trim)
		tube("CurvedSpout",{V(-1.0,1.7,0),V(-1.6,1.94,0),V(-1.88,2.46,0),V(-2.13,2.7,0)},0.44,base)
		orb("SpoutRim",V(0.46,0.23,0.46),V(-2.13,2.73,0),trim,A(0,0,-0.4))
		ring("TeapotHandle",V(1.39,1.99,0.14),0.79,0.18,trim,"front",12)
		face(V(0,1.97,-1.03),0.47,0.52,true)
		for _,side in {-1,1} do foot(V(side*0.55,0.33,-0.01),V(0.66,0.4,0.96),trim,false) end
		for i=-1,1 do
			piece("PorcelainPetal",V(0.2,0.25,0.055),V(i*0.33,1.17,-0.94),trim,nil,A(0,0,i*0.55))
		end
		for i=1,3 do
			local steam=orb("TeaSteam",V(0.18,0.65,0.17),V(-0.36+(i-1)*0.36,3.67+(i%2)*0.23,0.04),ivory,A(0,0,i%2==0 and 0.25 or -0.25))
			steam.Transparency=0.48
		end
	elseif shape=="turtle" then
		orb("TerrapinBody",V(2.65,1.2,2.75),V(0,0.93,0.24),base)
		orb("TerrariumShell",V(3.25,1.8,3.1),V(0,1.7,0.45),trim)
		piece("ShellRim",V(0.3,3.4,3.2),V(0,1.13,0.45),trim:Lerp(ink,0.17),Enum.PartType.Cylinder,A(0,0,math.pi/2))
		for i=1,7 do
			local a=i*math.pi*2/7
			local x,z=math.cos(a)*0.94,math.sin(a)*0.82
			local top=math.sqrt(1-(x/1.625)^2-(z/1.55)^2)
			local normal=V(x/(1.625*1.625),top/0.9,z/(1.55*1.55))
			orb("ShellMosaic",V(0.65,0.14,0.7),V(x,1.7+0.9*top+0.065,0.45+z),i%2==0 and pale or base,CFrame.lookAt(Vector3.zero,normal,V(0,0,1))*A(math.pi/2,0,0))
		end
		orb("ShellCrownMosaic",V(1.05,0.16,1.16),V(0,2.69,0.45),pale)
		orb("TurtleNeck",V(1.15,0.74,0.95),V(0,1.14,-1.31),base)
		orb("TerrapinHead",V(1.7,1.1,1.36),V(0,1.48,-1.83),base)
		face(V(0,1.65,-2.43),0.36,0.45,false)
		for _,side in {-1,1} do
			for _,z in {-0.59,1.36} do foot(V(side*1.23,0.48,z),V(0.85,0.5,1.19),base,false) end
		end
		tube("TurtleTail",{V(0,0.91,1.59),V(0,0.7,2.08),V(0.22,0.73,2.4)},0.24,base)
		-- A living little garden grows from the shell's crown.
		rod("TerrariumSprig",V(0,2.62,0.45),V(0.06,3.33,0.45),0.1,dark)
		for _,side in {-1,1} do orb("ShellGardenLeaf",V(0.71,0.17,0.35),V(side*0.3,3.18,0.45),base,A(0,side*0.2,side*0.25)) end
		dot("ShellGardenBud",V(0.06,3.45,0.45),0.31,ivory)
	elseif shape=="koi" then
		orb("KoiBody",V(2.2,2.03,3.65),V(0,1.94,0.24),base)
		orb("KoiBelly",V(1.65,1.22,2.8),V(0,1.47,-0.1),ivory)
		orb("KoiHead",V(1.95,1.82,1.8),V(0,2.05,-1.15),base)
		orb("KoiTailPeduncle",V(0.86,0.85,1.05),V(0,1.94,2.04),base)
		face(V(0,2.24,-1.98),0.43,0.46,false)
		orb("KoiLips",V(0.54,0.24,0.18),V(0,1.65,-2.05),trim)
		for _,side in {-1,1} do
			piece("KoiFanTail",V(1.65,1.5,0.2),V(side*0.61,1.94,2.58),trim,"Wedge",A(0,0,side*0.65))
			orb("PectoralFin",V(1.72,0.2,1.1),V(side*1.4,1.76,-0.12),trim,A(0,side*0.52,side*-0.2))
			tube("KoiWhisker",{V(side*0.38,1.75,-1.99),V(side*0.77,1.57,-2.15),V(side*1.02,1.7,-2.11)},0.06,ivory)
			for i=1,3 do
				local z=-0.3+i*0.53
				local x=side*1.1*math.sqrt(1-(0.06/1.015)^2-((z-0.24)/1.825)^2)
				local normal=V(x/(1.1*1.1),0.06/(1.015*1.015),(z-0.24)/(1.825*1.825))
				orb("KoiSideScale",V(0.13,0.43,0.49),V(x+side*0.06,2.0,z),trim:Lerp(base,i*0.11),CFrame.lookAt(Vector3.zero,normal)*A(0,math.pi/2,0))
			end
			local function finSurface(u,v)
				local y=0.1*math.sqrt(1-(u/0.86)^2-(v/0.55)^2)+0.035
				local yaw,roll=side*0.52,side*-0.2
				local x=math.cos(roll)*u-math.sin(roll)*y
				return V(side*1.4+math.cos(yaw)*x+math.sin(yaw)*v,1.76+math.sin(roll)*u+math.cos(roll)*y,-0.12-math.sin(yaw)*x+math.cos(yaw)*v)
			end
			for i=1,3 do rod("FinRay",finSurface(side*-0.35,0),finSurface(side*0.6,(i-2)*0.16),0.035,ivory) end
		end
		for i=1,4 do piece("KoiDorsal",V(0.17,0.62,0.74),V(0,2.96,0.03+i*0.43),trim,"Wedge") end
		orb("KoiForeheadMark",V(0.8,0.15,0.65),V(0,2.99,-1.17),trim)
		ring("FloatingRipple",V(0,0.34,0.24),1.41,0.055,trim,"horizontal",14)
	elseif shape=="clock" then
		local brass=trim
		piece("WatchCase",V(0.79,3.15,3.15),V(0,2.13,0),brass,Enum.PartType.Cylinder,A(0,math.pi/2,0))
		piece("WatchDial",V(0.12,2.76,2.76),V(0,2.13,-0.45),pale,Enum.PartType.Cylinder,A(0,math.pi/2,0))
		for i=1,12 do
			local a=i*math.pi/6
			piece("DialHourMark",V(0.09,i%3==0 and 0.24 or 0.15,0.06),V(math.sin(a)*1.15,2.13+math.cos(a)*1.15,-0.54),brass,nil,A(0,0,-a))
		end
		rod("ClockMinuteHand",V(0,2.32,-0.59),V(-0.44,2.95,-0.59),0.09,dark)
		rod("ClockHourHand",V(0,2.32,-0.62),V(0.5,2.62,-0.62),0.13,dark)
		dot("ClockPin",V(0,2.32,-0.7),0.21,brass)
		face(V(0,1.88,-0.56),0.48,0.4,false)
		piece("WindingCrown",V(0.62,0.33,0.5),V(0,3.89,0),brass)
		ring("WatchBow",V(0,4.26,0),0.35,0.11,brass,"front",10)
		for _,side in {-1,1} do
			foot(V(side*0.64,0.29,0),V(0.78,0.4,1.05),brass,false)
			orb("WatchGlove",V(0.48,0.6,0.44),V(side*1.63,1.83,0),ivory)
		end
		for i=1,3 do
			local a=i*math.pi/2
			piece("OrbitTick",V(0.16,0.24,0.14),V(math.sin(a)*2.03,2.13+math.cos(a)*1.86,0),brass,nil,A(0,0,-a))
		end
	elseif shape=="manta" then
		-- Broad swept wings, cephalic fins and a flowing tail create a ray silhouette.
		orb("NebulaRayBody",V(2.9,1.12,3.0),V(0,1.83,0),base)
		orb("RayIvoryBelly",V(2.55,0.36,2.65),V(0,1.42,-0.07),pale)
		for _,side in {-1,1} do
			orb("RayWingShoulder",V(1.35,0.52,1.9),V(side*1.1,1.8,0.1),base)
			orb("SweptRayWing",V(4.0,0.33,2.3),V(side*2.37,1.79,0.37),base,A(0,side*0.37,side*0.14))
			tube("CephalicFin",{V(side*0.78,1.85,-1.04),V(side*1.02,1.96,-1.66),V(side*0.75,2.15,-1.91)},0.29,base)
			local function onWing(i)
				local u,v=side*(-0.9+i*0.65),(i%2)*0.2
				local y=0.165*math.sqrt(1-(u/2)^2-(v/1.15)^2)+0.055
				local yaw,roll=side*0.37,side*0.14
				local x=math.cos(roll)*u-math.sin(roll)*y
				return V(side*2.37+math.cos(yaw)*x+math.sin(yaw)*v,1.79+math.sin(roll)*u+math.cos(roll)*y,0.37-math.sin(yaw)*x+math.cos(yaw)*v)
			end
			for i=1,3 do
				dot("RayConstellationStar",onWing(i),0.15,ivory)
				if i<3 then rod("RayConstellationLine",onWing(i),onWing(i+1),0.035,trim) end
			end
			eye("RayEye",V(side*0.48,2.08,-1.38),0.41,trim:Lerp(ink,0.5))
		end
		tube("CometRayTail",{V(0,1.82,1.3),V(0.23,1.81,2.17),V(0.73,2.06,3.0),V(1.38,2.55,3.56),V(1.7,2.93,3.38)},0.26,dark)
		orb("RaySmile",V(0.48,0.1,0.13),V(0,1.68,-1.5),ink)
		for i=1,3 do
			piece("AstralRayCrest",V(0.19,0.66+(i%2)*0.23,0.18),V((i-2)*0.33,2.7,0.1),trim,"Wedge",A(0,0,(i-2)*0.22))
		end
		local crystal=piece("RayCrestGem",V(0.25,0.34,0.21),V(0,3.22,0.08),trim,"Wedge")
		crystal.Material=Enum.Material.Glass
	else
		orb("UnknownBud",V(2.4,2.6,2.0),V(0,1.8,0),base)
		face(V(0,2.2,-0.96),0.48,0.53,true)
		for _,side in {-1,1} do foot(V(side*0.6,0.35,0),V(0.7,0.45,1.0),trim,false) end
	end
	-- Selected finishes give the sculptures a deliberate material hierarchy;
	-- broad bodies stay soft while glass, cloth and royal metal read separately.
	local finishes={
		LowStone=Enum.Material.Slate,MiddleStone=Enum.Material.Slate,CrowningStone=Enum.Material.Slate,
		EmbeddedQuartz=Enum.Material.Glass,GlassWing=Enum.Material.Glass,
		ClearSpaceHelmet=Enum.Material.Glass,WandCrystal=Enum.Material.Glass,ScepterGem=Enum.Material.Glass,
		CrownBand=Enum.Material.Metal,CrownProng=Enum.Material.Metal,CrownJewel=Enum.Material.Glass,
		RoyalScepter=Enum.Material.Metal,DiscoChestTile=Enum.Material.Metal,DiscoHeadBand=Enum.Material.Metal,
		FloatingArmorScale=Enum.Material.Metal,OrbitShard=Enum.Material.Glass,
		ExplorerSatchel=Enum.Material.Fabric,SatchelFlap=Enum.Material.Fabric,
		SatchelBuckle=Enum.Material.Metal,BakerScarf=Enum.Material.Fabric,ScarfTail=Enum.Material.Fabric,
		GlazedTeapot=Enum.Material.Glass,PorcelainLid=Enum.Material.Glass,PorcelainPetal=Enum.Material.Metal,
		WatchCase=Enum.Material.Metal,WindingCrown=Enum.Material.Metal,WatchBow=Enum.Material.Metal,
		DialHourMark=Enum.Material.Metal,ClockPin=Enum.Material.Metal,OrbitTick=Enum.Material.Metal,
		LittleWalkingStick=Enum.Material.Wood,LittleWalkingStickJoint=Enum.Material.Wood,LittleWalkingStickTip=Enum.Material.Wood,
	}
	for _,object in model:GetChildren() do
		if object:IsA("BasePart") then
			if finishes[object.Name] then object.Material=finishes[object.Name] end
			-- Tiny face layers should read as a painted expression, not cast
			-- striped shadows over the eye or cheek beneath them.
			if string.match(object.Name,"White$") or string.match(object.Name,"Iris$") or string.match(object.Name,"Pupil$")
				or string.match(object.Name,"Catchlight$") or string.match(object.Name,"UpperLid$") or string.match(object.Name,"SoftReflection$")
				or object.Name=="Cheek" or object.Name=="HappyMouth" or object.Name=="Smile" or object.Name=="Tongue" then
				object.CastShadow=false
			end
		end
	end
	if variant.id~="Normal" then
		-- Finish the complete sculpture, including species-specific hard-coded
		-- details. Luminance keeps engraved patterns and trim distinct; eyes and
		-- expressions remain painted so a rare finish never hides the face.
		local shadow=variant.color:Lerp(ink,0.48)
		local highlight=variant.accent
		local diamond=variant.id=="Diamond"
		local crystalHost,hostHeight=nil,-math.huge
		for _,object in model:GetChildren() do
			if object:IsA("BasePart") and object~=root then
				local name=object.Name
				local facialWhite=string.match(name,"White$") or string.match(name,"Catchlight$") or string.match(name,"SoftReflection$")
				local facialInk=string.match(name,"Pupil$") or string.find(name,"Smile",1,true) or name=="HappyMouth" or name=="Nostril"
				local facialColor=name=="Cheek" or name=="Tongue"
				if string.match(name,"Iris$") then
					object.Color=variant.color:Lerp(ink,0.6)
				elseif name=="VoidEye" then
					object.Color=highlight
				elseif not facialWhite and not facialInk and not facialColor then
					local original=object.Color
					local luminance=original.R*0.2126+original.G*0.7152+original.B*0.0722
					object.Color=shadow:Lerp(highlight,math.clamp(luminance*0.88,0.06,0.94))
					object.Material=diamond and Enum.Material.Glass or Enum.Material.Metal
					object.Reflectance=diamond and 0.13 or 0.08
					-- Existing transparent helmets, wings and steam keep their
					-- transparency; opaque bodies stay solid and easy to read.
					if math.max(object.Size.X,object.Size.Z)>=1 and object.Size.Y>=0.4 and math.min(object.Size.X,object.Size.Z)>=0.5 then
						local height=object.CFrame.Y+object.Size.Y/2
						if height>hostHeight then crystalHost,hostHeight=object,height end
					end
				end
			end
		end
		if diamond and crystalHost then
			-- Two small cut stones follow an existing upper surface rather than
			-- adding an aura or changing the creature's authored silhouette.
			for _,side in {-1,1} do
				local offset=V(side*0.25,crystalHost.Size.Y/2+0.11,0)
				for _,facet in {-1,1} do
					local stone=piece("DiamondFacet",V(0.22,0.28,0.18),Vector3.zero,
						facet<0 and variant.color or highlight,"Wedge")
					stone.CFrame=crystalHost.CFrame*CFrame.new(offset+V(0,0,facet*0.075))*A(0,facet<0 and math.pi or 0,0)
					stone.Material=Enum.Material.Glass;stone.Reflectance=0.2;stone.CastShadow=false
				end
			end
		end
	end
	if spec.rarity=="Mythic" or spec.rarity=="Secret" then
		local light=Instance.new("PointLight")
		light.Color=variant.id=="Normal" and trim or variant.accent
		light.Brightness=0.35
		light.Range=7
		light.Parent=root
	end
	if scale and scale~=1 then model:ScaleTo(math.clamp(scale,0.1,5)) end
	return model
end

return CreatureFactory
