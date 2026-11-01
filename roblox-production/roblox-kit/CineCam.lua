--[[
CineCam  -  shot-list camera + action sequencer for vertical (9:16) Roblox story videos.

WHERE IT GOES
  ReplicatedStorage > CineCam            (ModuleScript, this file)
  ReplicatedStorage > Shots              (ModuleScript that returns the shot table, see Shots_Example.lua)
  StarterPlayer > StarterPlayerScripts > ShotRunner (LocalScript, see ShotRunner.client.lua)

SCENE CONVENTIONS (the production docs use these names)
  workspace.Cast   -> every actor Model (R6 / blocky rigs with a Humanoid), named "Hero", "Mom", ...
  workspace.Marks  -> invisible anchored Parts used as camera targets or walk targets
  workspace.FX     -> Folders of effects; each folder holds ParticleEmitters / Beams / Lights

WHY TIME-BASED
  Every camera value is computed from the time inside the shot, so the take is
  frame-accurate and identical every time you press Play. Record with OBS at 9:16.

SHOT FIELDS (all optional except dur)
  id       "S01"                 label printed to Output when the shot starts
  dur      1.4                   seconds (take it from the voiceover timing)
  subject  "Hero" | Instance | Vector3 | CFrame   what the camera frames
  size     "ECU" "CU" "MCU" "MS" "MWS" "WS" "EWS" or a number (studs of height that fill the frame)
  aim      number                studs above HumanoidRootPart to aim at (default per size)
  dist     number                force camera distance in studs (overrides size)
  yaw      degrees               0 = in front of the face, +35 = 3/4 from subject's RIGHT, 90 = profile, 180 = behind
  pitch    degrees               negative = camera low looking UP (hero/threat), positive = high looking DOWN
  roll     degrees               dutch tilt (sign picks the direction; 4-15 is typical)
  screenX  -0.5..0.5             where the subject sits horizontally (0 centre, -0.2 left, +0.2 right)
  screenY  -0.5..0.5             where the subject sits vertically (+ = higher in frame)
  fov      degrees               vertical field of view (default CineCam.BASE_FOV)
  move     "lock" "pushin" "pullout" "dollyin" "dollyout" "orbit" "pan" "tilt" "crane" "truck"
  amount   number                pushin/pullout/dolly: fraction (0.10 = 10%), orbit/pan/tilt: degrees, crane/truck: studs
                                 (orbit + = toward subject's right, pan + = right, tilt + = up, crane + = up, truck + = right)
  ease     "Linear" "Sine" "Quad" "Cubic" ...   (Enum.EasingStyle name)   default "Linear"
  easeDir  "In" "Out" "InOut"                                             default "InOut"
  follow   true                  re-read the subject position every frame (walking / flying subjects)
  shake    degrees               0 none, 0.15 handheld, 0.6 rumble, 1.5 impact
  shakeFreq hz                   default 6
  shakeDecay number              >0 makes the shake die out (impact), e.g. 6
  actions  { {at=0.0, fn=function() ... end}, ... }   timed events inside the shot (face swap, animation, VFX)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local CineCam = {}

CineCam.BASE_FOV = 70
CineCam.ASPECT = 9 / 16 -- width / height of the recorded frame

-- Vertical span in studs that fills the frame height (tuned for a ~5 stud tall avatar).
CineCam.SIZES = {
	ECU = 1.3, -- extreme close-up: face only (avoid in this channel: too close)
	CU = 2.2, -- close-up: head + shoulders (only for the biggest emotional beats)
	MCU = 3.0, -- medium close-up: head to chest
	MS = 4.0, -- medium: head to waist        <- default dialogue size
	MWS = 5.6, -- medium-wide: head to knees  <- default action size
	WS = 7.5, -- wide: full body with floor
	EWS = 28, -- establishing: location reads first, avatar small
}

-- Height above HumanoidRootPart to aim at, per size (keeps headroom right in 9:16).
CineCam.AIM = { ECU = 1.5, CU = 1.35, MCU = 1.1, MS = 0.75, MWS = 0.3, WS = -0.4, EWS = 0 }

-- Fill these with the face asset ids of YOUR style (classic 2D faces on a "face" Decal).
CineCam.FACES = {
	NEUTRAL = "",
	SMUG = "",
	HAPPY = "",
	GRIN = "",
	SHOCKED = "",
	SCARED = "",
	WORRIED = "",
	SAD = "",
	CRYING = "",
	ANGRY = "",
	DETERMINED = "",
	SMIRK = "",
	CONFUSED = "",
	EVIL = "",
	DEAD = "",
}

----------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------

local function folder(name)
	return workspace:FindFirstChild(name)
end

function CineCam.actor(name)
	if typeof(name) == "Instance" then
		return name
	end
	local cast = folder("Cast")
	local m = (cast and cast:FindFirstChild(name)) or workspace:FindFirstChild(name, true)
	if not m then
		warn("CineCam: actor not found: " .. tostring(name))
	end
	return m
end

local function resolve(subject)
	if typeof(subject) == "Vector3" then
		return subject, nil
	end
	if typeof(subject) == "CFrame" then
		return subject.Position, subject
	end
	if typeof(subject) == "string" then
		local marks = folder("Marks")
		local cast = folder("Cast")
		subject = (cast and cast:FindFirstChild(subject))
			or (marks and marks:FindFirstChild(subject))
			or workspace:FindFirstChild(subject, true)
	end
	if typeof(subject) == "Instance" then
		if subject:IsA("Model") then
			local root = subject:FindFirstChild("HumanoidRootPart")
				or subject.PrimaryPart
				or subject:FindFirstChildWhichIsA("BasePart", true)
			if root then
				return root.Position, root.CFrame
			end
		elseif subject:IsA("BasePart") then
			return subject.Position, subject.CFrame
		elseif subject:IsA("Attachment") then
			return subject.WorldPosition, subject.WorldCFrame
		end
	end
	error("CineCam: cannot resolve subject " .. tostring(subject))
end

local function eased(shot, alpha)
	local okStyle, style = pcall(function()
		return Enum.EasingStyle[shot.ease or "Linear"]
	end)
	local okDir, dir = pcall(function()
		return Enum.EasingDirection[shot.easeDir or "InOut"]
	end)
	if not okStyle then
		style = Enum.EasingStyle.Linear
	end
	if not okDir then
		dir = Enum.EasingDirection.InOut
	end
	return TweenService:GetValue(math.clamp(alpha, 0, 1), style, dir)
end

-- FOV that makes the picture `scale` times bigger than baseFov (pure zoom, no parallax).
local function zoomFov(baseFov, scale)
	local half = math.atan(math.tan(math.rad(baseFov) * 0.5) / scale)
	return math.deg(half * 2)
end

local function shakeCF(shot, t)
	local a = shot.shake or 0
	if a <= 0 then
		return CFrame.identity
	end
	local f = shot.shakeFreq or 6
	local k = 1
	if shot.shakeDecay then
		k = math.exp(-t * shot.shakeDecay)
	end
	local rx = math.noise(t * f + 0.31, 1.7, 0.5) * a * k
	local ry = math.noise(t * f + 0.73, 9.3, 0.5) * a * k
	local rz = math.noise(t * f + 0.11, 4.1, 0.5) * a * 0.5 * k
	return CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

----------------------------------------------------------------------------
-- camera solve for one frame of one shot
----------------------------------------------------------------------------

function CineCam.solve(shot, lt)
	local alpha = shot.dur > 0 and lt / shot.dur or 1
	local e = eased(shot, alpha)

	local rootPos, rootCF
	if shot.follow or not shot._rootPos then
		rootPos, rootCF = resolve(shot.subject or "Hero")
		if not shot.follow then
			shot._rootPos, shot._rootCF = rootPos, rootCF
		end
	else
		rootPos, rootCF = shot._rootPos, shot._rootCF
	end

	local size = shot.size or "MS"
	local span = typeof(size) == "number" and size or (CineCam.SIZES[size] or CineCam.SIZES.MS)
	local baseFov = shot.fov or CineCam.BASE_FOV
	local aimUp = shot.aim or (typeof(size) == "string" and CineCam.AIM[size]) or 0
	local aim = rootPos + Vector3.new(0, aimUp, 0)
	local dist = shot.dist or (span * 0.5) / math.tan(math.rad(baseFov) * 0.5)

	local move = shot.move or "lock"
	local amount = shot.amount or 0
	local yaw = shot.yaw or 0
	local pitch = shot.pitch or 0

	if move == "dollyin" then
		dist = dist / (1 + amount * e)
	elseif move == "dollyout" then
		dist = dist * (1 + amount * e)
	elseif move == "orbit" then
		yaw = yaw + amount * e
	end

	-- subject facing (yaw only)
	local look = rootCF and rootCF.LookVector or Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local facing = CFrame.lookAt(Vector3.zero, flat.Unit)
	-- yaw + = camera swings to the subject's right; pitch + = camera goes up
	local rot = facing * CFrame.Angles(0, -math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
	local camPos = aim + rot:VectorToWorldSpace(Vector3.new(0, 0, -dist))

	if move == "crane" then
		camPos = camPos + Vector3.new(0, amount * e, 0)
	end

	local base = CFrame.lookAt(camPos, aim)
	local frameH = 2 * dist * math.tan(math.rad(baseFov) * 0.5)
	local frameW = frameH * CineCam.ASPECT
	local lookPoint = aim
		- base.RightVector * ((shot.screenX or 0) * frameW)
		- base.UpVector * ((shot.screenY or 0) * frameH)

	if move == "truck" then
		local slide = base.RightVector * (amount * e)
		camPos = camPos + slide
		lookPoint = lookPoint + slide
	end

	local cf = CFrame.lookAt(camPos, lookPoint)
	if move == "pan" then
		cf = cf * CFrame.Angles(0, -math.rad(amount * e), 0)
	elseif move == "tilt" then
		cf = cf * CFrame.Angles(math.rad(amount * e), 0, 0)
	end
	cf = cf * CFrame.Angles(0, 0, -math.rad(shot.roll or 0)) * shakeCF(shot, lt)

	local fov = baseFov
	if move == "pushin" then
		fov = zoomFov(baseFov, 1 + amount * e)
	elseif move == "pullout" then
		fov = zoomFov(baseFov, 1 + amount * (1 - e))
	end
	return cf, fov
end

----------------------------------------------------------------------------
-- player / UI hiding for clean recording
----------------------------------------------------------------------------

function CineCam.hideUI()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)
end

function CineCam.hidePlayer()
	local lp = Players.LocalPlayer
	local char = lp and (lp.Character or lp.CharacterAdded:Wait())
	if not char then
		return
	end
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if root then
		root.Anchored = true
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

----------------------------------------------------------------------------
-- action helpers (use inside shot.actions)
----------------------------------------------------------------------------

-- Swap a classic 2D face. key = name in CineCam.FACES or a raw "rbxassetid://..." string.
function CineCam.face(actorName, key)
	local m = CineCam.actor(actorName)
	local head = m and m:FindFirstChild("Head")
	local decal = head and (head:FindFirstChild("face") or head:FindFirstChildWhichIsA("Decal"))
	local tex = CineCam.FACES[key] or key
	if decal and tex and tex ~= "" then
		decal.Texture = tex
	elseif not decal then
		warn("CineCam.face: no face Decal on " .. tostring(actorName) .. " (dynamic head? use your own face method)")
	end
end

-- Emote ids are read from the local player's Animate script, so they always match the
-- place's rig type (set Game Settings > Avatar to the same rig type as your actors).
local EMOTE_KEYS = { wave = true, point = true, cheer = true, laugh = true, dance = true, dance2 = true, dance3 = true }

local function emoteId(key)
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local animate = char and char:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(key)
	local a = holder and holder:FindFirstChildWhichIsA("Animation")
	return a and a.AnimationId
end

local tracks = {}

-- Play an animation on an actor. idOrKey = "rbxassetid://..." or an emote key (wave, point, cheer, laugh, dance...)
function CineCam.anim(actorName, idOrKey, speed, fade, looped)
	local m = CineCam.actor(actorName)
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local id = idOrKey
	if EMOTE_KEYS[idOrKey] then
		id = emoteId(idOrKey)
	end
	if not id then
		warn("CineCam.anim: no animation id for " .. tostring(idOrKey))
		return nil
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	local track = animator:LoadAnimation(a)
	if looped ~= nil then
		track.Looped = looped
	end
	track:Play(fade or 0.15, 1, speed or 1)
	tracks[m] = tracks[m] or {}
	table.insert(tracks[m], track)
	return track
end

function CineCam.stopAnims(actorName, fade)
	local m = CineCam.actor(actorName)
	for _, tr in ipairs((m and tracks[m]) or {}) do
		tr:Stop(fade or 0.15)
	end
	if m then
		tracks[m] = {}
	end
end

-- Walk an actor to a Mark / Vector3 (uses the Humanoid, so the walk animation plays if the rig has one).
function CineCam.walkTo(actorName, target, speed)
	local m = CineCam.actor(actorName)
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if speed then
		hum.WalkSpeed = speed
	end
	local pos = resolve(target)
	hum:MoveTo(pos)
end

-- Effects are found by name: workspace.FX[name] (static effects) and any Folder/Attachment/Model
-- called `name` inside workspace.Cast (effects that must move with an actor, e.g. an aura on Hero).
local function fxTargets(name)
	local list = {}
	local fxRoot = folder("FX")
	local f = fxRoot and fxRoot:FindFirstChild(name)
	if f then
		table.insert(list, f)
	end
	local cast = folder("Cast")
	if cast then
		for _, d in ipairs(cast:GetDescendants()) do
			if d.Name == name and (d:IsA("Folder") or d:IsA("Attachment") or d:IsA("Model")) then
				table.insert(list, d)
			end
		end
	end
	if #list == 0 then
		warn("CineCam: no effect called " .. tostring(name))
	end
	return list
end

local function isToggleable(d)
	return d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light")
		or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Highlight")
end

-- Turn every ParticleEmitter / Beam / Trail / Light / Fire / Smoke / Sparkles / Highlight of an effect on or off.
function CineCam.fx(name, on)
	for _, root in ipairs(fxTargets(name)) do
		for _, d in ipairs(root:GetDescendants()) do
			if isToggleable(d) then
				d.Enabled = on
			end
		end
		-- Neon/visual parts inside the effect folder appear/disappear too
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("FXVisible") ~= nil then
				d.Transparency = on and (d:GetAttribute("FXVisible") or 0) or 1
			end
		end
	end
end

-- One-shot burst from every ParticleEmitter of an effect.
function CineCam.burst(name, count)
	for _, root in ipairs(fxTargets(name)) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d:Emit(count or 30)
			end
		end
	end
end

-- Teleport / lay down an actor (e.g. fallen on the floor). Anchors the root so physics can't move it.
function CineCam.place(actorName, where, anchored)
	local m = CineCam.actor(actorName)
	if not m then
		return
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	if root and anchored ~= false then
		root.Anchored = true
	end
	local cf
	if typeof(where) == "CFrame" then
		cf = where
	else
		local pos, whereCF = resolve(where)
		cf = whereCF or CFrame.new(pos)
	end
	m:PivotTo(cf)
end

-- Fly / glide an actor (or any Model) to a CFrame over `time` seconds (flying hero, falling body, floating orb).
function CineCam.flyTo(actorName, targetCF, time, style, dir)
	local m = CineCam.actor(actorName)
	if not m then
		return
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	local v = Instance.new("CFrameValue")
	v.Value = m:GetPivot()
	local conn = v.Changed:Connect(function(cf)
		m:PivotTo(cf)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(time or 1,
		Enum.EasingStyle[style or "Sine"], Enum.EasingDirection[dir or "InOut"]), { Value = targetCF })
	tw.Completed:Connect(function()
		conn:Disconnect()
		v:Destroy()
	end)
	tw:Play()
	return tw
end

-- Procedural pose: rotate a Motor6D away from its rest C0 (works on top of playing animations).
-- R6 joints: "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck" (in Torso), "RootJoint" (in HumanoidRootPart)
-- R15 joints: "RightShoulder" (RightUpperArm), "LeftShoulder", "Neck" (Head), "Waist" (UpperTorso) ...
-- Angles are degrees; tune them by eye in Studio once per rig and save them as named poses.
local restC0 = {}
function CineCam.pose(actorName, jointName, rx, ry, rz, time)
	local m = CineCam.actor(actorName)
	if not m then
		return
	end
	local joint
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == jointName then
			joint = d
			break
		end
	end
	if not joint then
		warn("CineCam.pose: no joint " .. jointName .. " on " .. tostring(actorName))
		return
	end
	restC0[joint] = restC0[joint] or joint.C0
	local goal = restC0[joint] * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	TweenService:Create(joint, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = goal }):Play()
end

function CineCam.resetPose(actorName, time)
	local m = CineCam.actor(actorName)
	if not m then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") and restC0[d] then
			TweenService:Create(d, TweenInfo.new(time or 0.2), { C0 = restC0[d] }):Play()
		end
	end
end

-- Full-screen colour flash (white flash = power-up / transition, red = hit, black = blink).
local flashGui
function CineCam.flash(color, inTime, hold, outTime)
	local lp = Players.LocalPlayer
	if not flashGui then
		flashGui = Instance.new("ScreenGui")
		flashGui.Name = "CineFlash"
		flashGui.IgnoreGuiInset = true
		flashGui.DisplayOrder = 100
		flashGui.ResetOnSpawn = false
		local fr = Instance.new("Frame")
		fr.Name = "F"
		fr.Size = UDim2.fromScale(1, 1)
		fr.BorderSizePixel = 0
		fr.BackgroundTransparency = 1
		fr.Parent = flashGui
		flashGui.Parent = lp:WaitForChild("PlayerGui")
	end
	local fr = flashGui.F
	fr.BackgroundColor3 = color or Color3.new(1, 1, 1)
	local tIn = TweenService:Create(fr, TweenInfo.new(inTime or 0.06), { BackgroundTransparency = 0 })
	tIn:Play()
	task.delay((inTime or 0.06) + (hold or 0.04), function()
		TweenService:Create(fr, TweenInfo.new(outTime or 0.35), { BackgroundTransparency = 1 }):Play()
	end)
end

-- Tween any Lighting property for mood changes (e.g. night, power-up glow).
function CineCam.light(props, time)
	TweenService:Create(game:GetService("Lighting"), TweenInfo.new(time or 0.5), props):Play()
end

----------------------------------------------------------------------------
-- the sequencer
----------------------------------------------------------------------------

-- Plays the shot list once. Returns when the last shot ends.
-- opts.delay  : seconds to wait before shot 1 (start OBS, then count in)
-- opts.from   : start at this shot index (rehearse one part)
-- opts.loop   : true = repeat forever (for rehearsal)
function CineCam.play(shots, opts)
	opts = opts or {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	CineCam.hideUI()

	local first = opts.from or 1
	local t0 = 0
	for i = first, #shots do
		local s = shots[i]
		assert(type(s.dur) == "number" and s.dur > 0, "CineCam: shot " .. tostring(s.id or i) .. " needs dur > 0")
		s._t0 = t0
		s._rootPos, s._rootCF = nil, nil
		s._fired = {}
		t0 = t0 + s.dur
	end
	local total = t0

	local t = -(opts.delay or 0)
	local idx = first - 1
	local current = nil
	local finished = Instance.new("BindableEvent")

	RunService:BindToRenderStep("CineCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		t = t + dt
		if t < 0 then
			return
		end
		if t >= total then
			RunService:UnbindFromRenderStep("CineCam")
			finished:Fire()
			return
		end
		while idx < #shots and t >= shots[idx + 1]._t0 do
			idx = idx + 1
			current = shots[idx]
			current._rootPos, current._rootCF = nil, nil
			print(string.format("[CineCam] %s  t=%.2f", tostring(current.id or idx), t))
		end
		if not current then
			return
		end
		local lt = t - current._t0
		for i, act in ipairs(current.actions or {}) do
			if not current._fired[i] and lt >= (act.at or 0) then
				current._fired[i] = true
				task.spawn(act.fn)
			end
		end
		local cf, fov = CineCam.solve(current, lt)
		cam.CFrame = cf
		cam.FieldOfView = fov
	end)

	finished.Event:Wait()
	if opts.loop then
		return CineCam.play(shots, opts)
	end
end

return CineCam
