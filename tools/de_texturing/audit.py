"""Check DE material provenance, compiled map lineage and distribution hashes."""
from pathlib import Path
import argparse, hashlib, json, struct, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from makkon.theme import bsp_textures, name
from pressureworks.build import wad_records

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def planes(path):
    return '\n'.join(line[:line.rfind(')')+1] if line.startswith('( ') else line for line in path.read_text().splitlines())
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--baseline',type=Path);args=parser.parse_args()
    catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())
    rules=json.loads((ROOT/'deathmatch/maps/defusal.json').read_text())
    skies=json.loads((ROOT/'deathmatch/maps/skies/SOURCES.json').read_text())['map_sources']
    rows=[]
    for id in rules:
        folder=ROOT/('maps/Dust2Rebuilt' if id=='de_dust2_rebuilt' else 'maps/ClassicDE/'+id)
        bsp=ROOT/'maps'/(id+'.bsp');digest=sha(bsp)
        manifest=json.loads((folder/'manifest.json').read_text())
        assert digest==manifest['sha256']==rules[id]['sha256']==next(r['sha256'] for r in catalog if r['id']==id)
        assert (folder/bsp.name).read_bytes()==bsp.read_bytes() and skies[digest]==id
        assert manifest['full_vis'] and struct.unpack_from('<i',bsp.read_bytes())[0]==29 and bsp.stat().st_size<25_000_000
        wad=wad_records(folder/('dust2.wad' if id=='de_dust2_rebuilt' else 'classic.wad'))
        provenance=json.loads((folder/'texture-sources.json').read_text())
        embedded=bsp_textures(bsp.read_bytes())
        assert all(raw==wad[name(raw)] for raw in embedded if raw is not None)
        assert all(hashlib.sha256(raw).hexdigest()==provenance[n]['sha256'] for n,raw in wad.items())
        for row in provenance.values():
            if row.get('generator')=='built-in imagegen':assert sha(ROOT/row['source'])==row['source_sha256']
        assets=json.loads((ROOT/'test-results/de-texturing'/(id+'-assets.json')).read_text())
        assert assets['bsp_sha256']==digest and assets['invalid_faces']==assets['overflow_faces']==0
        assert {row['format'] for row in assets['codecs']}=={'bc7','astc4'}
        row=dict(map=id,sha256=digest,bytes=bsp.stat().st_size,textures=sum(raw is not None for raw in embedded),embedded_miptex_matches_source=True,full_vis=True,navigation_sha256=sha(ROOT/'maps/navigation'/(id+'.res')))
        if args.baseline:
            old=args.baseline/id
            assert planes(old/(id+'.map'))==planes(folder/(id+'.map')),id+' brush planes/entities changed'
            assert sha(old/(id+'.res'))==row['navigation_sha256']
            row.update(previous_sha256=sha(old/bsp.name),brush_planes_and_entities_preserved=True,navigation_preserved=True)
        rows.append(row);print('DE_MATERIAL_AUDIT_PASS',id,row['textures'],row['bytes'])
    (ROOT/'test-results/de-texturing/source-audit.json').write_text(json.dumps(rows,indent=2)+'\n')

if __name__=='__main__':main()
