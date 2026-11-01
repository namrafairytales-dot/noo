--[[
Shots  (ModuleScript)  ->  ReplicatedStorage > Shots

Example shot list in the reference grammar, but with the channel rule
"avatar a little farther from the camera" (MS / MWS / WS by default,
CU only on the one biggest emotional beat).

Each production doc ends with a table like this. Durations come from the
voiceover timing; the sum of dur = length of the audio.
]]

local CineCam = require(game:GetService("ReplicatedStorage"):WaitForChild("CineCam"))
local C = CineCam

return {
	-- HOOK: establishing shot, location reads first, hero small in frame, slow push
	{ id = "S01", dur = 1.6, subject = "Hero", size = "EWS", pitch = 12, yaw = 25,
		move = "pushin", amount = 0.10,
		actions = {
			{ at = 0.0, fn = function() C.face("Hero", "NEUTRAL") end },
		} },

	-- Premise line: medium-wide, low angle, slow constant push-in (the channel's default shot)
	{ id = "S02", dur = 1.3, subject = "Hero", size = "MWS", pitch = -8, yaw = 15,
		move = "pushin", amount = 0.10,
		actions = {
			{ at = 0.0, fn = function() C.face("Hero", "SMUG") end },
		} },

	-- Power moment: orbit 25 degrees around the hero while the orb flies in, white flash on contact
	{ id = "S03", dur = 2.2, subject = "Hero", size = "WS", pitch = -5, yaw = -20,
		move = "orbit", amount = 25, ease = "Sine",
		actions = {
			{ at = 0.0, fn = function() C.fx("PowerOrb", true) end },
			{ at = 0.0, fn = function() C.flyTo(workspace.FX.PowerOrb.Orb, workspace.Cast.Hero:GetPivot(), 1.1) end },
			{ at = 1.1, fn = function() C.flash(Color3.new(1, 1, 1), 0.05, 0.05, 0.4) end },
			{ at = 1.1, fn = function() C.fx("PowerOrb", false); C.fx("HeroAura", true) end },
			{ at = 1.1, fn = function() C.face("Hero", "SHOCKED") end },
		} },

	-- Reaction: the ONE close-up of the scene (still head + shoulders, never face-only)
	{ id = "S04", dur = 1.2, subject = "Hero", size = "MCU", pitch = -6, yaw = 10,
		move = "pushin", amount = 0.08,
		actions = {
			{ at = 0.0, fn = function() C.face("Hero", "HAPPY") end },
			{ at = 0.1, fn = function() C.anim("Hero", "cheer") end },
		} },

	-- Walk-and-talk: camera follows the hero walking toward camera (tracking back)
	{ id = "S05", dur = 2.0, subject = "Hero", size = "MWS", pitch = -4, yaw = 0, follow = true,
		move = "dollyout", amount = 0.05,
		actions = {
			{ at = 0.0, fn = function() C.walkTo("Hero", "WalkEnd", 10) end },
		} },

	-- Impact: landing with dust burst and decaying shake
	{ id = "S06", dur = 1.0, subject = "Hero", size = "WS", pitch = -12, yaw = 30,
		move = "pushin", amount = 0.12, shake = 1.5, shakeDecay = 6,
		actions = {
			{ at = 0.0, fn = function() C.burst("LandingDust", 60) end },
		} },

	-- ENDING: slow pull-out to wide (the references end on a zoom-out)
	{ id = "S07", dur = 2.1, subject = "Hero", size = "WS", pitch = 10, yaw = 0,
		move = "pullout", amount = 0.15,
		actions = {
			{ at = 0.0, fn = function() C.face("Hero", "SMIRK") end },
		} },
}
