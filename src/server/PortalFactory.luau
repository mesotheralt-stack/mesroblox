-- Original stone travel gates. Static geometry remains visible in edit mode;
-- PortalEffects animates only the marked decorative pieces on each client.
local PortalFactory = {}
local V = Vector3.new
local rgb = Color3.fromRGB

function PortalFactory.create(parent, entrance, worldId, tint)
	local gate=Instance.new("Folder")
	gate.Name="WorldTravelPortal"
	gate:SetAttribute("PortalVFX",true)
	gate:SetAttribute("WorldId",worldId)
	local center=entrance+V(0,12,0)
	local stone=rgb(151,167,158)
	local pale=rgb(228,239,218)
	local glow=tint:Lerp(rgb(112,235,219),0.6)
	local function piece(name,size,position,color,material,rotation,collide,shape)
		local p=Instance.new("Part")
		p.Name=name; p.Size=size; p.Position=position
		p.Color=color; p.Material=material or Enum.Material.SmoothPlastic
		p.Anchored=true; p.CanCollide=collide==true; p.CanTouch=false; p.CanQuery=false
		p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
		if shape then p.Shape=shape end
		p.CFrame=CFrame.new(position)*(rotation or CFrame.new())
		p.Parent=gate
		return p
	end
	local function animate(p,speed,pulse)
		p:SetAttribute("PortalCenter",center)
		p:SetAttribute("PortalBase",p.CFrame)
		p:SetAttribute("PortalSpin",speed)
		p:SetAttribute("PortalPulse",pulse or 0)
		p:SetAttribute("PortalAlpha",p.Transparency)
	end
	local function segment(name,a,b,width,color,speed)
		local delta=b-a
		local length=delta.Magnitude
		local up=math.abs(delta.Y/length)>0.98 and V(0,0,1) or V(0,1,0)
		local p=piece(name,V(width,width,length+0.08),(a+b)*0.5,color,Enum.Material.Neon,CFrame.lookAt(Vector3.zero,delta,up))
		p.Transparency=0.2
		animate(p,speed,0.055)
		return p
	end
	piece("PortalCourt",V(44,0.3,32),entrance+V(0,0.45,0),stone,Enum.Material.Cobblestone,nil,true)
	piece("CourtInlay",V(38,0.045,26),entrance+V(0,0.625,0),rgb(102,131,126),Enum.Material.Slate)
	for _,side in {-1,1} do
		piece("GateButtress",V(3.5,16,4.6),entrance+V(side*14,8,0),stone,Enum.Material.Slate,nil,true)
		piece("ButtressFoot",V(5.2,1.0,6),entrance+V(side*14,0.8,0),pale,Enum.Material.Marble,nil,true)
		local crystal=piece("PortalBeaconCrystal",V(2,4.6,2),entrance+V(side*14,18,0),glow,Enum.Material.Neon,CFrame.Angles(0,math.pi/4,0))
		crystal.Transparency=0.2
		local light=Instance.new("PointLight"); light.Color=glow;light.Range=35;light.Brightness=0.9;light.Parent=crystal
		for _,face in {-1,1} do piece("ButtressRune",V(0.45,8,0.08),entrance+V(side*14,9,face*2.34),glow,Enum.Material.Neon) end
	end
	for j=0,19 do
		local angle=j*math.pi/10
		local pos=center+V(math.sin(angle)*10.8,math.cos(angle)*10.8,0)
		piece("ArchStone",V(3.45,1.6,2.3),pos,stone:Lerp(pale,(j%3)*0.055),Enum.Material.Slate,CFrame.Angles(0,0,-angle))
		if j%2==0 then
			for _,face in {-1,1} do piece("RingRune",V(0.48,0.85,0.08),pos+V(0,0,face*1.2),glow,Enum.Material.Neon,CFrame.Angles(0,0,-angle)) end
		end
	end
	-- Three spiral arms form a complete vortex rather than a rotating flat disc.
	for arm=0,2 do
		for j=1,12 do
			local function at(t)
				local radius=0.9+7.25*t
				local angle=arm*math.pi*2/3+t*math.pi*1.55
				return center+V(math.cos(angle)*radius,math.sin(angle)*radius,0)
			end
			segment("SwirlingRibbon",at((j-1)/12),at(j/12),0.25+j*0.018,arm==1 and pale or glow,0.62)
		end
	end
	for j=1,6 do
		local a=j*math.pi/3
		local mote=piece("OrbitingSpark",V(0.52,0.52,0.52),center+V(math.cos(a)*8.8,math.sin(a)*8.8,0.55),pale,Enum.Material.Neon,nil,false,Enum.PartType.Ball)
		mote.Transparency=0.22
		animate(mote,-0.43,0.08)
	end
	local core=piece("VortexHeart",V(1.6,1.6,0.7),center,glow,Enum.Material.Neon,nil,false,Enum.PartType.Ball)
	core.Transparency=0.18
	animate(core,0,0.09)
	local veil=piece("PortalVeil",V(18,18,0.1),center,glow,Enum.Material.Glass,nil,false,Enum.PartType.Ball)
	veil.Transparency=0.94
	local target=piece("WorldPortal",V(2,2,1),entrance+V(0,4.5,0),glow)
	target.Transparency=1
	target:SetAttribute("WorldId",worldId)
	local prompt=Instance.new("ProximityPrompt")
	prompt.ActionText="Choose a world";prompt.ObjectText="World portal"
	prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.HoldDuration=0;prompt.MaxActivationDistance=18;prompt.RequiresLineOfSight=false
	prompt:SetAttribute("WorldTravel",true);prompt.Parent=target
	local board=piece("PortalHeader",V(29,3.6,0.6),entrance+V(0,26,0),rgb(37,68,61),Enum.Material.Wood)
	for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do
		local gui=Instance.new("SurfaceGui");gui.Name="PortalWayfinding";gui.Face=face;gui.CanvasSize=Vector2.new(720,100)
		gui.LightInfluence=0.15;gui.MaxDistance=160;gui.Parent=board
		local title=Instance.new("TextLabel")
		title.Size=UDim2.fromScale(1,0.6);title.BackgroundTransparency=1;title.Font=Enum.Font.BuilderSansBold;title.TextSize=36
		title.TextColor3=pale;title.Text="WORLD PORTAL";title.Parent=gui
		local subtitle=title:Clone();subtitle.Position=UDim2.fromScale(0,0.6);subtitle.Size=UDim2.fromScale(1,0.4)
		subtitle.Font=Enum.Font.BuilderSans;subtitle.TextSize=20;subtitle.TextColor3=glow;subtitle.Text="F / tap  ·  Travel to another world";subtitle.Parent=gui
	end
	gate.Parent=parent
	return gate
end

return PortalFactory
