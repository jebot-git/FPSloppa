"""Check Vulkan startup and reject an explicit OpenGL override before gameplay."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/renderer-policy'
OUT.mkdir(parents=True, exist_ok=True)
godot = os.environ.get('GODOT_BIN', 'godot')
subprocess.run([godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                '--script', 'res://deathmatch/tests/renderer_policy.gd'], check=True, timeout=30)
results = []
for method, driver, expected in [('gl_compatibility', 'opengl3', 2), ('mobile', 'vulkan', 0)]:
    log = OUT / (driver + '.log')
    with log.open('w') as output:
        result = subprocess.run([godot, '--rendering-method', method, '--rendering-driver', driver,
                                 '--xr-mode', 'off', '--path', str(ROOT), '--', '--quit-after-seconds', '3'],
                                stdout=output, stderr=subprocess.STDOUT, timeout=90)
    text = log.read_text()
    assert result.returncode == expected, (result.returncode, text[-2500:])
    assert 'SCRIPT ERROR' not in text, text[-2500:]
    if expected:
        assert 'FPSloppa requires Vulkan' in text and 'Connecting' not in text
    else:
        assert 'Forward Mobile' in text, text[-2500:]
    results.append(dict(method=method, driver=driver, exit=result.returncode, passed=True))
    print(results[-1], flush=True)
(OUT / 'startup.json').write_text(json.dumps(results, indent=2) + '\n')
