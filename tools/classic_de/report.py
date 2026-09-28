"""Collect current-map DE restoration checks into a compact retained receipt."""
import hashlib,json,struct,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/de-restoration'
def read(path):return json.loads(path.read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def test(log):
    text=(OUT/(log+'.log')).read_text()
    assert 'SCRIPT ERROR:' not in text and not any(l.startswith('FAIL ') for l in text.splitlines()),log
    return {'name':log,'checks':sum(l.startswith('PASS ') for l in text.splitlines()),'passed':True}
def main():
    names=['penetration-physics','penetration-combat','cover-runtime','cs16','objectives',
           'bot-behavior','network-server','network-client',
           'routes-dust','routes-nuke','routes-inferno','routes-aztec','routes-train']
    tests=[test(name) for name in names]
    maps=[];soaks=[]
    for name in ['dust2','nuke','inferno','aztec','train']:
        id='de_'+name+'_rebuilt';bsp=ROOT/'maps'/(id+'.bsp');raw=bsp.read_bytes()
        assert struct.unpack_from('<i',raw)[0]==29
        end=(max(o+n for o,n in struct.iter_unpack('<ii',raw[4:124]))+3)&~3
        assert raw[end:end+4]==b'BSPX';lumps={}
        for i in range(struct.unpack_from('<I',raw,end+4)[0]):
            key,offset,size=struct.unpack_from('<24sII',raw,end+8+i*32)
            lumps[key.rstrip(b'\0').decode()]=[offset,size]
        offset,size=lumps['FSLP_BALLISTICS'];data=json.loads(raw[offset:offset+size])
        assert 'RGBLIGHTING' in lumps and data['version']==1
        folder=ROOT/('maps/Dust2Rebuilt' if name=='dust2' else 'maps/ClassicDE/'+id)
        manifest=read(folder/'manifest.json');assert manifest['full_vis']
        assert read(ROOT/'deathmatch/maps/defusal.json')[id]['sha256']==sha(bsp)
        cache=read(ROOT/'test-results/de-texturing'/(id+'-assets.json'))
        assert cache['bsp_sha256']==sha(bsp) and cache['invalid_faces']==cache['overflow_faces']==0
        assert {c['format'] for c in cache['codecs']}=={'bc7','astc4'}
        maps.append({'id':id,'sha256':sha(bsp),'bsp_bytes':len(raw),'metadata_bytes':size,
                     'static_brushes':len(data['static']),'moving_leaves':len(data['movers']),
                     'full_vis':True,'compressed_caches':['bc7','astc4'],'navigation_sha256':sha(ROOT/'maps/navigation'/(id+'.res'))})
        soak=read(ROOT/'test-results/de-bot-review'/('restoration-'+id+'.json'))
        assert soak['completed'] and soak['rounds']==6 and soak['map_sha256']==sha(bsp)
        assert all(len(s['bots'])==12 for s in soak['samples']) and len(soak['spawn_exits'])==72
        soaks.append({'map':id,'completed':True,'rounds':6,'simulation_seconds':soak['seconds'],
                      'scores':soak['scores'],'roster':12,'spawn_exits':72,
                      'max_spawn_exit_seconds':max(row['seconds'] for row in soak['spawn_exits'])})
    test('bot-soak')
    markings=read(ROOT/'test-results/de-site-markings/surface-audit.json');assert len(markings)==10
    native=(OUT/'native-views.log').read_text();assert 'SCRIPT ERROR' not in native and native.count('DE_SITE_VISUAL_PASS')==5
    assets=read(ROOT/'deathmatch/assets/base_manifest.json');archive=OUT/'Base-Assets.zip'
    assert sha(archive)==assets['sha256']
    with zipfile.ZipFile(archive) as z:
        for row in assets['files']:
            assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256'],row['path']
    report={'passed':True,'date':'2026-09-27','checks':sum(r['checks'] for r in tests),
            'tests':tests,'maps':maps,'site_markings':markings,
            'bot_series':soaks,'completed_rounds':30,'simulation':'Ordinary 60 Hz physics, accelerated offline pacing; six rounds/map, sides swapped after three',
            'query_probe':read(OUT/'cover-runtime.json')['maps'],
            'network':'Actual loopback ENet: late join, partial mover positions, round resets, demo state and AK damage through Nuke timber',
            'archive':{'path':str(archive.relative_to(ROOT)),'sha256':assets['sha256'],'bytes':archive.stat().st_size,'all_entry_hashes_verified':True},
            'limits':['Approximate reconstructed layouts, not exact retail geometry or GoldSrc penetration parity.',
                      'No player penetration, breakable surfaces, hinged doors or rotating/scaled penetration movers.',
                      'Geometry/CPU queries and desktop rendering checked; no headset frame-time benchmark.',
                      'Some Godot harnesses report shutdown ObjectDB/resource warnings.']}
    target=ROOT/'docs/validation/de-restoration-2026-09-27.json'
    target.write_text(json.dumps(report,indent=2)+'\n');print(target,report['checks'],'checks; 30 completed 6v6 rounds; archive verified')
if __name__=='__main__':main()
