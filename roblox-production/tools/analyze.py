"""Shot detection + per-frame camera motion analysis.

For every frame pair we compute:
  - histogram distance (HSV) and mean abs pixel diff -> cut detection
  - global similarity transform (scale, rotation, tx, ty) from tracked
    features (LK optical flow + RANSAC) -> camera zoom / pan / roll
  - residual flow spread -> parallax (orbit / dolly with depth) vs pure zoom

Outputs JSON per video with per-frame metrics and a shot list.
Usage: python3 analyze.py <frames_dir> <out_json>
"""
import sys, os, json, glob
import numpy as np
import cv2

frames_dir, out_json = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(frames_dir, "f*.jpg")))
FPS = 30.0

def hsv_hist(img):
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    h = cv2.calcHist([hsv], [0, 1, 2], None, [16, 8, 8], [0, 180, 0, 256, 0, 256])
    cv2.normalize(h, h)
    return h

per = []
prev = prev_gray = prev_hist = None
lk = dict(winSize=(21, 21), maxLevel=3,
          criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 30, 0.01))

for i, f in enumerate(files):
    img = cv2.imread(f)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    hist = hsv_hist(img)
    rec = {"i": i, "t": round(i / FPS, 3), "bright": float(gray.mean())}
    if prev is not None:
        rec["hd"] = float(cv2.compareHist(prev_hist, hist, cv2.HISTCMP_BHATTACHARYYA))
        rec["pd"] = float(np.mean(cv2.absdiff(gray, prev_gray)))
        # feature tracking for global motion
        pts = cv2.goodFeaturesToTrack(prev_gray, maxCorners=400, qualityLevel=0.01,
                                      minDistance=8, blockSize=7)
        s = r = tx = ty = None
        resid = None
        n_in = 0
        if pts is not None and len(pts) >= 12:
            nxt, st, err = cv2.calcOpticalFlowPyrLK(prev_gray, gray, pts, None, **lk)
            good0 = pts[st.flatten() == 1].reshape(-1, 2)
            good1 = nxt[st.flatten() == 1].reshape(-1, 2)
            if len(good0) >= 12:
                M, inl = cv2.estimateAffinePartial2D(good0, good1, method=cv2.RANSAC,
                                                     ransacReprojThreshold=2.0)
                if M is not None:
                    a, b = M[0, 0], M[1, 0]
                    s = float(np.hypot(a, b))
                    r = float(np.degrees(np.arctan2(b, a)))
                    tx, ty = float(M[0, 2]), float(M[1, 2])
                    inl = inl.flatten().astype(bool)
                    n_in = int(inl.sum())
                    pred = (good0 @ M[:, :2].T) + M[:, 2]
                    res = np.linalg.norm(good1 - pred, axis=1)
                    resid = float(np.median(res))
                    rec["inlier_ratio"] = float(n_in / len(good0))
                    # flow magnitude stats
                    flow = good1 - good0
                    rec["flow_med"] = float(np.median(np.linalg.norm(flow, axis=1)))
        rec.update({"s": s, "rot": r, "tx": tx, "ty": ty, "resid": resid, "n": n_in})
    per.append(rec)
    prev, prev_gray, prev_hist = img, gray, hist

# ---- cut detection: adaptive threshold on histogram distance + pixel diff
hd = np.array([p.get("hd", 0.0) for p in per])
pd = np.array([p.get("pd", 0.0) for p in per])
cuts = [0]
for i in range(1, len(per)):
    win = hd[max(1, i - 15):i]
    base = np.median(win) if len(win) else 0
    is_cut = (hd[i] > 0.35 and hd[i] > base * 3 + 0.12) or (hd[i] > 0.22 and pd[i] > 28 and hd[i] > base * 4 + 0.08)
    if is_cut and i - cuts[-1] >= 4:
        cuts.append(i)

shots = []
for k, st in enumerate(cuts):
    en = (cuts[k + 1] - 1) if k + 1 < len(cuts) else len(per) - 1
    seg = per[st + 1:en + 1]
    def arr(key):
        return np.array([p[key] for p in seg if p.get(key) is not None], dtype=float)
    S, TX, TY, R, RES = arr("s"), arr("tx"), arr("ty"), arr("rot"), arr("resid")
    total_zoom = float(np.prod(S)) if len(S) else 1.0
    shots.append({
        "shot": k + 1, "start_f": st, "end_f": en,
        "start_t": round(st / FPS, 2), "end_t": round((en + 1) / FPS, 2),
        "dur": round((en - st + 1) / FPS, 2),
        "zoom_total": round(total_zoom, 3),           # >1 zoom in / push, <1 zoom out / pull
        "pan_x_total": round(float(TX.sum()), 1) if len(TX) else 0.0,   # px, + = content moves right (camera pans left)
        "pan_y_total": round(float(TY.sum()), 1) if len(TY) else 0.0,
        "roll_total": round(float(R.sum()), 2) if len(R) else 0.0,
        "resid_med": round(float(np.median(RES)), 3) if len(RES) else 0.0,
        "pd_mean": round(float(np.mean([p.get("pd", 0) for p in seg])), 2) if seg else 0.0,
        "shake": round(float(np.std(TX) + np.std(TY)), 2) if len(TX) > 2 else 0.0,
        "bright_mean": round(float(np.mean([p["bright"] for p in per[st:en + 1]])), 1),
    })

json.dump({"frames": len(per), "fps": FPS, "cuts": cuts, "shots": shots, "per": per},
          open(out_json, "w"))
print(f"{frames_dir}: {len(per)} frames, {len(shots)} shots")
for s in shots:
    print(f"#{s['shot']:3d} {s['start_t']:7.2f}-{s['end_t']:7.2f} ({s['dur']:5.2f}s) "
          f"zoom {s['zoom_total']:.3f} panX {s['pan_x_total']:7.1f} panY {s['pan_y_total']:7.1f} "
          f"roll {s['roll_total']:6.2f} resid {s['resid_med']:.2f} shake {s['shake']:.2f} pd {s['pd_mean']:.1f}")
