"""Install selected Optional Community Map Pack categories without replacing files."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import shutil


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contained(root, name):
    part = PurePosixPath(name)
    if part.is_absolute() or '..' in part.parts or '\\' in name:
        raise ValueError('Unsafe package path: ' + name)
    path = root.joinpath(*part.parts)
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Path escapes installation directory: ' + name)
    return path


def install(package, destination, categories=(), dry_run=False):
    manifest = json.loads((package / 'PACK.json').read_text())
    selected = set(categories) or set(manifest['categories'])
    if selected - set(manifest['categories']):
        raise ValueError('Unknown categories: ' + ', '.join(sorted(selected - set(manifest['categories']))))
    jobs = {}
    # Validate the entire selection before making any changes, including conflicts.
    for row in manifest['files']:
        if row.get('category') not in selected or 'install_path' not in row:
            continue
        source = contained(package, row['path'])
        target = contained(destination, row['install_path'])
        if digest(source) != row['sha256']:
            raise ValueError('Package checksum mismatch: ' + row['path'])
        if target.exists() and (not target.is_file() or digest(target) != row['sha256']):
            raise ValueError('Preserving different existing file: ' + str(target))
        previous = jobs.get(target)
        if previous and digest(previous) != row['sha256']:
            raise ValueError('Conflicting category payload: ' + str(target))
        jobs[target] = source
    if not dry_run:
        for target, source in jobs.items():
            if target.exists():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive creation also protects a file created after preflight.
            with target.open('xb') as output, source.open('rb') as incoming:
                shutil.copyfileobj(incoming, output)
    maps = [r for r in manifest['maps'] if r['category'] in selected]
    return {'maps': len(maps), 'files': len(jobs), 'categories': sorted(selected), 'dry_run': dry_run}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir', type=Path, required=True, help='External asset root containing maps/')
    parser.add_argument('--category', action='append', default=[], help='Mode tag; repeat to select multiple categories; default: all')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(install(Path(__file__).resolve().parent, args.game_dir, args.category, args.dry_run)))
    except (ValueError, OSError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
