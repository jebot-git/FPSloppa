"""Theme maintained LibreQuake/TF BSPs, preserving originals and all nontexture lumps."""
from pathlib import Path
import argparse
import json
import shutil
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from makkon.theme import makkon, replace, bsp_textures, name, sha


def build(install=False):
    originals=ROOT/'tools/makkon/local/maintained-originals';originals.mkdir(parents=True,exist_ok=True)
    out=ROOT/'test-results/map-texture-audit/maintained/maps';out.mkdir(parents=True,exist_ok=True)
    donors,sources=makkon()
    crosswalk=json.loads(Path(__file__).with_name('shared.json').read_text())['librequake']
    paths=[ROOT/'maps'/f'lqdm{i}.bsp' for i in range(1,9)]
    paths+=list((ROOT/'optional-map-pack').glob('*.bsp'))+list((ROOT/'optional-tf-map-pack').glob('*.bsp'))
    report=[]
    receipt=ROOT/'docs/validation/maintained-textures.json'
    previous={row['id']:row for row in json.loads(receipt.read_text())} if receipt.exists() else {}
    for path in paths:
        backup=originals/path.name
        if not backup.exists():shutil.copy2(path,backup)
        assert sha(path.read_bytes()) in [sha(backup.read_bytes()),previous.get(path.stem,{}).get('sha256')], 'Map changed since last theme build; review and update the preserved source explicitly: '+str(path)
        raw=backup.read_bytes();old=bsp_textures(raw)
        mapping={name(tile):crosswalk[name(tile)] for tile in old if tile and name(tile) in crosswalk}
        updated=replace(raw,{key:donors[value] for key,value in mapping.items()})
        # Every resulting record is either an exact original tile or an exact
        # Makkon donor; no source image is recoloured, resized or renamed.
        allowed=set(old)-{None};allowed.update(donors[value] for value in mapping.values())
        assert all(tile in allowed for tile in bsp_textures(updated) if tile)
        (out/path.name).write_bytes(updated)
        row=dict(id=path.stem,path=str(path.relative_to(ROOT)),source_sha256=sha(raw),sha256=sha(updated),
            bytes=len(updated),replacements=mapping,all_records_verified=True,nontexture_lumps_unchanged=True,
            textures={value:sources[value] for value in sorted(set(mapping.values()))})
        report.append(row)
        if install:
            path.write_bytes(updated)
            if path.parent.name=='optional-tf-map-pack':(ROOT/'maps'/path.name).write_bytes(updated)
    if install:
        catalog_path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(catalog_path.read_text())
        hashes={r['id']:r['sha256'] for r in report}
        for row in catalog:
            if row['id'] in hashes:row['sha256']=hashes[row['id']]
        catalog_path.write_text(json.dumps(catalog,indent=2)+'\n')
        for folder in [ROOT/'maps/Makkon',ROOT/'optional-map-pack',ROOT/'optional-tf-map-pack']:
            relevant=[r for r in report if r['path'].startswith('maps/' if folder.name=='Makkon' else folder.name+'/')]
            (folder/'texture-theme.json').write_text(json.dumps(relevant,indent=2)+'\n')
            shutil.copy2(Path(__file__).with_name('Makkon_License.txt'),folder/'Makkon_License.txt')
        for folder in ['optional-map-pack','optional-tf-map-pack']:
            p=ROOT/folder/'manifest.json';data=json.loads(p.read_text());rows=data['maps'] if isinstance(data,dict) else data
            for row in rows:
                if row['id'] in hashes:
                    row.setdefault('pre_makkon_sha256',row['sha256']);row['sha256']=hashes[row['id']]
                    row['texture_theme']='Original Makkon metal/industrial records; see texture-theme.json. Remaining original LibreQuake art unchanged.'
            p.write_text(json.dumps(data,indent=2)+'\n')
    (ROOT/'docs/validation/maintained-textures.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MAINTAINED_TEXTURES',len(report),'maps;',sum(len(r['replacements']) for r in report),'texture slots;', 'installed' if install else 'review copies only')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true')
    build(parser.parse_args().install)
