"""Extract burned-in one-word captions with timing.

1) cheap per-frame mask of white caption text in the caption band
2) change detection on the mask -> candidate segments
3) OCR one frame per segment (+ extra probes on long segments)
4) merge identical consecutive words -> word list with start/end time
Usage: python3 captions.py <frames_dir> <out_json>
"""
import sys, os, glob, json
import numpy as np
from PIL import Image
from rapidocr_onnxruntime import RapidOCR

frames_dir, out_json = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(frames_dir, "f*.jpg")))
FPS = 30.0
Y0, Y1, X0, X1 = 395, 475, 20, 340

masks = []
for f in files:
    a = np.asarray(Image.open(f).crop((X0, Y0, X1, Y1)).convert("RGB")).astype(np.int16)
    mn = a.min(axis=2)
    mx = a.max(axis=2)
    m = (mn > 205) & ((mx - mn) < 40)
    masks.append(m)

def score(a, b):
    u = np.logical_or(a, b).sum()
    if u < 30:
        return 0.0
    return np.logical_xor(a, b).sum() / u

changes = [0]
for i in range(1, len(masks)):
    s = score(masks[i - 1], masks[i])
    if s > 0.45 and i - changes[-1] >= 2:
        changes.append(i)
changes.append(len(masks))

ocr = RapidOCR()
cache = {}
def read(i):
    if i in cache:
        return cache[i]
    crop = np.asarray(Image.open(files[i]).crop((0, Y0, 360, Y1)).convert("RGB"))
    res, _ = ocr(crop)
    txt, conf = "", 0.0
    if res:
        # keep boxes whose center is near the horizontal middle (captions are centered)
        cand = []
        for box, t, c in res:
            xs = [p[0] for p in box]
            cx = (min(xs) + max(xs)) / 2
            cand.append((abs(cx - 180), t, float(c)))
        cand.sort()
        txt, conf = cand[0][1], cand[0][2]
    cache[i] = (txt.strip(), conf)
    return cache[i]

segs = []
for k in range(len(changes) - 1):
    a, b = changes[k], changes[k + 1] - 1
    L = b - a + 1
    probes = [a + L // 2]
    if L > 14:
        probes = [a + L // 4, a + L // 2, a + (3 * L) // 4]
    reads = [(p, read(p)) for p in probes]
    texts = [r[1][0] for r in reads]
    if len(set(texts)) == 1:
        segs.append({"a": a, "b": b, "w": texts[0], "c": max(r[1][1] for r in reads)})
    else:
        # refine: scan every 2nd frame in this segment
        last = None
        for p in range(a, b + 1, 2):
            t, c = read(p)
            if last is None or t != last["w"]:
                if last is not None:
                    last["b"] = p - 1
                    segs.append(last)
                last = {"a": p, "b": b, "w": t, "c": c}
        segs.append(last)

# merge consecutive identical words, drop empties
words = []
for s in segs:
    if words and s["w"] == words[-1]["w"]:
        words[-1]["b"] = s["b"]
        words[-1]["c"] = max(words[-1]["c"], s["c"])
    else:
        words.append(dict(s))
out = [{"w": w["w"], "start": round(w["a"] / FPS, 2), "end": round((w["b"] + 1) / FPS, 2),
        "conf": round(w["c"], 2)} for w in words if w["w"]]
json.dump(out, open(out_json, "w"), indent=0)
print(f"{frames_dir}: {len(changes)-1} mask segments, {len(cache)} OCR calls, {len(out)} words")
print(" ".join(w["w"] for w in out))
