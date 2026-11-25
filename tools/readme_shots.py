#!/usr/bin/env python3
"""Crops README screenshots out of a tools/render.sh output directory into docs/screenshots/.
usage: python3 tools/readme_shots.py <render outdir>"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Scene 01 is the full-screen context shot, cropped here to the window; the others come out of render.sh already
# cropped 1:1 to our frames (box None: copied as they are).
CROPS = {
    "main.png": ("scene_01_main_default.png", (380, 90, 1240, 985)),
    "elvui_wc3.png": ("scene_02_main_elvui.png", None),
    "card.png": ("scene_03_card_default.png", None),
    "alerts.png": ("scene_05_alerts.png", None),
    "compact.png": ("scene_06_compact.png", None),
    "first_run.png": ("scene_07_first_run_empty.png", None),
}


def main():
    src = sys.argv[1]
    out = os.path.join(ROOT, "docs", "screenshots")
    os.makedirs(out, exist_ok=True)
    for name, (scene, box) in CROPS.items():
        img = Image.open(os.path.join(src, scene)).convert("RGB")
        if box:
            img = img.crop(box)
        img.save(os.path.join(out, name), optimize=True)
        print("wrote", os.path.join("docs", "screenshots", name), img.size)


if __name__ == "__main__":
    main()
