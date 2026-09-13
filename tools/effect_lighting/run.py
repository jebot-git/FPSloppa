"""Bounded, serial desktop Vulkan experiment. No production settings are changed."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/effect-lighting'
OUT.mkdir(parents=True, exist_ok=True)
with (OUT / 'render.log').open('w') as log:
    result = subprocess.run(
        ['godot', '--xr-mode', 'off', '--path', str(ROOT), '--rendering-method', 'mobile',
         '--audio-driver', 'Dummy', '--script', 'res://tools/effect_lighting/render.gd'],
        cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=240)
print('Exit:', result.returncode, 'Log:', OUT / 'render.log')
raise SystemExit(result.returncode)
