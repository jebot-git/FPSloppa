"""Verify original records, minimal WAD contents and texture-only BSP changes."""
from pathlib import Path
import json
import struct
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from makkon.theme import makkon, wad_textures, bsp_textures, name, lumps, sha
from texture_replacements.convert import convert


def main():
    originals,_=makkon()
    proof=json.loads(Path(__file__).with_name('selection.json').read_text())
    pack=ROOT/'deathmatch/maps/texture_replacements'
    raw=(pack/'makkon-used.wad').read_bytes();selected=wad_textures(raw)
    assert sha(raw)==proof['sha256'] and set(selected)==set(proof['textures'])
    for key,tile in selected.items():assert tile==originals[key]
    used=set(proof['aliases'].values())
    paths=[ROOT/r['path'].removeprefix('res://') for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())]
    paths+=list((ROOT/'optional-map-pack').glob('*.bsp'))+list((ROOT/'optional-tf-map-pack').glob('*.bsp'))
    for path in paths:
        used.update(name(tile) for tile in bsp_textures(path.read_bytes()) if tile and name(tile) in selected)
    assert set(selected)==used, 'Unused or missing records in the shipped WAD'
    manifest=json.loads((pack/'manifest.json').read_text())
    for key,row in manifest['textures'].items():
        if row.get('pack')=='makkon-used.wad':
            assert raw[row['offset']:row['offset']+row['size']]==originals[row['makkon']]
    checked=[]
    # Exercise idempotence and preservation of solids, lightmap extents, VIS,
    # liquid/sky/animated semantic names, and all extra BSPX payloads.
    paths=list((ROOT/'test-results/map-texture-audit/originals').glob('threewave_*.bsp'))
    paths+=list((ROOT/'test-results/map-texture-audit/originals').glob('tf_original_*.bsp'))
    for path in paths:
        before=path.read_bytes();after,report=convert(before,True)
        assert convert(after,True)[0]==after
        old,bx=lumps(before);new,ax=lumps(after)
        assert bx==ax and all(old[i]==new[i] for i in range(15) if i!=2)
        old_tiles=bsp_textures(before);new_tiles=bsp_textures(after)
        for a,b in zip(old_tiles,new_tiles):
            if a and name(a).startswith(('*','sky','+','{')):assert name(a)==name(b)
        checked.append(path.name)
    maintained=json.loads((ROOT/'docs/validation/maintained-textures.json').read_text())
    for row in maintained:
        before=(ROOT/'tools/makkon/local/maintained-originals'/(row['id']+'.bsp')).read_bytes()
        after=(ROOT/row['path']).read_bytes()
        assert sha(before)==row['source_sha256'] and sha(after)==row['sha256']
        old,bx=lumps(before);new,ax=lumps(after)
        assert bx==ax and all(old[i]==new[i] for i in range(15) if i!=2)
    result=dict(passed=True,original_records=len(selected),wad_bytes=len(raw),wad_sha256=sha(raw),
        minimal_used_set=True,aliases=len(proof['aliases']),conversion_maps=checked,maintained_maps=len(maintained))
    (ROOT/'docs/validation/makkon-shared.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':main()
