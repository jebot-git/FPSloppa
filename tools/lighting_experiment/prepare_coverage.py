#!/usr/bin/env python3
"""Inventory the shipping bundle and randomly select a local external BSP archive."""
import argparse
import hashlib
import json
from pathlib import Path
import random
import secrets
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.community_maps.archive import members, read_member
from tools.makkon.theme import lumps, repack

OUT = ROOT/'test-results/lighting-coverage'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=int)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    base = json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text())
    catalog = {r['id']: r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())}
    rows = []
    (OUT/'sources').mkdir(exist_ok=True)
    previous = json.loads((OUT/'input.json').read_text()) if (OUT/'input.json').exists() else {'rows': []}
    prior = {r['id']: r for r in previous['rows']}
    bundle = ROOT.parent/'Builds'/f'FPSloppa-{base["version"]}-Base-Assets.zip'
    with zipfile.ZipFile(bundle) as archive:
        for entry in base['files']:
            if not entry['path'].endswith('.bsp'):
                continue
            data = archive.read(entry['path'])
            assert sha(data) == entry['sha256']
            name = Path(entry['path']).stem
            snapshot = OUT/'sources'/f'{name}.bsp'
            snapshot.write_bytes(data)
            parts, extra = lumps(data)
            baked = b'"_fpsloppa_bake" "1"' in parts[0].split(b'}')[0]
            rows.append(dict(id=name, path='res://'+snapshot.relative_to(ROOT).as_posix(), original_path=entry['path'], sha256=sha(data),
                             category='distribution', modes=catalog.get(name, prior.get(name, {})).get('modes', []),
                             expected_baked=baked, expected_rgb=any(k.rstrip(b'\0') == b'RGBLIGHTING' for k,v in extra) if baked else False))
    # Select before inspecting appearance. Keep the candidate pool and seed in
    # the receipt; failures must be reported rather than silently re-rolling.
    excluded = {r['archive'] for r in json.loads((ROOT/'tools/community_maps/approved.json').read_text())}
    pool = []
    for archive in sorted((ROOT/'tools/community_maps/local').glob('quaddicted-*.zip')):
        if archive.name in excluded:
            continue
        for member in members(archive):
            if member.lower().endswith('.bsp'):
                pool.append([archive.name, member])
    seed = args.seed if args.seed is not None else secrets.randbits(32)
    selected = random.Random(seed).choice(pool)
    archive = ROOT/'tools/community_maps/local'/selected[0]
    data = read_member(archive, selected[1])
    parts, extra = lumps(data)
    assert len(data) <= 25_000_000 and parts[8], 'Selected BSP must be supported and have baked samples'
    source_name = Path(selected[1]).stem
    original = OUT/'external-original.bsp'
    original.write_bytes(data)
    for member in members(archive):
        if member.lower().endswith('.txt'):
            (OUT/('external-readme-'+Path(member).name)).write_bytes(read_member(archive, member))
    # Diagnostic opt-in only. Keep original gray/RGB lighting and every other
    # lump byte-for-byte, including original textures and collision.
    enabled = list(parts)
    assert b'_fpsloppa_bake' not in enabled[0]
    enabled[0] = enabled[0].replace(b'{', b'{\n"_fpsloppa_bake" "1"\n"_fpsloppa_atlas" "4096"', 1)
    diagnostic = repack(enabled, extra)
    check, check_extra = lumps(diagnostic)
    assert check[1:] == parts[1:] and check_extra == extra
    (OUT/'external-optin.bsp').write_bytes(diagnostic)
    for variant, payload in [('original', data), ('optin', diagnostic)]:
        rows.append(dict(id='external-'+variant, title=source_name, path=f'res://test-results/lighting-coverage/external-{variant}.bsp',
                         sha256=sha(payload), category='external', modes=['dm'], expected_baked=variant=='optin',
                         expected_rgb=variant=='optin' and any(k.rstrip(b'\0')==b'RGBLIGHTING' for k,v in extra)))
    source_file = archive.name.removeprefix('quaddicted-')
    if source_file.startswith(('ctf-', 'tf-')):
        source_file = source_file.replace('-', '/', 1)
    receipt = dict(seed=seed, selection=selected, pool=pool, archive_sha256=sha(archive.read_bytes()),
                   source='https://www.quaddicted.com/files/maps/multiplayer/'+source_file,
                   source_bsp_sha256=sha(data), original_light_bytes=len(parts[8]), diagnostic_only_entities_changed=True,
                   distribution_version=base['version'], bundle=str(bundle), rows=rows)
    (OUT/'input.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({k:v for k,v in receipt.items() if k not in ('pool','rows')}, indent=2))
    print(len(rows), 'cases;', len(pool), 'external BSP candidates')


if __name__ == '__main__':
    main()
