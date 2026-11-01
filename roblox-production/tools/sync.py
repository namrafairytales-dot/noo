"""Edit-rhythm analysis: how cuts line up with narration words.
Usage: python3 sync.py <video_letter>
Writes analysis/<v>.shots_words.json with words per shot and prints stats.
"""
import sys, json
import numpy as np

v = sys.argv[1]
m = json.load(open(f"analysis/{v}.motion.json"))
w = json.load(open(f"analysis/{v}.words_clean.json"))
starts = np.array([x["start"] for x in w])
dur_total = m[-1]["end_t"]
wpm = len(w) / (dur_total / 60)

offs = []
for s in m[1:]:
    t = s["start_t"]
    k = int(np.argmin(np.abs(starts - t)))
    offs.append(t - starts[k])
offs = np.array(offs)

rows = []
for s in m:
    ws = [x for x in w if x["start"] < s["end_t"] - 0.02 and x["end"] > s["start_t"] + 0.02]
    rows.append({"shot": s["shot"], "start": s["start_t"], "end": s["end_t"], "dur": s["dur"],
                 "words": " ".join(x["w"] for x in ws), "n_words": len(ws)})
json.dump(rows, open(f"analysis/{v}.shots_words.json", "w"), indent=1)
nw = np.array([r["n_words"] for r in rows])
print(f"{v}: {len(w)} words in {dur_total:.1f}s = {wpm:.0f} wpm; words/shot median {np.median(nw):.0f} mean {nw.mean():.1f}")
print(f"   cut - nearest word start: median {np.median(offs)*1000:.0f} ms, |off|<=100ms: {(np.abs(offs)<=0.1).mean()*100:.0f}%, "
      f"cut before word (off<0): {(offs<0).mean()*100:.0f}%")
