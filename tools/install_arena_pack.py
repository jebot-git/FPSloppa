"""Install an extracted FPSloppa arena pack and merge mode rotations safely.

Usage: python3 install_arena_pack.py --game-dir /path/to/game
The package's install-manifest.json is beside this script. No game binary is needed.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import tempfile

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inside(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('Path leaves installation directory: ' + relative)
    return path

def install(source, game, dry_run=False):
    manifest = json.loads((source / 'install-manifest.json').read_text())
    copies = []
    for row in manifest['files']:
        relative = row['path']
        if not relative.startswith('maps/') or '..' in Path(relative).parts:
            raise ValueError('Invalid package destination: ' + relative)
        src = inside(source, relative); dest = inside(game, relative)
        if digest(src) != row['sha256']:
            raise ValueError('Package checksum mismatch: ' + relative)
        if dest.exists():
            if digest(dest) != row['sha256']:
                raise ValueError('Existing file differs; preserve/rename it before installing: ' + str(dest))
        else:
            copies.append((src, dest))
    rotations = []
    for mode, maps in manifest['rotations'].items():
        if mode not in ('dm','tdm','ctf','koth','ig','ft','cc','tf'):
            raise ValueError('Unknown game mode')
        if not all(isinstance(name,str) and name.startswith(mode+'_') and name.replace('_','').isalnum() for name in maps):
            raise ValueError('Invalid map id')
        dest = inside(game, 'maps/' + mode + '_maplist.txt')
        old = dest.read_text() if dest.exists() else ''
        existing = set(old.split())
        added = [name for name in maps if name not in existing]
        if added:
            new = old + ('\n' if old and not old.endswith('\n') else '') + '\n'.join(added) + '\n'
            rotations.append((dest, new))
    print(f'{len(copies)} new files; {len(rotations)} rotations to extend.')
    if dry_run:
        return
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    for src, dest in copies:
        dest.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=dest.parent, prefix='.arena-install-', delete=False) as handle:
            temp = Path(handle.name)
            with src.open('rb') as input_file: shutil.copyfileobj(input_file,handle)
        os.replace(temp, dest)
    for dest, content in rotations:
        dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():
            shutil.copy2(dest, dest.with_name(dest.name + '.before-arena-pack-' + stamp))
        with tempfile.NamedTemporaryFile(mode='w', dir=dest.parent, prefix='.arena-rotation-', delete=False) as handle:
            temp=Path(handle.name);handle.write(content)
        os.replace(temp,dest)
    print('Installed. Rescan ASSETS in FPSloppa, then choose the map and mode.')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--game-dir',type=Path,required=True)
    parser.add_argument('--source',type=Path,default=Path(__file__).resolve().parent)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args();install(args.source,args.game_dir,args.dry_run)

if __name__=='__main__':main()
