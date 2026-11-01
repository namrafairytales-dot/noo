"""Writes analysis/<v>.words.json and analysis/<v>.words_clean.json.
Fix OCR words that were read upside-down (the OCR angle classifier sometimes
rotates short captions 180 deg: "dad" -> "pep", "nobody" -> "Apoqou") and drop
in-world sign text that leaked into the caption band.
Usage: python3 clean_captions.py <video_letter>
"""
import sys, json, itertools, re
from wordfreq import zipf_frequency

v = sys.argv[1]
words = json.load(open(f"analysis/{v}.captions.json"))

FLIP = {
    "p": ["d"], "d": ["p"], "b": ["q"], "q": ["b", "i"], "n": ["u"], "u": ["n", "r"],
    "a": ["e"], "e": ["a"], "m": ["w"], "w": ["m"], "M": ["w"], "W": ["m"],
    "y": ["h"], "h": ["y"], "A": ["y"], "4": ["h"], "!": ["i"], "i": ["l", "i"],
    "l": ["l", "i"], "I": ["l", "i"], "1": ["i", "l"], "3": ["t"], "6": ["g"], "g": ["b"],
    "0": ["o"], "o": ["o"], "O": ["o"], "s": ["s"], "S": ["s"], "t": ["t"], "k": ["k"],
    "x": ["x"], "z": ["z"], "c": ["c"], "r": ["r"], "P": ["d"], "D": ["p"], "N": ["u"],
    "U": ["n"], "E": ["a"], "Y": ["h"], "H": ["y"], "f": ["f"], "v": ["v"], "j": ["j"],
    ",": ["'"], ".": ["'"], "'": [","], "L": ["l"], "K": ["k"], "T": ["t"], "Z": ["z"],
}

def z(w):
    return zipf_frequency(w.lower().strip(".,!?'\""), "en")

def flips(w):
    rev = w[::-1]
    opts = [FLIP.get(ch, [ch.lower()]) for ch in rev]
    n = 1
    for o in opts:
        n *= len(o)
    if n > 512:
        return []
    return ["".join(c) for c in itertools.product(*opts)]

out = []
for x in words:
    w = x["w"].strip()
    # in-world sign text: long all-caps tokens or tokens with digits+letters mash
    if re.fullmatch(r"[A-Z0-9.*]{4,}", w) and w not in ("SKILLSTREAM",):
        continue
    if re.search(r"[A-Z]{2,}\d", w):
        continue
    base = z(w)
    best, bestz = w, base
    for c in flips(w):
        cz = z(c)
        if cz > bestz:
            best, bestz = c, cz
    if best != w and bestz >= 2.5 and bestz > base + 0.8:
        w2 = best
    else:
        w2 = w
    out.append({**x, "w": w2, "raw": x["w"]})

json.dump(out, open(f"analysis/{v}.words.json", "w"), indent=0)

# hand fixes seen in the reference videos + drop OCR double-reads of the same word
HAND = {"peoumop": "download", "peorumop": "download", "Aepsani": "tuesday", "Kepsant": "tuesday",
        "3.up!p": "didn't", "goest": "goes", "04": "to", "s,apec": "Cade's", "So!": "that", "SPI": "kids",
        "qufet": "quiet", "gir!": "girl", "skwith,": "with", ".Cade": "Cade", "Valler": "Valor",
        "Valour": "Valor", "there'": "there's", "Iron.": "Iron", "we're": "were", "619": "big"}
clean = []
for o in out:
    o = {**o, "w": HAND.get(o["w"], o["w"])}
    if clean and o["w"].lower() == clean[-1]["w"].lower() and o["start"] - clean[-1]["end"] < 0.25:
        clean[-1]["end"] = o["end"]
        continue
    clean.append(o)
json.dump(clean, open(f"analysis/{v}.words_clean.json", "w"), indent=0)
fixed = [(o["raw"], o["w"]) for o in out if o["raw"] != o["w"]]
print(f"{v}: {len(out)} words, fixed {len(fixed)}: {fixed}")
print(" ".join(o["w"] for o in out))
