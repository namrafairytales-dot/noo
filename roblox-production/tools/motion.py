"""Turn per-frame similarity transforms into per-shot camera-move labels.

p = t - (I - sR)c  -> pan of the image about the frame centre (px/frame)
Per shot we report: total zoom %, zoom profile (linear / ease / punch),
pan x/y in % of frame, roll, shake, flash, and a move label.
Usage: python3 motion.py <analysis.json> <out.json>
"""
import sys, json, math
import numpy as np

d = json.load(open(sys.argv[1]))
per, shots, FPS = d["per"], d["shots"], d["fps"]
W, H = 360.0, 640.0
c = np.array([W / 2, H / 2])

def frame_motion(p):
    if p.get("s") is None:
        return None
    s, r = p["s"], math.radians(p["rot"])
    R = np.array([[math.cos(r), -math.sin(r)], [math.sin(r), math.cos(r)]])
    t = np.array([p["tx"], p["ty"]])
    pan = t - (np.eye(2) - s * R) @ c
    return s, p["rot"], pan[0], pan[1], p.get("resid") or 0.0, p.get("inlier_ratio", 0)

out = []
for sh in shots:
    a, b = sh["start_f"], sh["end_f"]
    rows = [frame_motion(per[i]) for i in range(a + 1, b + 1)]
    rows = [r for r in rows if r is not None]
    n = b - a + 1
    if len(rows) < 2:
        out.append({**sh, "label": "too short", "frames": n})
        continue
    S = np.array([r[0] for r in rows]); ROT = np.array([r[1] for r in rows])
    PX = np.array([r[2] for r in rows]); PY = np.array([r[3] for r in rows])
    RES = np.array([r[4] for r in rows]); INL = np.array([r[5] for r in rows])
    # robust: ignore frames with crazy estimates (cuts inside / transitions)
    ok = (np.abs(np.log(S)) < 0.25) & (np.abs(PX) < 80) & (np.abs(PY) < 120)
    S2, R2, PX2, PY2 = S[ok], ROT[ok], PX[ok], PY[ok]
    zoom = float(np.prod(S2)) if len(S2) else 1.0
    logz = np.log(S2) if len(S2) else np.array([0.0])
    # zoom profile
    prof = "none"
    if abs(zoom - 1) > 0.02 and len(logz) >= 6:
        k = max(1, len(logz) // 3)
        r1, r2, r3 = logz[:k].mean(), logz[k:2 * k].mean(), logz[2 * k:].mean()
        mx = np.max(np.abs(logz))
        if mx > 6 * (abs(np.mean(logz)) + 1e-6) and mx > 0.03:
            prof = "punch"
        elif abs(r2) > 1.4 * max(abs(r1), abs(r3)):
            prof = "ease-in-out"
        elif abs(r1) > 1.5 * abs(r3):
            prof = "ease-out (fast start, slows)"
        elif abs(r3) > 1.5 * abs(r1):
            prof = "ease-in (slow start, speeds up)"
        else:
            prof = "linear/constant"
    panx = float(PX2.sum()) if len(PX2) else 0.0
    pany = float(PY2.sum()) if len(PY2) else 0.0
    roll = float(R2.sum()) if len(R2) else 0.0
    shake = float(np.std(np.diff(PX2)) + np.std(np.diff(PY2))) if len(PX2) > 3 else 0.0
    bright = [per[i]["bright"] for i in range(a, b + 1)]
    flash = max(bright) - np.median(bright) > 40
    resid = float(np.median(RES))
    inl = float(np.median(INL))
    bad = int((~ok).sum())
    # label
    lab = []
    zp = (zoom - 1) * 100
    px_pct, py_pct = panx / W * 100, pany / H * 100
    if zp > 1.5:
        lab.append(f"ZOOM-IN {zp:.0f}%")
    elif zp < -1.5:
        lab.append(f"ZOOM-OUT {abs(zp):.0f}%")
    if abs(px_pct) > 6:
        lab.append(f"PAN {'content→right (cam left)' if panx > 0 else 'content→left (cam right)'} {abs(px_pct):.0f}%W")
    if abs(py_pct) > 5:
        lab.append(f"TILT {'content↓ (cam up)' if pany > 0 else 'content↑ (cam down)'} {abs(py_pct):.0f}%H")
    if abs(roll) > 2.5:
        lab.append(f"ROLL {roll:+.0f}°")
    if resid > 1.2 and inl < 0.6:
        lab.append("PARALLAX/3D-move or subject motion")
    if shake > 2.5:
        lab.append(f"SHAKE {shake:.1f}")
    if flash:
        lab.append("FLASH")
    if bad > 0:
        lab.append(f"({bad} wild frames)")
    if not lab:
        lab = ["LOCKED/STATIC"]
    out.append({**sh, "frames": n, "zoom_pct": round(zp, 1), "zoom_profile": prof,
                "zoom_rate_pct_per_s": round(zp / max(sh["dur"], 0.01), 1),
                "pan_x_pctW": round(px_pct, 1), "pan_y_pctH": round(py_pct, 1),
                "roll_deg": round(roll, 1), "shake": round(shake, 2), "flash": bool(flash),
                "resid": round(resid, 2), "inlier": round(inl, 2), "wild": bad,
                "label": " + ".join(lab)})

json.dump(out, open(sys.argv[2], "w"), indent=1)
for s in out:
    print(f"#{s['shot']:3d} {s['start_t']:7.2f}-{s['end_t']:7.2f} {s['dur']:5.2f}s  {s['label']}"
          + (f"  [{s.get('zoom_profile')}]" if s.get('zoom_profile') not in (None, 'none') else ""))
