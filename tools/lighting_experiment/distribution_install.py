#!/usr/bin/env python3
"""Install validated base-map AO bakes/caches and record lighting-only lineage."""
import json
from pathlib import Path
import shutil
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.lighting_experiment.distribution_bake import OUT
from tools.lighting_experiment.bake import sha, verify
from tools.makkon.theme import lumps


def main():
    bake = json.loads((OUT/'bake.json').read_text())
    imported = json.loads((OUT/'import.json').read_text())
    rendered = json.loads((OUT/'mobile/render.json').read_text())
    summary = json.loads((OUT/'render-summary.json').read_text())
    catalog_path = ROOT/'deathmatch/maps/manifest.json'
    catalog = json.loads(catalog_path.read_text())
    ids = {r['id'] for r in catalog if r.get('distribution', 'base') == 'base'}
    assert ids == {r['id'] for r in bake['maps']} == {r['id'] for r in imported['maps']}
    assert not imported['failures'] and not rendered['failures']
    assert len(rendered['records']) == len(ids)*16
    assert summary['extra_draws'] == 0
    rows = []
    for row in bake['maps']:
        name = row['id'];original = (OUT/'original'/(name+'.bsp')).read_bytes()
        candidate = (OUT/'low'/(name+'.bsp')).read_bytes()
        assert sha(original) == row['original_sha256']
        assert sha((ROOT/row['source']).read_bytes()) == row['original_sha256'], 'Distribution changed: '+name
        assert sha(candidate) == row['bakes']['low']['sha256']
        checks = verify(original, candidate)
        cache = OUT/'cache'/(name+'.scn')
        imported_row = next(r for r in imported['maps'] if r['id'] == name)
        assert sha(cache.read_bytes()) == imported_row['cache_sha256']
        rows.append({'id': name, 'original_sha256': sha(original), 'sha256': sha(candidate),
                     'cache_sha256': sha(cache.read_bytes()), 'navigation_sha256': sha((ROOT/'maps/navigation'/(name+'.res')).read_bytes()),
                     'original_bytes': len(original), 'bytes': len(candidate),
                     'atlas_dimensions': [imported_row['low']['atlases'][0]['width'], imported_row['low']['atlases'][0]['height']],
                     'preserved_pruned_style_blocks': row['bakes']['low']['preserved_pruned_style_blocks'], **checks})
    receipt = {'status': 'validated; installing', 'maps': rows, 'compiler': bake['compiler'],
               'compiler_sha256': bake['compiler_sha256'], 'flags': bake['common_flags']+bake['variants']['low'],
               'layout_policy': bake['layout_policy'],
               'validation': {'import_failures': imported['failures'], 'render_failures': rendered['failures'],
                              'render_summary': summary, 'atlas_uvs_dimensions_and_material_counts_preserved': True},
               'limitations': ['Static scenery AO merged into existing RGB; Classic/Contrast does not disable AO.',
                              'No dynamic avatar/elevator contact occlusion.',
                              'Single Linux Vulkan GPU sweep; no new headset match benchmark.',
                              'Original gameplay/art receipts retain their tested hashes; this receipt establishes lighting-only lineage.']}
    target = ROOT/'docs/validation/lighting-ao-distribution.json'
    backup = OUT/'metadata-original';backup.mkdir(exist_ok=True)
    shutil.copyfile(catalog_path, backup/'catalog.json')
    manifest_paths = [ROOT/'maps'/folder/'manifest.json' for folder in ['HiSlop','Frigate','Pressureworks','VesperAbbey']]
    manifest_paths += sorted((ROOT/'maps/CTFStudies').glob('ctf_*/manifest.json'))
    # Preserve historical build and playtest receipts. Only current manifests
    # change hashes; the new receipt proves the unchanged gameplay/art lumps.
    for path in manifest_paths:
        data = json.loads(path.read_text())
        row = next((r for r in rows if r['original_sha256'] == data.get('sha256')), None)
        if row:
            saved = backup/path.relative_to(ROOT);saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, saved)
            data['sha256'] = row['sha256']
            data['lighting_rebake'] = {'original_sha256': row['original_sha256'], 'receipt': 'docs/validation/lighting-ao-distribution.json'}
            path.write_text(json.dumps(data, indent=2)+'\n')
    for row in rows:
        name = row['id']
        shutil.copyfile(OUT/'low'/(name+'.bsp'), ROOT/'maps'/(name+'.bsp'))
        for suffix in ['.scn', '-lightmap1.scn']:
            destination = ROOT/'maps/cache'/(name+suffix)
            if destination.exists():
                saved = OUT/'cache-original'/destination.name;saved.parent.mkdir(exist_ok=True)
                shutil.copyfile(destination, saved)
            shutil.copyfile(OUT/'cache'/(name+'.scn'), destination)
        lit = ROOT/'maps'/(name+'.lit')
        if lit.exists():
            shutil.copyfile(lit, OUT/'original'/lit.name)
            _, extras = lumps((ROOT/'maps'/(name+'.bsp')).read_bytes())
            lit.write_bytes(b'QLIT\x01\x00\x00\x00'+dict(extras)[b'RGBLIGHTING'.ljust(24,b'\0')])
        entry = next(r for r in catalog if r['id'] == name)
        entry['sha256'] = row['sha256']
        assert sha((ROOT/'maps/navigation'/(name+'.res')).read_bytes()) == row['navigation_sha256']
    catalog_path.write_text(json.dumps(catalog, indent=2)+'\n')
    receipt['status'] = 'installed in base distribution; package refresh pending'
    target.write_text(json.dumps(receipt, indent=2)+'\n')
    print('Installed', len(rows), 'AO BSPs and both cache variants; navigation unchanged')


if __name__ == '__main__':
    main()
