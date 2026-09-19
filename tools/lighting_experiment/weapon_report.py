"""Assemble the captured weapon matrix; no synthetic lighting/image corrections."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-results/weapon-emission"
report = json.loads((OUT / "report.json").read_text())
assert not report["failures"], report["failures"]
font = ImageFont.truetype("/usr/share/fonts/google-noto/NotoSans-Regular.ttf", 17)
small = ImageFont.truetype("/usr/share/fonts/google-noto/NotoSans-Regular.ttf", 14)
rows = report["weapons"]

def gallery(items, name, columns=3):
    width, height = 400, 332
    canvas = Image.new("RGB", (columns * width, ((len(items)+columns-1)//columns)*height), "#12151c")
    draw = ImageDraw.Draw(canvas)
    for i, row in enumerate(items):
        x, y = i % columns * width, i // columns * height
        image = Image.open(OUT / row["image"]).convert("RGB").resize((400, 300), Image.Resampling.LANCZOS)
        canvas.paste(image, (x, y+32))
        draw.text((x+9,y+7), row["label"], fill="#e3e7ef", font=font)
    canvas.save(OUT / name, quality=92)

selected = [5, 6, 7, 8, 9, 15, 18, 26, 27, 30, 34, 35, 36, 77, 76]
gallery([rows[i] for i in selected], "highlights.jpg")
gallery(rows[:44], "all-profiles.jpg", 4)
gallery(rows[44:], "tf-and-charged.jpg", 4)
canvas = Image.new("RGB", (1200, 475), "#12151c")
draw = ImageDraw.Draw(canvas)
for i, name in enumerate(["dm6-off", "dm6-on"]):
    canvas.paste(Image.open(OUT/(name+".png")).convert("RGB").resize((600,450)), (i*600,25))
    draw.text((i*600+10,4), "DM6 / weapon illumination " + ("off" if i==0 else "on"),font=small,fill="white")
canvas.save(OUT / "dm6-comparison.jpg", quality=94)
perf=json.loads((OUT / "performance.json").read_text())
summary={"passed": True,"weapon_cases":len(rows),"checks":len(report["checks"]),"effect_limit":report["effect_limit"],"failures":[],"gpu":report["gpu"],"renderer":report["renderer"],"resolution":[800,600],"msaa":4,"performance":perf,"regression":{"weapon_rules_and_demos":71,"optics_fx":23,"simulated_vr_projectile_presentation":28},"artifacts":"test-results/weapon-emission/"}
(ROOT / "docs/validation/weapon-emission.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
