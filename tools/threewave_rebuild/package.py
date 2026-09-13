"""Package only authored maps and approved materials, with hash-bound test receipts."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'maps/CTFStudies'
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    manifests=[json.loads(p.read_text()) for p in sorted(OUT.glob('ctf_*/manifest.json'))]
    assert len(manifests)==6
    catalog={r['id']:r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())}
    files=[];reports=[]
    for m in manifests:
        key=m['id'];bsp=ROOT/'maps'/(key+'.bsp');digest=sha(bsp.read_bytes())
        assert digest==m['sha256']
        assert catalog[key]['sha256']==digest and catalog[key]['modes']==['ctf']
        assert sha((OUT/key/(key+'.map')).read_bytes())==m['source_sha256']
        assert (OUT/key/'navigation-sha256.txt').read_text().strip()==digest
        audit=json.loads((OUT/key/'texture-audit.json').read_text());assert audit['sha256']==digest
        phases={}
        for phase in ['static','walk','routes','bots','views']:
            path=ROOT/'test-results/threewave'/key/(phase+'.json');r=json.loads(path.read_text())
            assert r['sha256']==digest,(key,phase,'stale test')
            assert not r['failures'],(key,phase,r['failures'])
            log=path.with_suffix('.log').read_text();assert 'ERROR:' not in log,(key,phase,'engine error')
            phases[phase]=r
        report={'id':key,'sha256':digest,'tests':phases};reports.append(report)
        (OUT/key/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
        files.extend([bsp,ROOT/'maps/cache'/(key+'.scn'),ROOT/'maps/cache'/(key+'-lightmap1.scn'),ROOT/'maps/navigation'/(key+'.res')])
    # Explicit allowlist: reference downloads and converted originals cannot enter.
    files.extend(p for p in OUT.rglob('*') if p.is_file())
    files.append(ROOT/'maps/ctf_maplist.txt')
    files.append(ROOT/'test-results/threewave/index.html')
    for m in manifests:files.extend((ROOT/'test-results/threewave'/m['id']).glob('views-*.png'))
    files.extend(ROOT/'tools/threewave_rebuild'/f for f in ['README.md','reference-hashes.json','layouts.py','build.py','bake.gd','acceptance.gd','verify.py','install.py','package.py','gallery.py'])
    for path in files:
        assert 'local' not in path.relative_to(ROOT).parts
        assert not any(x in path.name.lower() for x in ['pak0','pak1','3wctfc'])
    receipts=[{'path':str(p.relative_to(ROOT)),'size':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(set(files))]
    result={'maps':[{'id':r['id'],'sha256':r['sha256']} for r in reports],'files':receipts,'limitations':['Solo reference walkthroughs were sampled, not watched continuously.','Authored adaptations are not exact original geometry.','One 60-second 4v4 bot smoke per map does not establish competitive balance.','No human multiplayer playtest or Quest performance test was performed.']}
    target=ROOT/'dist/FPSloppa-CTF-Studies.zip';target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(set(files)):z.write(p,str(p.relative_to(ROOT)))
        z.writestr('CTF-Studies-PACKAGE.json',json.dumps(result,indent=2)+'\n')
    result['archive']={'path':str(target.relative_to(ROOT)),'sha256':sha(target.read_bytes()),'size':target.stat().st_size}
    (ROOT/'docs/validation/threewave-ctf-studies.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['archive']))
if __name__=='__main__':main()
