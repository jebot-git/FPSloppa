#!/usr/bin/env python3
"""Check image orientation, factory depth parity and displaced terrain coverage.
Run after run.gd. Requires Pillow 12.1 or later; does not run during timed captures.
"""
import json
from pathlib import Path
from PIL import Image, ImageStat

root = Path(__file__).resolve().parents[2]
output = root / "test-results/voxelspace"
checks = []

def load(name):
    return Image.open(output / (name + ".png")).convert("RGB")

for variant in ("columns_hybrid", "columns_solid"):
    image = load(variant + "_front")
    sky = ImageStat.Stat(image.crop((30, 30, 80, 80))).mean
    ground = ImageStat.Stat(image.crop((30, 800, 80, 850))).mean
    checks.append({"name": variant + " sky above terrain", "pass": sky[2] > sky[0] * 1.2 and ground[1] > ground[2] * 1.2})

for view in ("front", "diagonal", "interior_storey2"):
    reference = load("patch_lod_" + view)
    hybrid = load("columns_hybrid_" + view)
    count = matched = 0
    # Brown facade pixels are common opaque geometry. Terrain is green/gray.
    for ref, candidate in zip(reference.get_flattened_data(), hybrid.get_flattened_data()):
        if ref[0] > ref[1] * 1.3 and ref[0] > ref[2] * 1.7 and ref[0] > 65:
            count += 1
            matched += max(abs(a - b) for a, b in zip(ref, candidate)) <= 2
    parity = matched / max(count, 1)
    checks.append({"name": view + " opaque factory depth parity", "pass": count > 500 and parity > .98, "factory_pixels": count, "matching_fraction": parity})

reference = load("raster_full_diagonal").crop((0, 700, 1440, 900))
patch = load("patch_lod_diagonal").crop((0, 700, 1440, 900))
leaks = sum(candidate[2] > candidate[0] * 1.2 and ref[2] <= ref[0] * 1.2 for ref, candidate in zip(reference.get_flattened_data(), patch.get_flattened_data()))
checks.append({"name": "displaced LOD terrain covers foreground like full mesh", "pass": leaks == 0, "sky_leak_pixels": leaks})
receipt = {"checks": checks, "scope": "Saved RGB captures: screen orientation, opaque facade agreement, foreground terrain coverage; not exhaustive per-pixel depth validation."}
(output / "render-validation.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
raise SystemExit(0 if all(row["pass"] for row in checks) else 1)
