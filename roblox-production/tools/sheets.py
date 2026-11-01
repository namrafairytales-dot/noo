"""Contact sheets: per shot START / MID / END frames + label + spoken words.
Usage: python3 sheets.py <video_letter>
"""
import sys, json, os
from PIL import Image, ImageDraw, ImageFont

v = sys.argv[1]
motion = json.load(open(f"analysis/{v}.motion.json"))
wp = f"analysis/{v}.words_clean.json"
words = json.load(open(wp)) if os.path.exists(wp) else []
TW, TH = 160, 284
CELL_W, LABEL_H = TW * 3, 50
COLS, ROWS = 3, 4
PER = COLS * ROWS
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    fontb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
except Exception:
    font = fontb = ImageFont.load_default()

def spoken(a, b):
    return " ".join(w["w"] for w in words if w["start"] < b and w["end"] > a)

os.makedirs(f"sheets/{v}", exist_ok=True)
for page in range((len(motion) + PER - 1) // PER):
    chunk = motion[page * PER:(page + 1) * PER]
    sheet = Image.new("RGB", (CELL_W * COLS, (TH + LABEL_H) * ROWS), (20, 20, 20))
    dr = ImageDraw.Draw(sheet)
    for k, s in enumerate(chunk):
        cx, cy = (k % COLS) * CELL_W, (k // COLS) * (TH + LABEL_H)
        a, b = s["start_f"], s["end_f"]
        picks = [a, (a + b) // 2, b]
        for j, fi in enumerate(picks):
            im = Image.open(f"frames/{v}/f{fi + 1:05d}.jpg").resize((TW, TH))
            sheet.paste(im, (cx + j * TW, cy + LABEL_H))
        dr.rectangle([cx, cy, cx + CELL_W - 1, cy + LABEL_H - 1], fill=(0, 0, 0))
        dr.text((cx + 4, cy + 2), f"#{s['shot']}  {s['start_t']:.2f}-{s['end_t']:.2f}s ({s['dur']:.2f}s)", fill=(255, 220, 80), font=fontb)
        lab = s.get("label", "")[:62]
        dr.text((cx + 4, cy + 18), lab, fill=(150, 220, 255), font=font)
        sp = spoken(s["start_t"], s["end_t"])[:66]
        dr.text((cx + 4, cy + 33), f"“{sp}”", fill=(255, 255, 255), font=font)
        dr.line([cx + CELL_W - 1, cy, cx + CELL_W - 1, cy + TH + LABEL_H], fill=(255, 80, 80), width=2)
    sheet.save(f"sheets/{v}/sheet_{page + 1:02d}.jpg", quality=85)
print(v, "pages:", (len(motion) + PER - 1) // PER)
