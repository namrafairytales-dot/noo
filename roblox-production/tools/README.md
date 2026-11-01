# tools · reference-video analysis pipeline

The scripts used to measure the reference videos. Run them again on any new reference video.

```bash
pip install opencv-python-headless numpy pillow rapidocr-onnxruntime wordfreq
```

Work in a scratch folder that holds `frames/<V>/`, `analysis/` and `sheets/` (V = a letter per video):

```bash
mkdir -p frames/A analysis sheets
```

```bash
ffmpeg -i video.mp4 -vsync 0 -q:v 3 frames/A/f%05d.jpg
```

```bash
python3 analyze.py frames/A analysis/A.json
```

```bash
python3 motion.py analysis/A.json analysis/A.motion.json
```

```bash
python3 captions.py frames/A analysis/A.captions.json
```

```bash
python3 clean_captions.py A
```

| Script | Output |
|---|---|
| `analyze.py` | shot cuts (HSV histogram + pixel difference) and per-frame zoom/pan/roll from LK optical flow + RANSAC |
| `motion.py` | per shot: zoom %, zoom profile (linear/ease/punch), pan, tilt, roll, shake, flash, and a move label |
| `captions.py` | one-word burned-in captions → words with start/end times (RapidOCR) |
| `clean_captions.py` | repairs words the OCR read upside-down (`pep` → `dad`), drops in-world sign text, applies hand fixes and removes double reads → `words_clean.json` |
| `sync.py` | words per shot, words per minute, how cuts line up with word onsets |
| `sheets.py`, `strip.py` | contact sheets (start/mid/end of each shot) and filmstrips used for the visual check |
| `make_tables.py`, `gallery.py` | the shot tables in `02–04` and the images in `reference-frames/` |
