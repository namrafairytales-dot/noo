"""Curated reference galleries (labelled frame grids) for the production docs.
Usage: python3 gallery.py <out_dir>
"""
import sys, json, os
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
M = {v: {s["shot"]: s for s in json.load(open(f"analysis/{v}.motion.json"))} for v in "ABC"}
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
FS = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)

def frame(v, shot, frac):
    s = M[v][shot]
    fi = s["start_f"] + round(frac * (s["end_f"] - s["start_f"]))
    return Image.open(f"frames/{v}/f{fi + 1:05d}.jpg")

def grid(name, items, cols=5, tw=216, th=384):
    rows = (len(items) + cols - 1) // cols
    lh = 38
    img = Image.new("RGB", (cols * tw, rows * (th + lh)), (18, 18, 18))
    d = ImageDraw.Draw(img)
    for k, (v, shot, frac, label) in enumerate(items):
        x, y = (k % cols) * tw, (k // cols) * (th + lh)
        img.paste(frame(v, shot, frac).resize((tw, th)), (x, y + lh))
        d.text((x + 4, y + 2), f"{v}#{shot}", fill=(255, 210, 70), font=F)
        d.text((x + 4, y + 20), label[:30], fill=(235, 235, 235), font=FS)
    img.save(os.path.join(out, name), quality=82)
    print(name, img.size)

def strips(name, items, n=6, tw=150, th=267):
    lh = 22
    img = Image.new("RGB", (n * tw, len(items) * (th + lh)), (18, 18, 18))
    d = ImageDraw.Draw(img)
    for r, (v, shot, label) in enumerate(items):
        s = M[v][shot]
        y = r * (th + lh)
        d.text((4, y + 3), f"{v}#{shot}  {label}  ({s['dur']:.1f}s, measured: {s['label'][:60]})", fill=(255, 210, 70), font=FS)
        for k in range(n):
            img.paste(frame(v, shot, k / (n - 1)).resize((tw, th)), (k * tw, y + lh))
    img.save(os.path.join(out, name), quality=80)
    print(name, img.size)

grid("locations.jpg", [
    ("A", 25, .5, "Night city street"), ("A", 4, .5, "Day plaza + crowd"), ("A", 17, .5, "Plaza funeral"),
    ("A", 23, .5, "Classroom (wide)"), ("A", 39, .5, "Kitchen (warm)"), ("A", 53, .5, "Living room + fireplace"),
    ("A", 34, .5, "Kid bedroom"), ("A", 65, .5, "Riverside road night"), ("A", 97, .9, "Back garden night"),
    ("A", 41, .5, "Fishing dock"), ("B", 26, .5, "Parking lot + sports cars"), ("B", 9, .5, "Suburb street"),
    ("B", 41, .5, "Cafeteria"), ("B", 28, .5, "Nurse office"), ("B", 15, .5, "School hallway"),
    ("B", 47, .5, "Gym winter dance"), ("B", 104, .6, "Snowy school exterior"), ("C", 1, .8, "Futuristic city"),
    ("C", 3, .9, "SkillStream store"), ("C", 8, .5, "Classroom (C)"), ("C", 38, .5, "Garage workshop"),
    ("C", 62, .5, "Night street crowd"), ("C", 88, .3, "Emergency stairwell"), ("C", 90, .5, "Broadcast machine room"),
    ("C", 117, .2, "Billboard golden hour"),
])
grid("vfx.jpg", [
    ("A", 1, .8, "Sparkle trail flight"), ("A", 2, .5, "Soul/power orb + smoke"), ("A", 3, .3, "White flash hit"),
    ("A", 3, .95, "Power aura"), ("A", 7, .7, "Fire hands"), ("A", 8, .6, "Take-off dust"),
    ("A", 10, .6, "Confetti"), ("A", 29, .6, "Glass cracks + shards"), ("A", 61, .4, "Shockwave ring"),
    ("A", 66, .8, "Water splash"), ("A", 78, .6, "Transformation burst"), ("A", 82, .5, "Windows shatter"),
    ("B", 1, .6, "Fire from head"), ("B", 5, .4, "Eye lasers"), ("B", 14, .5, "X-ray skeletons"),
    ("B", 49, .5, "Pink sparkles"), ("B", 60, .6, "Roof collapse white-out"), ("B", 80, .5, "Red power tint"),
    ("C", 3, .55, "Download glow"), ("C", 21, .8, "Electric board"), ("C", 71, .5, "Red chip glow"),
    ("C", 103, .9, "Generator sparks"), ("C", 91, .5, "Cyan machine rings"), ("C", 120, .5, "Spray-paint sparkle"),
    ("B", 22, .9, "Power-up glint"),
])
grid("faces.jpg", [
    ("A", 16, .5, "SMUG / sly"), ("A", 3, .05, "SHOCKED"), ("A", 13, .1, "WORRIED"), ("A", 13, .95, "SMUG smile"),
    ("A", 18, .5, "EXCITED"), ("A", 52, .5, "SAD"), ("A", 55, .5, "CRINGE"), ("A", 76, .2, "TERRIFIED"),
    ("A", 98, .5, "ANGRY"), ("A", 9, .5, "HAPPY"), ("B", 76, .5, "CRYING"), ("B", 100, .5, "X-EYES (out)"),
    ("B", 75, .9, "DETERMINED"), ("B", 86, .5, "SHOUTING"), ("B", 40, .7, "GRIN"), ("B", 43, .6, "SLY"),
    ("B", 44, .5, "SHOCKED O"), ("C", 3, .99, "HAPPY (after power)"), ("C", 43, .5, "FRUSTRATED"),
    ("C", 100, .5, "SMUG side-eye"), ("C", 59, .7, "FROZEN blank"), ("C", 109, .5, "CONFUSED"),
    ("C", 111, .5, "WORRIED villain"), ("C", 30, .6, "SMUG villain"), ("A", 107, .5, "Monster, sad pose"),
])
grid("framing-scale.jpg", [
    ("A", 26, .5, "ECU face (avoid)"), ("A", 13, .5, "CU (rare for us)"), ("A", 52, .5, "MCU"),
    ("A", 39, .5, "MS (ref) = our closest"), ("A", 17, .5, "WS = our default"), ("A", 1, .6, "EWS = establishing"),
    ("B", 1, .6, "ECU low angle (avoid)"), ("B", 29, .5, "MS"), ("B", 36, .5, "WS action"), ("C", 76, .5, "High-angle crowd WS"),
], cols=5)
strips("camera-moves.jpg", [
    ("A", 13, "PUSH-IN (the default, linear ~10%)"), ("A", 76, "CRASH ZOOM (68% in 0.5 s)"),
    ("A", 8, "TILT-FOLLOW a flyer"), ("A", 59, "DOLLY-BACK before a monster"), ("A", 31, "WHIP PAN"),
    ("C", 31, "ORBIT around the villain"), ("B", 101, "TOP-DOWN CRANE-UP (pull 45% + roll)"),
    ("B", 45, "FOLLOW FROM BEHIND"), ("B", 37, "DUTCH ANGLE (-26 deg) + push"), ("C", 120, "ENDING PULL-OUT"),
])
