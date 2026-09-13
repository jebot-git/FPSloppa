#!/usr/bin/env python3
"""Install reviewed static bakes and prepared map caches with preserved lineage."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.lighting_experiment.bake import verify
from tools.makkon.theme import lumps

OUT = ROOT/'test-results/static-rendering'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    bake=json.loads((OUT/'bake.json').read_text())
    imported=json.loads((OUT/'import.json').read_text())
    rendered=json.loads((OUT/'mobile/render.json').read_text())
    assert not imported['failures'] and not rendered['failures']
    assert '"failures":[]' in (OUT/'unit.log').read_text()
    assert 'LIGHTING_PROFILE_RESULT []' in (OUT/'profile.log').read_text()
    catalog_path=ROOT/'deathmatch/maps/manifest.json'
    catalog=json.loads(catalog_path.read_text())
    base=[r for r in catalog if r.get('distribution','base')=='base']
    assert {r['id'] for r in base}=={r['id'] for r in imported['maps']}
    for row in imported['maps']:
        assert sha(OUT/'cache'/(row['id']+'.scn'))==row['cache_sha256']
    for row in bake['maps']:
        name=row['id'];original=OUT/'original'/(name+'.bsp');candidate=OUT/'candidate'/(name+'.bsp')
        assert sha(ROOT/'maps'/(name+'.bsp'))==row['original_sha256']==sha(original)
        assert sha(candidate)==row['sha256']
        verify(original.read_bytes(),candidate.read_bytes())
        row['navigation_sha256']=sha(ROOT/'maps/navigation'/(name+'.res'))
    backup=OUT/'installed-original';backup.mkdir(exist_ok=True)
    def save(path):
        target=backup/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
        assert not target.exists(), 'Already installed; refusing to replace baseline '+str(target)
        shutil.copyfile(path,target)
    save(catalog_path)
    for row in bake['maps']:
        name=row['id'];path=ROOT/'maps'/(name+'.bsp');save(path)
        shutil.copyfile(OUT/'candidate'/path.name,path)
        lit=path.with_suffix('.lit')
        if lit.exists():
            save(lit)
            _,extras=lumps(path.read_bytes())
            lit.write_bytes(b'QLIT\x01\x00\x00\x00'+dict(extras)[b'RGBLIGHTING'.ljust(24,b'\0')])
        next(r for r in catalog if r['id']==name)['sha256']=row['sha256']
        folder={'tf_pressureworks':'Pressureworks','tf_vesper':'VesperAbbey'}[name]
        manifest=ROOT/'maps'/folder/'manifest.json';save(manifest)
        data=json.loads(manifest.read_text());data['sha256']=row['sha256']
        data['static_refinement']={'original_sha256':row['original_sha256'],'receipt':'docs/validation/static-rendering.json'}
        manifest.write_text(json.dumps(data,indent=2)+'\n')
    for row in imported['maps']:
        for suffix in ['.scn','-lightmap1.scn']:
            path=ROOT/'maps/cache'/(row['id']+suffix)
            if path.exists():save(path)
            shutil.copyfile(OUT/'cache'/(row['id']+'.scn'),path)
    catalog_path.write_text(json.dumps(catalog,indent=2)+'\n')
    receipt={'status':'installed in project; packages not yet refreshed','bakes':bake,
        'prepared_maps':imported['maps'],'import_failures':imported['failures'],
        'render_failures':rendered['failures'],'renderer':rendered['renderer'],'gpu':rendered['gpu'],
        'measured_frames':rendered['measured_frames'], 'summary':json.loads((OUT/'summary.json').read_text()),
        'shader_sha256':sha(ROOT/'deathmatch/maps/baked_light.gdshader'),
        'mip_preparation_version':1,
        'limits':['Desktop Vulkan static views, not headset frame-time certification.',
                  'ADB reported no connected devices. No Quest/Pico run.',
                  'Two bake refinements; colour mips prepared for all 25 base maps.',
                  'Classic response unchanged; Contrast response refined; default remains Classic.',
                  'Original AO and gameplay/art validation receipts retain their historical hashes.']}
    (ROOT/'docs/validation/static-rendering.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('Installed 2 static bakes and 50 caches; navigation and source art preserved')

if __name__=='__main__':main()
