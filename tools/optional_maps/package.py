"""Build all 53 redistributable retired/optional maps as installable mode categories."""
from pathlib import Path
import argparse
import hashlib
import io
import json
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE_COMMIT = 'cec9edddcec7ccb2c8ab5541d96397e90fc6ce06'
CATEGORIES = {'dm': 'Deathmatch', 'tdm': 'Team Deathmatch', 'ctf': 'Capture the Flag',
              'koth': 'King of the Hill', 'ig': 'Instagib', 'ft': 'Freeze Tag',
              'cc': 'Chainsaw Carnage'}
DOC_SUFFIXES = {'.md', '.txt', '.json', '.map'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def collect():
    raw = subprocess.check_output(['git', 'archive', ARCHIVE_COMMIT, 'optional-arena-pack'], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        old = {m.name.removeprefix('optional-arena-pack/'): archive.extractfile(m).read()
               for m in archive.getmembers() if m.isfile()}
    current = json.loads((ROOT / 'deathmatch/maps/manifest.json').read_text())
    rows = []
    payload = {}

    def put(mode, relative, data):
        name = f'categories/{mode}/maps/{relative}'
        if name in payload and payload[name] != data:
            raise ValueError('Conflicting asset ' + name)
        payload[name] = data

    def docs(mode, folder, prefix):
        for path in sorted(folder.rglob('*')):
            if path.is_file() and not path.name.endswith('_maplist.txt') and (path.suffix in DOC_SUFFIXES or path.name in {'COPYING', 'CREDITS', 'README-IMPORTANT-LICENCE-INFO'}):
                put(mode, 'OptionalMapPack/' + prefix + '/' + path.relative_to(folder).as_posix(), path.read_bytes())

    def add(row, mode, group, data, lit=None):
        row = {k: row[k] for k in ['id', 'title', 'sha256', 'modes', 'objectives', 'recommended_players', 'small_groups_only', 'author'] if k in row}
        assert sha(data) == row['sha256'], (row['id'], 'BSP receipt mismatch')
        row.update(category=mode, collection=group, distribution='optional',
                   path='res://maps/' + row['id'] + '.bsp', scene='res://maps/cache/' + row['id'] + '.scn')
        rows.append(row)
        put(mode, row['id'] + '.bsp', data)
        if lit:
            put(mode, row['id'] + '.lit', lit)

    for source in json.loads(old['manifest.json']):
        if source['mode'] not in CATEGORIES:
            continue
        row = dict(source, modes=[source['mode']])
        add(row, source['mode'], 'Arena Collection 1', old[source['id'] + '.bsp'], old.get(source['id'] + '.lit'))
        for name in ['readmes/' + row['id'] + '.md', 'source/' + row['id'] + '.map']:
            put(source['mode'], 'OptionalMapPack/ArenaCollection1/' + name, old[name])
    for mode in CATEGORIES.keys() - {'as'}:
        for name, data in old.items():
            if '/' not in name and (Path(name).suffix in DOC_SUFFIXES) and not name.endswith('_maplist.txt'):
                put(mode, 'OptionalMapPack/ArenaCollection1/' + name, data)
    for row in current:
        if row.get('expansion') not in {'librequake', 'community'}:
            continue
        folder = ROOT / ('optional-librequake' if row['expansion'] == 'librequake' else 'optional-community') / 'maps'
        path = folder / (row['id'] + '.bsp')
        if not path.exists():
            path = ROOT / 'maps' / path.name
        add(row, 'dm', 'LibreQuake' if row['expansion'] == 'librequake' else 'Community', path.read_bytes(),
            path.with_suffix('.lit').read_bytes() if path.with_suffix('.lit').exists() else None)
        if row['expansion'] == 'community':
            docs('dm', ROOT / 'maps/Community' / row['id'], 'Community/' + row['id'])
    extra = ROOT / 'optional-map-pack'
    for row in json.loads((extra / 'manifest.json').read_text())['maps']:
        path = extra / (row['id'] + '.bsp')
        add(dict(row, modes=['dm', 'tdm', 'ig', 'ft', 'cc']), 'dm', 'LibreQuake', path.read_bytes(),
            path.with_suffix('.lit').read_bytes() if path.with_suffix('.lit').exists() else None)
    docs('dm', extra, 'LibreQuake/ExtraMaps')
    for path in (ROOT / 'deathmatch/maps').glob('LibreQuake-*.txt'):
        put('dm', 'OptionalMapPack/LibreQuake/' + path.name, path.read_bytes())
    docs('dm', ROOT / 'maps/Makkon', 'Makkon')
    assert len(rows) == len({r['id'] for r in rows}) == 53
    assert {r['id'] for r in current if r.get('distribution', 'base') == 'base'}.isdisjoint(r['id'] for r in rows)
    assert all(r.get('modes') and set(r['modes']) <= CATEGORIES.keys() for r in rows)
    return sorted(rows, key=lambda r: (list(CATEGORIES).index(r['category']), r['title'])), payload


def build(output=None, sync_catalog=False):
    rows, payload = collect()
    if sync_catalog:
        path = ROOT / 'deathmatch/maps/manifest.json'
        current = json.loads(path.read_text())
        known = {r['id'] for r in current}
        current += [dict(r, expansion='optional-community-pack') for r in rows if r['id'] not in known]
        path.write_bytes(encoded(current))
    catalog = {r['id']: r for r in json.loads((ROOT / 'deathmatch/maps/manifest.json').read_text())}
    for row in rows:
        assert row['sha256'] == catalog[row['id']]['sha256'] and row['modes'] == catalog[row['id']]['modes'], row['id']
        assert catalog[row['id']]['distribution'] == 'optional'
    lines = ['# Optional Community Map Pack', '', '53 maps, sorted by their authored game mode. Multi-mode LibreQuake/community arenas live in Deathmatch; the compatibility lists below also include them in their supported modes.', '']
    for mode, title in CATEGORIES.items():
        selected = [r for r in rows if r['category'] == mode]
        compatible = [r for r in rows if mode in r['modes']]
        lines += [f'## {title} ({mode}) — {len(selected)} maps', '', '| Map | ID | Collection | Supported modes |', '| --- | --- | --- | --- |']
        lines += [f"| {r['title']} | `{r['id']}` | {r['collection']} | {', '.join(r['modes'])} |" for r in selected]
        lines += ['']
        put = f'categories/{mode}/maps/OptionalMapPack/categories/{mode}/'
        payload[put + 'catalog.json'] = encoded(selected)
        payload[put + 'README.md'] = (f'# {title}\n\nCopy this category’s maps/ contents into the game’s external maps/ folder.\n'
                                    'Keep OptionalMapPack notices with the maps. Existing rotations are not changed.\n').encode()
        # Examples deliberately do not use the live *_maplist.txt filenames.
        payload[put + mode + '_maplist.example.txt'] = ('\n'.join(r['id'] for r in selected) + '\n').encode()
        payload['rotations/' + mode + '_maplist.example.txt'] = ('\n'.join(r['id'] for r in compatible) + '\n').encode()
    payload['CATALOG.md'] = ('\n'.join(lines) + '\n').encode()
    payload['README.md'] = (ROOT / 'tools/optional_maps/PACK-README.md').read_bytes()
    payload['install.py'] = (ROOT / 'tools/optional_maps/install.py').read_bytes()
    receipts = []
    for name, data in sorted(payload.items()):
        receipt = {'path': name, 'bytes': len(data), 'sha256': sha(data)}
        if name.startswith('categories/'):
            receipt.update(category=name.split('/')[1], install_path=name.split('/', 2)[2])
        receipts.append(receipt)
    manifest = {'format': 1, 'name': 'FPSloppa Optional Community Map Pack', 'categories': CATEGORIES,
                'arena_collection_commit': ARCHIVE_COMMIT, 'maps': rows, 'files': receipts,
                'excluded': ['Local-only AD, original TF, FortressOne and ThreeWave conversions', 'Unreviewed community downloads', 'Current base maps', 'Renderer caches and old navigation caches'],
                'validation_note': 'Historical per-collection reports retain their original scope. Current installation/import verification is recorded separately; no new balance or headset-performance certification.'}
    payload['PACK.json'] = encoded(manifest)
    version = (ROOT / 'VERSION').read_text().strip()
    output = output or ROOT / 'dist' / f'FPSloppa-{version}-Optional-Community-Maps.zip'
    output.parent.mkdir(parents=True, exist_ok=True)
    # Fixed metadata and order make identical inputs reproduce the same archive.
    with tempfile.TemporaryDirectory(prefix='.optional-pack-', dir=output.parent) as staging:
        candidate = Path(staging) / output.name
        with zipfile.ZipFile(candidate, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name, data in sorted(payload.items()):
                entry = zipfile.ZipInfo(name, date_time=(2026, 9, 12, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, data)
        with zipfile.ZipFile(candidate) as archive:
            assert archive.testzip() is None
            assert len([n for n in archive.namelist() if n.endswith('.bsp')]) == 53
            for row in receipts:
                assert sha(archive.read(row['path'])) == row['sha256']
            assert not any(Path(n).name in {m + '_maplist.txt' for m in CATEGORIES} or Path(n).suffix in {'.scn', '.res', '.pak'} for n in archive.namelist())
        candidate.replace(output)
    output.with_suffix('.sha256').write_text(sha(output.read_bytes()) + '  ' + output.name + '\n')
    (ROOT / 'tools/optional_maps/CATALOG.md').write_bytes(payload['CATALOG.md'])
    print(json.dumps({'archive': str(output), 'bytes': output.stat().st_size, 'sha256': sha(output.read_bytes()), 'maps': len(rows)}))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--sync-catalog', action='store_true', help='Register missing optional map metadata without installing maps')
    args = parser.parse_args()
    build(args.output, args.sync_catalog)
