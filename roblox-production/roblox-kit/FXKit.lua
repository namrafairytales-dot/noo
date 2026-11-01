--[[
FXKit  -  builds the effect types seen in the reference videos, ready for CineCam.fx / CineCam.burst.

Put in ReplicatedStorage > FXKit (ModuleScript). Run the builders ONCE in Edit mode
(command bar or your Studio AI), e.g.

  local FX = require(game.ReplicatedStorage.FXKit)
  FX.orb("PowerOrb", workspace.Marks.OrbStart.Position, Color3.fromRGB(255, 235, 140))
  FX.dust("LandingDust", workspace.Marks.LandingSpot.Position, Color3.fromRGB(200, 170, 120))
  FX.aura("HeroAura", workspace.Cast.Hero, Color3.fromRGB(255, 160, 60))
  FX.laser("EyeLasers", workspace.Cast.Kid.Head, workspace.Marks.Sky, Color3.fromRGB(120, 230, 255))
  FX.snow("Snow", workspace.Marks.SetCentre.Position, 120)

Everything is created DISABLED. In the shot list turn it on with
  {at = 0.4, fn = function() CineCam.fx("PowerOrb", true) end}
or fire a one-shot puff with
  {at = 0.0, fn = function() CineCam.burst("LandingDust", 60) end}

Textures: the built-in Roblox particle textures are used so everything works offline.
For a richer look swap Texture for a Creator Store particle texture you like.
]]

local FXKit = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function fxFolder(name)
	local root = workspace:FindFirstChild("FX")
	if not root then
		root = Instance.new("Folder")
		root.Name = "FX"
		root.Parent = workspace
	end
	local f = root:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function anchorPart(parent, pos, size)
	local p = Instance.new("Part")
	p.Name = "Emitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = parent
	return p
end

local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- Sparkle / glitter (power gained, magic, download complete, "ding" moments)
function FXKit.sparkles(name, pos, color, parentOverride)
	local f = parentOverride or fxFolder(name)
	local p = typeof(pos) == "Vector3" and anchorPart(f, pos) or pos
	local e = Instance.new("ParticleEmitter")
	e.Name = name .. "_Sparkles"
	e.Texture = SPARK
	e.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = seq(0.5, 0)
	e.Transparency = seq(0, 1)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 40
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Enabled = false
	e.Parent = p
	return e
end

-- Ground dust explosion (landing, punch, running start, car skid)
function FXKit.dust(name, pos, color)
	local f = fxFolder(name)
	local p = anchorPart(f, pos)
	local e = Instance.new("ParticleEmitter")
	e.Name = name .. "_Dust"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color or Color3.fromRGB(205, 180, 140))
	e.Size = seq(2, 7)
	e.Transparency = seq(0.15, 1)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(85, 85)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 4
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Rate = 0
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Enabled = false
	e.Parent = p
	return e
end

-- Glowing power orb / soul (neon ball + light + sparkles). Fly it with CineCam.flyTo on the "Orb" Model.
function FXKit.orb(name, pos, color)
	local f = fxFolder(name)
	local m = Instance.new("Model")
	m.Name = "Orb"
	m.Parent = f
	local ball = Instance.new("Part")
	ball.Name = "Core"
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color or Color3.fromRGB(255, 235, 140)
	ball.Size = Vector3.new(1.6, 1.6, 1.6)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(pos)
	ball.Transparency = 1
	ball:SetAttribute("FXVisible", 0) -- CineCam.fx(name, true) makes it visible
	ball.Parent = m
	m.PrimaryPart = ball
	local light = Instance.new("PointLight")
	light.Color = ball.Color
	light.Range = 14
	light.Brightness = 3
	light.Enabled = false
	light.Parent = ball
	FXKit.sparkles(name, ball, ball.Color, f)
	return m
end

-- Aura that follows an actor (power-up, rage, glow while transformed)
function FXKit.aura(name, actor, color)
	local root = actor:FindFirstChild("HumanoidRootPart") or actor.PrimaryPart
	local att = root:FindFirstChild(name) or Instance.new("Attachment")
	att.Name = name
	att.Parent = root
	for _, c in ipairs(att:GetChildren()) do
		c:Destroy()
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color or Color3.fromRGB(255, 170, 60))
	e.LightEmission = 1
	e.Size = seq(1.2, 0)
	e.Transparency = seq(0.2, 1)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 60
	e.LockedToPart = true
	e.Enabled = false
	e.Parent = att
	local h = Instance.new("Highlight")
	h.FillColor = color or Color3.fromRGB(255, 170, 60)
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = actor
	h.Enabled = false
	h.Parent = att
	return att
end

-- Beam from a part (e.g. Head) to a target part (eye lasers, tractor beam, download beam)
function FXKit.laser(name, fromPart, toPart, color, width)
	local f = fxFolder(name)
	local a0 = Instance.new("Attachment")
	a0.Name = name .. "_A0"
	a0.Parent = fromPart
	local a1 = Instance.new("Attachment")
	a1.Name = name .. "_A1"
	a1.Parent = toPart
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color or Color3.fromRGB(120, 230, 255))
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Width0 = width or 0.35
	b.Width1 = width or 0.35
	b.FaceCamera = true
	b.Segments = 2
	b.Enabled = false
	b.Parent = f
	return b
end

-- Falling snow (or rain: change colour/size/speed) over an area around a point
function FXKit.snow(name, centre, area)
	local f = fxFolder(name)
	local p = anchorPart(f, centre + Vector3.new(0, 40, 0), Vector3.new(area or 120, 1, area or 120))
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = seq(0.25, 0.25)
	e.Transparency = seq(0.1, 0.4)
	e.Lifetime = NumberRange.new(8, 10)
	e.Speed = NumberRange.new(4, 6)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(15, 15)
	e.Rate = 400
	e.Enabled = false
	e.Parent = p
	return e
end

-- Fire on top of a part (head on fire, burning car, torch). Uses the built-in Fire + Smoke.
-- A small invisible source part is welded on top of `part` inside a Model called `name`,
-- so the fire moves with an actor and CineCam.fx(name, on) can find it.
function FXKit.fire(name, part, size)
	local cast = workspace:FindFirstChild("Cast")
	local holderParent
	if cast and part:IsDescendantOf(cast) then
		holderParent = part.Parent
	else
		holderParent = fxFolder(name)
	end
	local holder = Instance.new("Model")
	holder.Name = name
	holder.Parent = holderParent
	local src = Instance.new("Part")
	src.Name = "FireSource"
	src.Size = Vector3.new(0.5, 0.5, 0.5)
	src.Transparency = 1
	src.CanCollide = false
	src.CanQuery = false
	src.CanTouch = false
	src.Massless = true
	src.CastShadow = false
	src.CFrame = part.CFrame * CFrame.new(0, part.Size.Y * 0.5, 0)
	src.Parent = holder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = src
	weld.Parent = src
	local fire = Instance.new("Fire")
	fire.Size = size or 6
	fire.Heat = 12
	fire.Enabled = false
	fire.Parent = src
	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = (size or 6) * 0.6
	smoke.Enabled = false
	smoke.Parent = src
	return holder
end

-- Night / day / mood presets for Lighting (call in Edit mode, or via CineCam.light during a shot)
FXKit.MOOD = {
	day = { ClockTime = 14, Brightness = 3, ExposureCompensation = 0, OutdoorAmbient = Color3.fromRGB(128, 128, 128) },
	goldenHour = { ClockTime = 17.6, Brightness = 2.5, ExposureCompensation = 0.1, OutdoorAmbient = Color3.fromRGB(150, 120, 100) },
	night = { ClockTime = 0, Brightness = 1, ExposureCompensation = 0.2, OutdoorAmbient = Color3.fromRGB(70, 70, 120) },
}

function FXKit.mood(name)
	local L = game:GetService("Lighting")
	for k, v in pairs(FXKit.MOOD[name] or {}) do
		L[k] = v
	end
end

-- Post-processing that gives the reference "realistic Roblox" look. Run once per place.
function FXKit.postFX()
	local L = game:GetService("Lighting")
	local function get(class)
		return L:FindFirstChildOfClass(class) or Instance.new(class, L)
	end
	local bloom = get("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.2
	local cc = get("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	local rays = get("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.8
	local dof = get("DepthOfFieldEffect")
	dof.FarIntensity = 0.35
	dof.FocusDistance = 12
	dof.InFocusRadius = 14
	dof.NearIntensity = 0
	local atm = get("Atmosphere")
	atm.Density = 0.3
	atm.Haze = 1.2
	atm.Glare = 0.4
end

return FXKit
