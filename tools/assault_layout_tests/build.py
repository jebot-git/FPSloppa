"""Build expanded default Assault maps and compact Tiny variants."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from makkon.theme import apply_assault


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler-dir', type=Path, required=True)
    p.add_argument('--install', action='store_true')
    p.add_argument('--skip-build', action='store_true', help='Install already compiled results')
    args = p.parse_args()
    variants = []
    # Compile all variants before replacing donor BSPs and their provenance.
    for kind, generator, metadata_name in [('hislop','hispeed_concept','HiSlop'),('frigate','frigate_concept','Frigate')]:
        for tiny in [False, True]:
            out = ROOT/'test-results/assault-layouts'/kind/('tiny' if tiny else 'default')
            command = [sys.executable, str(ROOT/'tools'/generator/'build.py'),
                       '--compiler-dir', str(args.compiler_dir.resolve()), '--output', str(out)]
            if tiny:command.append('--tiny')
            if kind == 'hislop':command += ['--reuse-textures', str(ROOT/'maps/as_hislop_tiny.bsp')]
            if not args.skip_build:subprocess.run(command, check=True, cwd=ROOT)
            if not tiny:apply_assault(out)
            manifest = json.loads((out/'manifest.json').read_text())
            assert manifest['id'] == 'as_'+kind+('_tiny' if tiny else '') and manifest['full_vis']
            manifest.update(horizontal_scale=[1.0,1.0] if tiny else [1.75,1.25] if kind=='hislop' else [1.6,1.3],vertical_scale=1.0)
            (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
            bsp = out/'maps'/(manifest['id']+'.bsp')
            assert hashlib.sha256(bsp.read_bytes()).hexdigest() == manifest['sha256']
            variants.append((manifest,out,ROOT/'maps'/metadata_name/('Tiny' if tiny else '')))
    if args.install:
        path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(path.read_text())
        for manifest,out,metadata in variants:
            map_id=manifest['id'];bsp=out/'maps'/(map_id+'.bsp')
            shutil.copy2(bsp,ROOT/'maps'/bsp.name)
            metadata.mkdir(parents=True,exist_ok=True)
            for name in ['manifest.json','texture-sources.json']:shutil.copy2(out/name,metadata/name)
            for f in (out/'licenses').glob('*'):shutil.copy2(f,metadata/f.name)
            row=dict(id=map_id,title=manifest['title'],modes=['as'],path='res://maps/'+bsp.name,
                     scene='res://maps/cache/'+map_id+'.scn',sha256=manifest['sha256'],
                     recommended_players=manifest['recommended_players'],small_groups_only=manifest['small_groups_only'])
            index=next((i for i,r in enumerate(catalog) if r['id']==map_id),None)
            if index is None:catalog.append(row)
            else:catalog[index]=row
        catalog=[r for r in catalog if r['id'] not in ['as_hislop_layout_test','as_frigate_layout_test']]
        path.write_text(json.dumps(catalog,indent=2)+'\n')
        (ROOT/'maps/as_maplist.txt').write_text('as_hislop\nas_frigate\n')
        archive=ROOT/'test-results/assault-layouts/retired-test-ids';archive.mkdir(parents=True,exist_ok=True)
        for kind in ['hislop','frigate']:
            for folder,suffix in [('maps','.bsp'),('maps/navigation','.res')]:
                old=ROOT/folder/('as_'+kind+'_layout_test'+suffix)
                if old.exists():shutil.move(str(old),str(archive/old.name))
        subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),
                        '--log-file',str(ROOT/'test-results/assault-layouts/bake.log'),
                        '--script','res://tools/assault_layout_tests/bake.gd'], check=True, cwd=ROOT)
    report=dict(variants=[m for m,_,_ in variants],installed=args.install)
    (ROOT/'test-results/assault-layouts/build.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':main()
