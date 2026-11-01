# roblox-kit · CineCam + FXKit

A small Luau kit so the Studio AI can play a production doc's shot list exactly: camera moves, face swaps,
animations and VFX, all timed to the voiceover.

| File | Put it in | What it does |
|---|---|---|
| `CineCam.lua` | ReplicatedStorage › **CineCam** (ModuleScript) | Shot-list camera: LOCK, PUSH-IN, PULL-OUT, SLOW ORBIT, DOLLY, CRANE, PAN, TILT, TRUCK, FOLLOW, DUTCH, SHAKE. Helpers: `face`, `anim`, `walkTo`, `place`, `flyTo`, `pose`, `fx`, `burst`, `flash`, `light` |
| `FXKit.lua` | ReplicatedStorage › **FXKit** (ModuleScript) | Builds the reference effects: `sparkles`, `dust`, `orb`, `aura`, `laser`, `snow`, `fire`, `mood`, `postFX` |
| `Shots_Example.lua` | ReplicatedStorage › **Shots** (ModuleScript) | Example shot table (each production doc ends with a real one) |
| `ShotRunner.client.lua` | StarterPlayer › StarterPlayerScripts › **ShotRunner** (LocalScript) | Press Play: hides the player and UI, counts in, plays the shots |

## Scene conventions
- `workspace.Cast`: actor Models (R6 / blocky, Humanoid, classic `face` Decal on the Head)
- `workspace.Marks`: invisible anchored Parts used as camera targets and walk targets
- `workspace.FX`: effect folders made by FXKit (all start disabled)

## Distance presets (vertical 9:16, FOV 70)
| `size` | Frame bottom at | Head height | Use |
|---|---|---|---|
| `EWS` | avatar small | ~4 % | first shot of a location |
| `WS` | feet + floor | ~15 % | default |
| `MWS` | knees | ~20 % | default |
| `MS` | waist | ~28 % | dialogue |
| `MCU` | chest | ~37 % | rare |
| `CU` | shoulders | ~50 % | max 3 per video |

## Setup once per place
1. Workspace › `StreamingEnabled = false` (the whole set stays loaded wherever the camera is)
2. Lighting › `Technology = Future` (Properties panel), then run `require(game.ReplicatedStorage.FXKit).postFX()` in the command bar
3. Game Settings › Avatar › rig type = the same as your actors (emote keys like `"wave"` and `"cheer"` are read from the player's Animate script)
4. Fill `CineCam.FACES` with the face asset ids of your style
5. Test › Device › a 1080×1920 portrait device, then OBS → Play

## Notes
- `CineCam.pose` angles depend on the rig. Tune them once by eye and save named poses.
- Animations must be owned by you or by Roblox, or they won't load.
- `walkTo` needs an unanchored HumanoidRootPart. `place` / `flyTo` anchor it, so call `place(actor, cf, false)` to release it again.
- Rehearse one part with `START_AT` and `LOOP = true` in ShotRunner.
