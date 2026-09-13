#!/usr/bin/env python3
"""Capture a bounded Quest startup test, retaining only the FPSloppa process log."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--seconds', type=float, default=20)
    parser.add_argument('--label', default='startup')
    args = parser.parse_args()
    assert 1 <= args.seconds <= 60
    assert re.fullmatch(r'[a-zA-Z0-9_-]+', args.label)
    adb = ['adb', '-s', args.serial]
    package = 'org.entryway.arena.quest'
    out = ROOT/'test-results/quest-vulkan';out.mkdir(parents=True, exist_ok=True)
    def run(*command):
        return subprocess.check_output([*adb, *command], text=True)
    run('shell', 'am', 'force-stop', package)
    with tempfile.TemporaryFile(mode='w+') as capture:
        process = subprocess.Popen([*adb, 'logcat', '-T', '1', '-v', 'brief', 'godot:V', 'Godot:V', 'AndroidRuntime:E', 'VrApi:I', '*:S'], stdout=capture, stderr=subprocess.STDOUT)
        try:
            launch = run('shell', 'am', 'start', '-W', '-n', package+'/com.godot.game.GodotAppLauncher')
            pid = run('shell', 'pidof', package).strip()
            assert pid.isdecimal()
            time.sleep(args.seconds)
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        capture.seek(0)
        own = [line for line in capture.read().splitlines() if re.search(r'\(\s*'+pid+r'\)', line)]
    log = '\n'.join(own)+'\n'
    (out/f'{args.label}.log').write_text(log)
    repeated_no_viewport = sum('No viewport was marked' in line for line in own)
    significant = [line for line in own if 'No viewport was marked' not in line and
                   any(key in line for key in ['Vulkan', 'OpenGL', 'XR_', 'MAP_READY', 'ERROR:', 'SCRIPT ERROR', 'Error:', 'FRAME_STATS', 'ASSET_'])]
    report = {'package': package, 'pid': pid, 'launch': launch, 'capture_seconds': args.seconds,
              'vulkan_reported': any('Vulkan' in line for line in own),
              'xr_ready': any('XR_READY OpenXR' in line for line in own),
              'missing_viewport_messages': repeated_no_viewport, 'significant': significant,
              'vr_metrics': [line for line in own if 'FPS=' in line],
              'log_sha256': hashlib.sha256(log.encode()).hexdigest()}
    (out/f'{args.label}.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('vr_metrics','significant')}, indent=2))
    print('\n'.join(significant[:60]))


if __name__ == '__main__':
    main()
