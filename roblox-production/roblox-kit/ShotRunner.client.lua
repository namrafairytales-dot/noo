--[[
ShotRunner  (LocalScript)  ->  StarterPlayer > StarterPlayerScripts > ShotRunner

Press Play (F5) in Studio. The script waits for the world to load, hides the
player + Roblox UI, counts in, then plays the whole shot list with CineCam.

Recording checklist (do this once per place):
  1. Workspace.StreamingEnabled = false          (whole set always loaded)
  2. Lighting.Technology = Future                 (set in the Properties panel)
  3. Test tab > Device > add a 1080 x 1920 portrait device and select it
     (or record landscape at 2160p and crop the centre 9:16; Roblox FOV is vertical,
      so the framing stays identical after the crop)
  4. Start OBS recording, then press Play. COUNT_IN gives you time to switch windows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CineCam = require(ReplicatedStorage:WaitForChild("CineCam"))
local shots = require(ReplicatedStorage:WaitForChild("Shots"))

local COUNT_IN = 3 -- seconds of clean frame before shot 1 (trim it in the editor)
local START_AT = 1 -- set to a shot index to rehearse from the middle
local LOOP = false -- true while rehearsing camera moves

task.wait(2) -- let actors, textures and effects load
CineCam.hidePlayer()
CineCam.play(shots, { delay = COUNT_IN, from = START_AT, loop = LOOP })
print("[ShotRunner] take finished")
