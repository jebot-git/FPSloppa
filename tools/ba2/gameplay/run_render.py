#!/usr/bin/env python3
"""Bounded native Vulkan capture for the BA-2 gameplay fixture."""
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
out = root / 'test-results/ba2/gameplay'
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, XDG_DATA_HOME='/tmp/fpsloppa-ba2-data')
with (out / 'render.log').open('w') as log:
    result = subprocess.run(['godot', '--path', str(root), '--xr-mode', 'off',
        '--audio-driver', 'Dummy', '--rendering-method', 'mobile', '--rendering-driver', 'vulkan',
        '--script', 'res://tools/ba2/gameplay/render.gd'], env=env, stdout=log,
        stderr=subprocess.STDOUT, timeout=120)
print((out / 'render.log').read_text())
raise SystemExit(result.returncode)
