"""Build the per-shot breakdown markdown + CSV for one video.
Usage: python3 make_tables.py <v> <title> <out_md> <out_csv>
"""
import sys, json, csv

v, title, out_md, out_csv = sys.argv[1:5]
motion = json.load(open(f"analysis/{v}.motion.json"))
words = json.load(open(f"analysis/{v}.words_clean.json"))
notes = {}
for line in open("analysis/notes.txt"):
    parts = line.rstrip("\n").split("|")
    if len(parts) == 5 and parts[0] == v:
        notes[int(parts[1])] = parts[2:]

def spoken(a, b):
    return " ".join(w["w"] for w in words if w["start"] < b - 0.02 and w["end"] > a + 0.02)

def esc(s):
    return s.replace("|", "/")

rows = []
for s in motion:
    n = s["shot"]
    cam, see, why = notes.get(n, ["?", "?", "?"])
    z = s.get("zoom_pct", 0.0)
    zs = f"{z:+.0f}%" if abs(z) >= 1.5 else "0"
    rows.append({
        "shot": n, "start": s["start_t"], "end": s["end_t"], "dur": s["dur"],
        "vo": spoken(s["start_t"], s["end_t"]), "camera": cam, "zoom": zs,
        "pan_x_pctW": s.get("pan_x_pctW", 0), "pan_y_pctH": s.get("pan_y_pctH", 0),
        "roll_deg": s.get("roll_deg", 0), "shake": s.get("shake", 0),
        "profile": s.get("zoom_profile", ""), "see": see, "why": why,
        "measured": s.get("label", ""),
    })

with open(out_csv, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

def mmss(t):
    return f"{int(t // 60)}:{t % 60:05.2f}"

lines = []
lines.append("| # | Time | Dur | VO on screen | Shot · angle · camera | Zoom | What we see (location · avatar · face · action · VFX) | Why |")
lines.append("|---|---|---|---|---|---|---|---|")
for r in rows:
    lines.append(f"| {r['shot']} | {mmss(r['start'])} | {r['dur']:.2f}s | {esc(r['vo'])} | {esc(r['camera'])} | {r['zoom']} | {esc(r['see'])} | {esc(r['why'])} |")
open(out_md, "w").write("\n".join(lines) + "\n")
print(out_md, len(rows))
