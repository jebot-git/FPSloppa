"""Export a separate Linux Tribes/Stonehenge test bundle; never stage a release."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Builds/Stonehenge-Tribes'
LOG = ROOT / 'test-results/tribes/export-linux.log'
OUT.mkdir(parents=True, exist_ok=True)
markers = []
try:
    for folder in ['Builds', 'dist', 'external-tools', 'tools', 'docs', 'materials', 'textures']:
        marker = ROOT / folder / '.gdignore'
        if marker.parent.exists() and not marker.exists():
            marker.touch()
            markers.append(marker)
    with LOG.open('w') as log:
        subprocess.run(['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                        '--export-release', 'Linux PC', str(OUT/'FPSloppa.x86_64')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    assert 'SCRIPT ERROR:' not in LOG.read_text(), LOG
finally:
    for marker in markers:
        marker.unlink()

def stage(source, target=None):
    destination = OUT / (target or source.relative_to(ROOT))
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

for map_id in ['ctf_stonehenge', 'qsrc_dm1']:
    stage(ROOT / 'maps' / (map_id+'.bsp'))
    for source in (ROOT/'maps/cache').glob(map_id+'*.scn'):
        # The desktop package uses BC7 or raw cache; ASTC is for standalone XR.
        if '-astc4' not in source.name:
            stage(source)
    nav = ROOT / 'maps/navigation' / (map_id+'.res')
    if nav.exists():
        stage(nav)
for source in (ROOT/'maps/Stonehenge').iterdir():
    if source.suffix in ['.txt', '.md', '.json']:
        stage(source)
for source in (ROOT/'deathmatch/maps').glob('LibreQuake-*.txt'):
    stage(source, Path('licenses')/source.name)
for folder in ['addons', 'deathmatch/audio', 'deathmatch/ui', 'deathmatch/movement']:
    for source in (ROOT/folder).rglob('*'):
        if source.is_file() and ('license' in source.name.lower() or 'copying' in source.name.lower() or source.name in ['SOURCES.md', 'THIRDPARTY.md', 'OFL.txt', 'CREDITS.txt']):
            stage(source, Path('licenses')/source.relative_to(ROOT))
for name in ['GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt', 'ASSET_CREDITS.md']:
    stage(ROOT/name)
stage(ROOT/'docs/TRIBES-MOVEMENT.md', Path('README.md'))
for label, mode in [('Desktop', 'off'), ('VR', 'on')]:
    launcher = OUT / ('Stonehenge-'+label+'.sh')
    launcher.write_text('#!/bin/sh\nset -eu\ncd -- "$(dirname -- "$0")"\n'
                        'exec ./FPSloppa.x86_64 --xr-mode '+mode+' -- '
                        '--practice --no-bots --map ctf_stonehenge --mode st --weapons tribes "$@"\n')
    launcher.chmod(0o755)
files = [{'path':p.relative_to(OUT).as_posix(), 'bytes':p.stat().st_size,
          'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
         for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='BUILD-MANIFEST.json']
(OUT/'BUILD-MANIFEST.json').write_text(json.dumps({'test_build':True,
    'protocol':'fpsloppa-58-st-tribes', 'loadout':'tribes', 'map':'ctf_stonehenge',
    'files':files}, indent=2)+'\n')
archive = ROOT/'dist/FPSloppa-Stonehenge-Tribes-Linux-test.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as package:
    for path in sorted(OUT.rglob('*')):
        if path.is_file():
            package.write(path, Path(OUT.name)/path.relative_to(OUT))
    assert package.testzip() is None
print(json.dumps({'package':str(archive), 'bytes':archive.stat().st_size,
                  'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}), flush=True)
