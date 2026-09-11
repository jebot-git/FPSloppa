"""Package only the seven reviewed multiplayer source ports and their sources/licenses."""
from pathlib import Path
import hashlib,json,sys,zipfile
from verify import verify
ROOT=Path(__file__).resolve().parents[2]
def package(build):
    checked=verify(build);assert {r['id'] for r in checked}=={'qsrc_dm'+str(i) for i in range(1,8)}
    traversal=json.loads((ROOT/'test-results/quake-multiplayer-traversal/summary.json').read_text())
    for row in checked:
        result=next(r for r in traversal if r['name']==row['id'])
        assert result['sha256']==row['sha256'] and not result['failures'] and not result['engine_errors'] and result['exit_code']==0
    dest=build.parent/'FPSloppa-Quake-Multiplayer-Addon.zip'
    prefix='addons/quake-multiplayer/'
    with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for row in checked:z.write(build/'maps'/(row['id']+'.bsp'),'maps/'+row['id']+'.bsp')
        for filename in ['BUILD.json','COPYING-GPL-2.0.txt','ORIGINAL-README.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','LibreQuake-README-IMPORTANT-LICENCE-INFO.txt']:
            z.write(build/filename,prefix+filename)
        for sub in ['sources/original','sources/adapted','texture-dictionary']:
            for p in sorted((build/sub).glob('*')):
                if p.is_file() and p.suffix.lower() in ['.map','.wad','.txt','.json','.lmp','.md']:z.write(p,prefix+str(p.relative_to(build)))
        z.write(build/'sources/TEXTURE-SOURCES.json',prefix+'sources/TEXTURE-SOURCES.json')
        for sub in ['tools/quake_source','tools/texture_replacements','deathmatch/maps/texture_replacements']:
            for p in sorted((ROOT/sub).glob('*')):
                if p.is_file() and p.suffix in ['.py','.json','.md','.txt','.png','.lmp','.gd']:
                    z.write(p,prefix+str(p.relative_to(ROOT)))
        z.write(ROOT/'deathmatch/maps/palette.lmp',prefix+'deathmatch/maps/palette.lmp')
        z.write(ROOT/'tools/quake_source/README.md',prefix+'README.md')
        rotation=' '.join('qsrc_dm'+str(i) for i in range(1,7))
        cfg=[]
        for mode in ['dm','tdm','ig','ft','cc']:
            z.writestr('maps/'+mode+'_quake_maplist.txt',rotation.replace(' ','\n')+'\n')
            cfg.append('set '+mode+'_maplist "'+rotation+'"')
        z.writestr(prefix+'quake-maplists.cfg','\n'.join(cfg)+'\n')
        z.writestr(prefix+'VALIDATION.json',json.dumps({'textures':checked,'traversal':traversal},indent=2))
    with zipfile.ZipFile(dest) as z:
        bsps=[n for n in z.namelist() if n.endswith('.bsp')];assert len(bsps)==7 and all(n.startswith('maps/qsrc_dm') for n in bsps)
        assert len(z.namelist())==len(set(z.namelist()))
    dest.with_suffix('.sha256').write_text(hashlib.sha256(dest.read_bytes()).hexdigest()+'  '+dest.name+'\n')
    print(dest, dest.stat().st_size,'bytes')
if __name__=='__main__':package(Path(sys.argv[1]).resolve())
