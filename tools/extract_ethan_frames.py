#!/usr/bin/env python3
"""Cut Ethan's animation frames out of the 'FRAMES- Ethans Core Movements 2' sheet
(plus balance/crouch poses from sheet 3) into res://assets/characters/ethan/<anim>_NN.png.

Every frame is placed on one shared canvas with the board's ground-contact point at the
bottom-centre pixel, so the Godot sprite origin (feet) is consistent across animations.
Usage: python3 tools/extract_ethan_frames.py [--preview contact.png]
Requires: pillow numpy scipy
"""
import argparse, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/source_sheets")
OUT = os.path.join(ROOT, "assets/characters/ethan")
SHEET2 = os.path.join(SRC, "FRAMES- Ethans Core Movements 2.png")
SHEET3 = os.path.join(SRC, "FRAMES- Ethans Core Movements 3.png")
KICKPUSH = os.path.join(SRC, "Elements - Kick Push.png")
GRINDING = os.path.join(SRC, "Elements - Grinding.png")

ROW_EDGES = [0, 190, 375, 548, 703, 860, 1024]
SPLIT_X = [535, 758, 758, 758, 758, 548]
# animation -> (row, side, frame indices (0-based) or None for all)
SHEET2_MAP = {
    "idle": (0, "L", None), "push": (0, "R", None),
    "cruise": (1, "L", None), "speed": (1, "R", None),
    "brake": (2, "L", None), "drift": (2, "R", None),
    "ollie": (3, "L", None),
    "landing": (5, "L", None),
}

def load_components(path, min_area=1500):
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3] > 24
    lab, n = ndi.label(alpha, structure=np.ones((3, 3)))
    comps = []
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        mask = lab[sl] == i
        area = int(mask.sum())
        if area < min_area:
            continue
        h, w = mask.shape
        if w / h > 8 or h / w > 8:      # divider lines
            continue
        px = arr[sl][mask]
        yellow = ((px[:, 0] > 200) & (px[:, 1] > 170) & (px[:, 2] < 90)).mean()
        if yellow > 0.12:               # yellow brush label
            continue
        comps.append({"box": (sl[1].start, sl[0].start, sl[1].stop, sl[0].stop), "lab": lab, "id": i, "area": area})
    return im, lab, comps

def merge_frames(comps, gap_x=14):
    """Merge comps (board/dust/body fragments) that overlap horizontally into one frame."""
    comps = sorted(comps, key=lambda c: c["box"][0])
    groups = []
    for c in comps:
        for g in groups:
            if c["box"][0] <= g["x1"] + gap_x and c["box"][2] >= g["x0"] - gap_x and \
               (c["box"][0] < g["x1"] - 0.4 * (g["x1"] - g["x0"]) or c["box"][2] < g["x1"] + gap_x):
                if min(c["box"][2], g["x1"]) - max(c["box"][0], g["x0"]) > 0.35 * min(c["box"][2] - c["box"][0], g["x1"] - g["x0"]):
                    g["ids"].append(c["id"]); g["x0"] = min(g["x0"], c["box"][0]); g["x1"] = max(g["x1"], c["box"][2]); break
        else:
            groups.append({"ids": [c["id"]], "x0": c["box"][0], "x1": c["box"][2]})
    return groups

def frame_image(im, lab, ids):
    arr = np.array(im)
    mask = np.isin(lab, ids)
    ys, xs = np.where(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = arr[y0:y1, x0:x1].copy()
    out[~mask[y0:y1, x0:x1]] = 0
    # anchor: x-centre of the lowest ~10px of opaque pixels (the board), y = lowest pixel
    bottom = np.where(out[:, :, 3] > 24)
    low = bottom[0].max()
    sel = bottom[1][bottom[0] > low - 10]
    anchor_x = int((sel.min() + sel.max()) / 2)
    return Image.fromarray(out), anchor_x

def sheet_frames(path, rows_filter=None):
    im, lab, comps = load_components(path)
    return im, lab, comps

def kick_push_frames():
    """Two rows of 8 clean figures: standard (top) and fast/aggressive (bottom)."""
    im, lab, comps = load_components(KICKPUSH)
    figs = [c for c in comps if (c["box"][3] - c["box"][1]) > 180]   # drops the label banners
    top = sorted([c for c in figs if (c["box"][1] + c["box"][3]) / 2 < 500], key=lambda c: c["box"][0])
    bot = sorted([c for c in figs if (c["box"][1] + c["box"][3]) / 2 >= 500], key=lambda c: c["box"][0])
    return ([frame_image(im, lab, [c["id"]]) for c in top], [frame_image(im, lab, [c["id"]]) for c in bot])

def grind_frames(row=0):
    """Rail row: cut the rail away (the game draws its own) so feet sit on the rail line."""
    im = Image.open(GRINDING).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3] > 24
    lab, n = ndi.label(alpha, structure=np.ones((3, 3)))
    objs = [sl for sl in ndi.find_objects(lab) if (sl[1].stop - sl[1].start) > 800]
    objs.sort(key=lambda sl: sl[0].start)
    sl = objs[row]
    x0, x1, y0, y1 = sl[1].start, sl[1].stop, sl[0].start, sl[0].stop
    region = alpha[y0:y1, x0:x1]
    cover = region.sum(axis=1) / region.shape[1]
    y_cut = y0 + int(np.argmax(cover > 0.8))       # first row where the rail/ledge spans (nearly) the full width
    keep = np.zeros_like(alpha)
    keep[y0:y_cut, x0:x1] = alpha[y0:y_cut, x0:x1]
    arr2 = arr.copy()
    arr2[~keep] = 0
    im2 = Image.fromarray(arr2)
    lab2, n2 = ndi.label(keep, structure=np.ones((3, 3)))
    figs = []
    for i, s2 in enumerate(ndi.find_objects(lab2), 1):
        if int((lab2[s2] == i).sum()) > 4000:
            figs.append((s2[1].start, i))
    figs.sort()
    return [frame_image(im2, lab2, [i]) for _, i in figs]

def collect():
    frames = {}
    im, lab, comps = load_components(SHEET2)
    buckets = {}
    for c in comps:
        cy = (c["box"][1] + c["box"][3]) / 2
        cx = (c["box"][0] + c["box"][2]) / 2
        row = next(i for i in range(6) if ROW_EDGES[i] <= cy < ROW_EDGES[i + 1])
        side = "L" if cx < SPLIT_X[row] else "R"
        buckets.setdefault((row, side), []).append(c)
    for anim, (row, side, idx) in SHEET2_MAP.items():
        groups = merge_frames(buckets.get((row, side), []))
        groups = [g for g in groups if g["x1"] - g["x0"] > 40]
        imgs = [frame_image(im, lab, g["ids"]) for g in groups]
        frames[anim] = imgs if idx is None else [imgs[i] for i in idx]
    # fall & recover: row 5, right side before x=1070
    groups = merge_frames([c for c in buckets.get((5, "R"), []) if c["box"][2] < 1075])
    frames["fall"] = [frame_image(im, lab, g["ids"]) for g in groups if g["x1"] - g["x0"] > 40]
    # sheet 3 poses (unlabelled)
    im3, lab3, comps3 = load_components(SHEET3)
    rows3 = {}
    for c in comps3:
        cy = (c["box"][1] + c["box"][3]) / 2
        rows3.setdefault(int(cy // 200), []).append(c)
    r0 = sorted(merge_frames(rows3.get(0, [])), key=lambda g: g["x0"])
    frames["grind"] = [frame_image(im3, lab3, g["ids"]) for g in r0]
    crouch = [c for c in comps3 if 560 < (c["box"][1] + c["box"][3]) / 2 < 760 and c["box"][0] > 700]
    frames["crouch"] = [frame_image(im3, lab3, g["ids"]) for g in sorted(merge_frames(crouch), key=lambda g: g["x0"])]
    # Newer, cleaner sheets override the older rough cuts for push and grind.
    std, fast = kick_push_frames()
    frames["push"], frames["push_fast"] = std, fast
    frames["grind"] = grind_frames(0)[1:4]   # balanced mid-grind poses on the rail row, looped
    return frames

# Source poses are drawn at different scales on different rows/sheets. Factors are chosen by eye so
# Ethan's board and body read the same size in every animation (idle = 1.0). Tweak and re-run.
SCALE = {"idle": 1.0, "push": 0.5, "push_fast": 0.5, "cruise": 1.0, "speed": 1.0, "brake": 1.0, "drift": 1.0,
         "ollie": 1.35, "landing": 1.3, "fall": 1.3, "grind": 0.5, "crouch": 0.68}

def normalize(frames):
    out = {}
    for k, v in frames.items():
        f = SCALE[k]
        out[k] = []
        for im, ax in v:
            if abs(f - 1.0) > 0.01:
                im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
                ax = round(ax * f)
            out[k].append((im, ax))
    return out

def remap(frames):
    """Map source groups onto the game's animation names."""
    o = frames.pop("ollie")
    frames["jump"] = o[0:3]
    frames["airborne"] = o[3:5]
    return frames

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    frames = remap(normalize(collect()))
    for k, v in frames.items():
        print(f"{k:8s} {len(v)} frames", [im.size for im, _ in v][:3])
    L = max(ax for fl in frames.values() for _, ax in fl)
    R = max(im.width - ax for fl in frames.values() for im, ax in fl)
    H = max(im.height for fl in frames.values() for im, _ in fl)
    W = 2 * max(L, R) + 4
    print("canvas", W, H)
    os.makedirs(OUT, exist_ok=True)
    sheet_rows = []
    for anim, fl in frames.items():
        row = []
        for i, (im, ax) in enumerate(fl):
            canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            canvas.alpha_composite(im, (W // 2 - ax, H - im.height))
            row.append(canvas)
            if not a.dry:
                canvas.save(os.path.join(OUT, f"{anim}_{i:02d}.png"))
        sheet_rows.append((anim, row))
    if a.preview:
        mx = max(len(r) for _, r in sheet_rows)
        sc = 0.5
        cw, ch = int(W * sc), int(H * sc)
        prev = Image.new("RGBA", (cw * mx, ch * len(sheet_rows)), (120, 120, 130, 255))
        for ri, (_, r) in enumerate(sheet_rows):
            for ci, c in enumerate(r):
                prev.alpha_composite(c.resize((cw, ch)), (ci * cw, ri * ch))
        prev.convert("RGB").save(a.preview)

if __name__ == "__main__":
    main()
