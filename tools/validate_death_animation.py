"""Bounded death animation/lifecycle checks plus existing avatar regressions."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot'))
    parser.add_argument('--preview', action='store_true', help='Open a rendered comparison and save a PNG')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Set GODOT_BIN or pass --godot')
    output = ROOT / 'test-results/death-animation'
    output.mkdir(parents=True, exist_ok=True)
    results = []
    cases = [('death_animation', []), ('avatar_stances', []), ('avatar_stances', ['--fallback']), ('avatar_scaling', [])]
    if args.preview:
        cases.append(('death_animation', ['--preview']))
    with tempfile.TemporaryDirectory(prefix='fpsloppa-death-validation-') as folder:
        for script, flags in cases:
            name = script + ('-' + flags[0].removeprefix('--') if flags else '')
            command = [args.godot, *([] if '--preview' in flags else ['--headless']), '--xr-mode', 'off', '--path', str(ROOT), '--script', 'res://deathmatch/tests/' + script + '.gd']
            if flags:
                command += ['--'] + flags
            path = output / (name + '.log')
            with path.open('w') as log:
                try:
                    code = subprocess.run(command, env=dict(os.environ, XDG_DATA_HOME=folder), stdout=log, stderr=subprocess.STDOUT, timeout=120).returncode
                except subprocess.TimeoutExpired:
                    code = 124
            errors = [s for s in path.read_text().splitlines() if 'ERROR:' in s or s.startswith('FAIL')]
            results.append({'test': name, 'exit_code': code, 'errors': errors, 'passed': code == 0 and not errors})
            print(name, 'PASS' if results[-1]['passed'] else 'FAIL', flush=True)
    sources = ['deathmatch/avatars/' + name + '.gd' for name in ['death_pose', 'pose', 'rig', 'fallback', 'eyes']]
    sources += ['deathmatch/art.gd', 'deathmatch/fighter.gd', 'deathmatch/tests/death_animation.gd']
    report = {'tests': results, 'passed': all(r['passed'] for r in results),
              'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
              'poses': json.loads((output / 'results.json').read_text()),
              'limits': 'Scripted collapse, without per-limb collision or slope conformance. Timings measure settled rig/pose script updates only, excluding GPU skinning, hair and rendering. No headset performance claim.'}
    (ROOT / 'docs/validation/death-animation.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
