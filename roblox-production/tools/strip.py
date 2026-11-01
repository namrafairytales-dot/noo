"""Filmstrips: N evenly spaced frames per shot, one row per shot.
Usage: python3 strip.py <video> <out.jpg> <N> <shot> [<shot> ...]
"""
import sys, json
from PIL import Image, ImageDraw, ImageFont

v, out, N = sys.argv[1], sys.argv[2], int(sys.argv[3])
ids = [int(x) for x in sys.argv[4:]]
m = {s["shot"]: s for s in json.load(open(f"analysis/{v}.motion.json"))}
TW, TH, LH = 135, 240, 18
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
img = Image.new("RGB", (TW * N, (TH + LH) * len(ids)), (15, 15, 15))
dr = ImageDraw.Draw(img)
for r, sid in enumerate(ids):
    s = m[sid]
    a, b = s["start_f"], s["end_f"]
    y = r * (TH + LH)
    dr.text((4, y + 2), f"{v}#{sid} {s['start_t']:.2f}-{s['end_t']:.2f}s  {s['label'][:120]}", fill=(255, 220, 80), font=font)
    for k in range(N):
        fi = a + round(k * (b - a) / max(1, N - 1))
        im = Image.open(f"frames/{v}/f{fi + 1:05d}.jpg").resize((TW, TH))
        img.paste(im, (k * TW, y + LH))
img.save(out, quality=85)
print(out)
