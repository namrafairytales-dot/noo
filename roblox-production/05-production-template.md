# 05 · Production Template (the format of every production doc)

When the owner sends a **script + audio**, the production doc is written in exactly this format and handed to the
Studio AI. The Studio AI builds in this order: **locations → lighting → cast → props → VFX → shot table → rehearse → record → edit.**

---

## 0. How the timing is made (done by me, before the doc)

1. Get word timestamps from the audio. If the audio has an SRT or captions export, use that; otherwise align the script against the audio.
2. Group the words into shots of **about 5 words** at natural phrase breaks. A shot never starts in the middle of a word.
3. Each **cut lands on the onset of the shot's first word** (as in 82 % of the reference cuts).
4. The shot `dur` values add up exactly to the audio length, so the recorded take lines up with the voiceover.
5. Target: average 1.4–1.6 s per shot. Establishing shots 1.5–2.5 s, micro-cuts 0.3–0.4 s, last 15 s slower (2–2.5 s).

---

## 1. Header

```
TITLE:            <video title>
VO FILE:          <name>.mp3   length <m:ss.ss>
FORMAT:           9:16 vertical, 1080x1920, 30 fps (record 60 if possible), Roblox Studio + OBS
SHOTS:            <n>   average <x.xx> s
LOCATIONS:        L01 … Lnn
CAST:             C01 … Cnn
DISTANCE RULE:    default WS/MWS (head 12–22 % of frame height), MS for dialogue, CU max 3, no face ECU
```

---

## 2. Location build sheet (one per location, BUILD THESE FIRST)

```
## L03 · Downtown Plaza (day)
STORY USE:        shots S004–S012 (examples of the rule)
LOOK:             realistic modern downtown: blue glass towers + tan-brick mid-rises, wide paved plaza with tile lines,
                  palm trees, benches, street lamps, traffic lights, parked sedans, a bus stop
REAL ROBLOX ITEMS (Creator Store / Toolbox search words):
                  "modern skyscraper", "glass office building", "brick apartment building", "city plaza",
                  "palm tree", "street lamp", "park bench", "traffic light", "sedan car", "bus stop"
SCALE:            avatar 5 studs · door 8 tall × 4 wide · storey 14 studs · road lane 12 studs · car ≈ 16 × 7 studs
DENSITY:          no empty background in any camera direction we use; fill to 150 studs deep behind the subject
LIGHTING:         FXKit.mood("day") · FXKit.postFX() · realistic cloud skybox · Atmosphere density 0.3
MARKS (anchored invisible parts in workspace.Marks):
                  L03_Establish (high corner), L03_Center, L03_RunStart, L03_RunEnd, L03_Reverse
CROWD:            25 NPC avatars walking (varied outfits)
REFERENCE:        reference-frames/locations.jpg → A#4, A#5
```

**Realism rules for every set**
- Use **real assets from the Creator Store**: buildings, cars, furniture, food and street props. No bare baseplates or placeholder grey blocks.
- **Delete every Script/LocalScript inside inserted free models** (free models can contain harmful or laggy scripts).
- True scale relative to a 5-stud avatar. A wide shot shows a lot of set, so dress at least 3 directions.
- Every interior gets windows with a sky or street visible outside, practical lights (lamps, ceiling lights) and clutter that suits the story.
- Give each location at least 3 marks: an establishing view, eye-level coverage and a reverse angle.

---

## 3. Cast sheet

```
## C01 · Narrator (channel mascot — same look every video)
LOOK:     orange messy hair, cream knit sweater, brown pants  (scene variant: blue knit sweater)
RIG:      R6 blocky (or R15 blocky body), classic face decal
FACES:    NEUTRAL, SMUG, SHOCKED, WORRIED, SAD, HAPPY, DETERMINED, SCARED, CRYING
MARK:     workspace.Cast.Narrator
```
Each character = one silhouette + one main colour so it reads instantly on a phone.

---

## 4. Props and text props

```
P01  "VALOR-O's" cereal box  — custom decal with the hero's picture   (insert S011)
P02  TV with news lower-third — SurfaceGui: "BREAKING NEWS · …"         (S049, S058)
P03  Phone screen "DAD · Voicemail 0:03" — SurfaceGui                   (S096)
```
Each **planted clue** gets two inserts: one when it is planted and one when it pays off.

---

## 5. VFX list (build with roblox-kit/FXKit.lua, all start disabled)

```
FX01  PowerOrb     FX.orb("PowerOrb", Marks.OrbStart.Position, Color3.fromRGB(255,235,140))   S002–S003
FX02  LandingDust  FX.dust("LandingDust", Marks.Landing.Position)                               S001
FX03  HeroAura     FX.aura("HeroAura", Cast.Hero, Color3.fromRGB(255,160,60))                   S003
```

---

## 6. Shot list: one block per shot

```
### S012 · 0:14.40 → 0:16.10 · 1.70 s
VO:         "and a superhero day — goes… not who they say"
LOCATION:   L03 Downtown Plaza · mark L03_Center · (first time here? no)
SIZE:       MWS — knees up, head ≈ 20 % of frame height, subject centred, eyes on the upper third
ANGLE:      low (pitch −8°), 3/4 from subject's right (yaw +25°), dutch 0°
CAMERA:     PUSH-IN 9 %, linear                 → CineCam {size="MWS", pitch=-8, yaw=25, move="pushin", amount=0.09}
AVATAR:     C04 Tank — EMOTION worried → smug (face swap at 0.90 s on "not")
MOVEMENT:   idle → crosses arms at 0.90 s
VFX/LIGHT:  —
SFX:        soft whoosh on the cut
CUT IN:     hard cut on "and"
WHY:        the line turns inside the shot, so the face turns with it (reference A#13 does the same, but in CU; we stay MWS)
```

**Fields are always the same:** VO, LOCATION, SIZE, ANGLE, CAMERA (exactly one move + numbers + CineCam mapping),
AVATAR (emotion and face swaps with times), MOVEMENT (animation/pose/walk), VFX/LIGHT, SFX, CUT IN, WHY.

---

## 7. Dictionaries the shot list uses

### 7.1 Distance (size) rule

| Size | Frame bottom cuts at | Head height | CineCam `size` | Our use |
|---|---|---|---|---|
| EWS | avatar small in the set | ~4 % | `"EWS"` | first shot in every new location |
| WS | below the feet (floor visible) | ~15 % | `"WS"` | **default** action and establishing |
| MWS | knees | ~20 % | `"MWS"` | **default** character shot |
| MS | waist | ~28 % | `"MS"` | dialogue and reactions |
| MCU | chest | ~37 % | `"MCU"` | rare, quiet emotional lines |
| CU | shoulders | ~50 % | `"CU"` | max 3 per video, biggest beats only |
| ECU | face only | 85 %+ | — | **never on faces** (object inserts only) |

### 7.2 Camera moves (amounts measured from the references)

| Move | When | Amount / time | CineCam |
|---|---|---|---|
| **LOCK** | deadpan joke, micro-cut, final quiet beat | — | `move="lock"` |
| **PUSH-IN** (zoom in) | default for every shot | WS 5–8 %, MWS 8–10 %, MS 10–12 %, linear | `move="pushin", amount=0.08` |
| **PULL-OUT** (zoom out) | realisation, ending, "the world is bigger" | 10–20 % over 1.5–2.5 s, Sine | `move="pullout", amount=0.15, ease="Sine"` |
| **SLOW ORBIT** | reveal, power-up, villain status, memorial | 15–30° over 2–4 s, Sine InOut | `move="orbit", amount=25, ease="Sine"` |
| **MOVE · FOLLOW** | walking/running/flying subject | camera keeps its offset | `follow=true` (+ any move) |
| **MOVE · DOLLY** | approach / retreat with parallax (monster charge) | 5–15 % | `move="dollyin"` / `"dollyout"` |
| **MOVE · CRANE** | rise to top-down at an ending, reveal over a wall | 3–10 studs | `move="crane", amount=6` |
| **MOVE · PAN / TILT** | follow a fast object from a fixed spot (flyer, orb) | 10–60° | `move="pan"` / `"tilt"` |
| **MOVE · TRUCK** | slide sideways past foreground | 2–6 studs | `move="truck", amount=4` |
| **CRASH ZOOM** | 3–5 biggest shocks per video | 30–70 % in 0.3–0.6 s | `move="pushin", amount=0.5, ease="Quad", easeDir="In"` |
| + DUTCH | tension, chaos, panic (not calm shots) | 4–15° | `roll=8` |
| + SHAKE | impact, footsteps, collapse | 0.6–1.5°, decaying | `shake=1.2, shakeDecay=6` |

### 7.3 Emotion → face → body → camera

| Beat | Face key | Body / animation | Camera tendency |
|---|---|---|---|
| Flex / premise / scheming | SMUG, SMIRK | hands on hips, arms crossed | low angle, push-in |
| Shock | SHOCKED | arms up, step back | crash zoom (rare) or push-in |
| Worry | WORRIED | hand to head, look down | slight high angle |
| Sadness | SAD | head down, slump | high angle, slow push, MS |
| Joy | HAPPY, GRIN | `cheer`, jump | push-in |
| Anger / fight | ANGRY | fists up, fighting stance | low angle, small dutch |
| Fear | SCARED | back away | dutch + small shake |
| Resolve | DETERMINED | step forward, look up | low angle push |
| Grief | CRYING | kneel, hug | MS, slow push or lock |
| Out cold / dead | DEAD (X-eyes) | lying on the floor (`CineCam.place`) | top-down crane-up + pull-out |
| Confused | CONFUSED | look left/right | lock or small push |

---

## 8. Lua shot table (last section of every production doc)

The shot list is repeated as a `Shots` ModuleScript for `roblox-kit/CineCam.lua`, so the camera, faces, animations and VFX
fire exactly on time:

```lua
local C = require(game.ReplicatedStorage.CineCam)
return {
  { id="S012", dur=1.70, subject="Tank", size="MWS", pitch=-8, yaw=25, move="pushin", amount=0.09,
    actions = {
      { at=0.00, fn=function() C.face("Tank","WORRIED") end },
      { at=0.90, fn=function() C.face("Tank","SMUG"); C.pose("Tank","Right Shoulder",0,0,-40) end },
    } },
  -- …
}
```

---

## 9. Edit sheet

- **Timeline:** drop the OBS take, trim the count-in, then put the VO at 0:00 so shot 1 starts on the first word.
- **Captions:** one word at a time, lowercase, bold rounded sans (white, thin black outline, soft shadow), centred at 68 %
  of the frame height, each word on its onset.
- **Music:** one bed for the whole video, about 18–20 dB under the voice, no gaps.
- **SFX:** whoosh on whips and transitions, boom on crash zooms and impacts, a glass sound on shatters, a sparkle sound on power-ups.
- **Export:** 1080×1920, 30 fps, H.264, high bitrate.

---

## 10. Example: the first 6 reference shots of A, redone with our rules

| Ref | Reference did | Our version |
|---|---|---|
| A#1 | sky tilt-down to hero landing, ends close | **EWS** from the night sky, TILT-follow the diving hero down to a **WS** landing with dust + shake; hero stays full-body |
| A#2 | MWS collapse, orb rises (tilt up) | **WS** collapse, orb rises; tilt up only 30° so the plaza stays in frame |
| A#3 | MS/MCU low, shocked face fills frame | **MWS** low angle; SLOW ORBIT 20° while the orb hits; white flash; face swap shocked → happy |
| A#4 | high-angle crowd, drone pull | same idea: **EWS** high angle, PULL-OUT 10 % over 1.6 s (crowd = "most people") |
| A#5 | low WS suits + flyer | **WS** low angle, PUSH-IN 6 %, flyer crosses the sky with a sparkle trail |
| A#7 | MCU fire hands | **MWS** fire hands, PUSH-IN 9 %, fire VFX big enough to read at that distance |
