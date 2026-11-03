#!/usr/bin/env python3
"""Cut individual sprites out of a concept/element sheet.

Usage:
  python3 tools/slice_sheet.py SHEET.png OUT_DIR [--min-area 400] [--pad 2] [--chroma #RRGGBB --tol 24]

It first VALIDATES the sheet (does it really have an alpha channel? how much of it
is transparent?) and refuses to cut a sheet with no transparency unless you give
--chroma to key out a flat background colour. Each connected group of opaque
pixels becomes one trimmed PNG (name_000.png, ...) plus a report (slices.json)
with bounding boxes, so you can check boundaries and rename pieces by hand.
Requires: pip install pillow
"""
import argparse, json, os, sys
from collections import deque
from PIL import Image


def key_chroma(img, hex_color, tol):
    r, g, b = (int(hex_color.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            pr, pg, pb, _ = px[x, y]
            if abs(pr - r) <= tol and abs(pg - g) <= tol and abs(pb - b) <= tol:
                px[x, y] = (pr, pg, pb, 0)
    return img


def components(alpha, w, h, thresh):
    seen = bytearray(w * h)
    boxes = []
    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if seen[i] or alpha[i] <= thresh:
                continue
            q = deque([(sx, sy)])
            seen[i] = 1
            x0 = x1 = sx
            y0 = y1 = sy
            area = 0
            while q:
                x, y = q.popleft()
                area += 1
                x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
                               (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and alpha[j] > thresh:
                            seen[j] = 1
                            q.append((nx, ny))
            boxes.append((x0, y0, x1 + 1, y1 + 1, area))
    return boxes


def merge_nearby(boxes, gap):
    boxes = [list(b) for b in boxes]
    changed = True
    while changed:
        changed = False
        out = []
        for b in boxes:
            for o in out:
                if not (b[0] > o[2] + gap or b[2] < o[0] - gap or b[1] > o[3] + gap or b[3] < o[1] - gap):
                    o[0], o[1], o[2], o[3] = min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3])
                    o[4] += b[4]
                    changed = True
                    break
            else:
                out.append(b)
        boxes = out
    return boxes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('out')
    ap.add_argument('--min-area', type=int, default=400)
    ap.add_argument('--pad', type=int, default=2)
    ap.add_argument('--merge-gap', type=int, default=6, help='merge fragments closer than this (px)')
    ap.add_argument('--alpha-thresh', type=int, default=8)
    ap.add_argument('--chroma')
    ap.add_argument('--tol', type=int, default=24)
    a = ap.parse_args()

    img = Image.open(a.sheet)
    has_alpha = img.mode in ('RGBA', 'LA') or 'transparency' in img.info
    img = img.convert('RGBA')
    if a.chroma:
        img = key_chroma(img, a.chroma, a.tol)
        has_alpha = True
    alpha = list(img.getchannel('A').getdata())
    transparent = sum(1 for v in alpha if v <= a.alpha_thresh) / len(alpha)
    print(f'{a.sheet}: {img.width}x{img.height}, alpha channel={has_alpha}, transparent={transparent:.1%}')
    if transparent < 0.02:
        sys.exit('REFUSING: sheet has (almost) no transparent pixels - it is not a usable transparent sheet. '
                 'Re-export with alpha, or pass --chroma #RRGGBB to key out a flat background.')

    boxes = [b for b in merge_nearby(components(alpha, img.width, img.height, a.alpha_thresh), a.merge_gap)
             if b[4] >= a.min_area]
    boxes.sort(key=lambda b: (round(b[1] / 200), b[0]))  # rows then columns
    os.makedirs(a.out, exist_ok=True)
    stem = os.path.splitext(os.path.basename(a.sheet))[0].replace(' ', '_')
    report = []
    for n, (x0, y0, x1, y1, area) in enumerate(boxes):
        x0, y0 = max(x0 - a.pad, 0), max(y0 - a.pad, 0)
        x1, y1 = min(x1 + a.pad, img.width), min(y1 + a.pad, img.height)
        name = f'{stem}_{n:03d}.png'
        img.crop((x0, y0, x1, y1)).save(os.path.join(a.out, name))
        report.append({'file': name, 'bbox': [x0, y0, x1, y1], 'size': [x1 - x0, y1 - y0], 'opaque_px': area})
    with open(os.path.join(a.out, 'slices.json'), 'w') as f:
        json.dump(report, f, indent=2)
    print(f'wrote {len(report)} sprites to {a.out} (see slices.json)')


if __name__ == '__main__':
    main()
