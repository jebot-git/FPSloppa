"""Prepare an offline collision regression bundle; never modify the live service."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess

from compare_jolt import JOLT_REVISION

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--template', type=Path, required=True)
    parser.add_argument('--jolt-source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('output must be a new directory')
    source = args.jolt_source.resolve()
    manifest = source / 'cq-source-manifest.json'
    if manifest.exists():
        data = json.loads(manifest.read_text())
        if data['revision'] != JOLT_REVISION:
            raise RuntimeError('Jolt source revision mismatch')
        for item in data['files']:
            relative = Path(item['path'])
            if relative.is_absolute() or '..' in relative.parts:
                raise RuntimeError('Unsafe dependency manifest path')
            content = (source / relative).read_bytes()
            blob = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
            if blob != item['sha']:
                raise RuntimeError('Jolt source hash mismatch: ' + str(relative))
    else:
        revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
        dirty = subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain'], text=True)
        if revision != JOLT_REVISION or dirty:
            raise RuntimeError('Jolt source must be a clean pinned checkout')
    output.mkdir(parents=True)
    (output / 'native').mkdir()
    for path in (ROOT / 'tools/collision_service/native').iterdir():
        if path.is_file():
            shutil.copy2(path, output / 'native' / path.name)
    if manifest.exists():
        # Copy only verified dependency files, rather than unlisted local files.
        for item in data['files']:
            target = output / 'jolt' / item['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / item['path'], target)
        shutil.copy2(manifest, output / 'jolt/cq-source-manifest.json')
    else:
        shutil.copytree(source, output / 'jolt', ignore=shutil.ignore_patterns('.git'))
    shutil.copy2(ROOT / 'tools/collision_service/run_deployment.py', output / 'run_suite.py')
    shutil.copy2(ROOT / 'tools/collision_service/DEPLOYMENT.md', output / 'README.md')
    (output / 'capacity').mkdir()
    for name in ['native_compare.py', 'client_fleet.py', 'process_sampler.py']:
        shutil.copy2(ROOT / 'tools/frontier_vps' / name, output / 'capacity' / name)
    shutil.copy2(ROOT / 'tools/voxel_battle/cq_classes.cfg', output / 'capacity/server.cfg')
    shutil.copytree(ROOT / 'tools/player_simulation', output / 'tools/player_simulation', ignore=shutil.ignore_patterns('__pycache__'))
    subprocess.run(['python3', str(ROOT / 'tools/frontier_vps/package.py'),
                    '--template', str(args.template.resolve()), '--output', str(output / 'release'),
                    '--godot', args.godot], cwd=ROOT, check=True)
    # Full Godot selects the extension's debug-feature path. The same optimized
    # GDExtension ABI works there; do not require a host-built debug library.
    voice = output / 'release/addons/twovoip/libs'
    shutil.copy2(voice / 'libtwovoip.linux.template_release.x86_64.so',
                 voice / 'libtwovoip.linux.template_debug.x86_64.so')
    version = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)
    files = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(output.rglob('*')) if p.is_file()}
    (output / 'manifest.json').write_text(json.dumps({
        'source_commit': version, 'source_dirty': bool(status),
        'jolt_revision': JOLT_REVISION, 'required_godot': '4.7.2',
        'protocol': re.search(r'const CLASS_PROTOCOL:="([^"]+)"',
                              (ROOT / 'tools/voxel_battle/class_arena.gd').read_text())[1],
        'files': files}, indent=2) + '\n')
    print('CQ_TEST_DEPLOYMENT_READY', output)


if __name__ == '__main__':
    main()
