# Roblox Story Video Production

Analysis of 3 reference videos (*Superpowers Transfer*, *Peanuts*, *Skill Downloads*) plus the format and tools for
making our own videos in the same style in Roblox Studio, with the avatar a little farther from the camera.

---

## Kya kiya gaya (Roman Urdu)

- Teeno videos ke **13,188 frames** (har ek frame) nikale. Code se **har frame par camera motion** naapa (zoom, pan, tilt,
  roll, shake) aur **334 shots** dhoondhe.
- Videos ke captions ko OCR se padh kar **poora script har word ke time ke saath** nikala.
- **Har shot** ke start, beech aur end frames khud dekh kar note kiya: location, avatar, chehra (expression), action, VFX,
  camera ka kaam, aur **kyun** (us line ke liye wo shot kyun hai).

**Sabse zaroori baatein:**
- Har **~1.3 second** par cut lagta hai, yaani 2.5 minute mein ~110 shots.
- **64 % shots mein camera dheere dheere zoom-in** karta hai (har shot mein ~10 %, ek hi speed se).
- Har 3 mein se 1 shot **chehre ke bahut paas** hai (CU/ECU). Hamare version mein camera door rahega: zyada tar
  **poora jism ya ghutnon tak**, close-up poori video mein sirf 1–3 baar.
- Voiceover bahut tez hai (**~240 words/min**), beech mein koi pause nahi, aur music poori video mein chalta hai.
- Captions **ek word ek baar**, screen ke beech mein (height ka 68 %), aur **82 % cuts bilkul kisi word ke shuru hone par** lagte hain.
- Har power moment par VFX, har clue ka alag insert shot, aur ending zoom-out ya locked shot par hoti hai.

**Agla step:** script aur audio bhejo (SRT/captions file bhi ho to timing aur exact hogi). Main uska poora production doc banaunga:
pehle locations, phir cast, VFX, har shot ka camera / emotion / movement / kyun, aur aakhir mein Roblox ke liye Lua shot table.

---

## Folder map

| Path | What it is |
|---|---|
| `01-style-bible.md` | **Start here.** The measured grammar of the references: camera, framing, cutting, avatars, locations, VFX, audio, and **our rules** |
| `02-shot-breakdown-A-superpowers-transfer.md` | Script, beat map and all 107 shots of A |
| `03-shot-breakdown-B-peanuts.md` | Script, beat map and all 107 shots of B |
| `04-shot-breakdown-C-skill-downloads.md` | Script, beat map and all 120 shots of C |
| `05-production-template.md` | The exact format of every production doc (location sheets, cast, VFX, per-shot blocks, dictionaries, Lua table, edit sheet) |
| `roblox-kit/` | Luau code: `CineCam` (shot-list camera + face/animation/VFX timing), `FXKit` (reference effects), example `Shots`, `ShotRunner` |
| `reference-frames/` | Labelled frame grids: locations, VFX, faces, framing scale, camera moves |
| `data/` | Per-shot CSV (timing, measured zoom/pan/roll/shake, words, notes) and caption word timings for each video |
| `tools/` | The Python analysis pipeline (shot detection, optical-flow camera motion, caption OCR) |

## Workflow

1. Owner sends **script + audio**.
2. A **production doc** is written in the `05` format: locations, cast, props, VFX, every shot, and the Lua `Shots` table.
3. The Studio AI reads `01-style-bible.md` and the production doc, then builds in this order:
   **locations (real Creator Store assets) → lighting → cast and faces → props → VFX → shot table → rehearse → record (OBS 1080×1920) → edit (VO, one-word captions, music, SFX)**.
