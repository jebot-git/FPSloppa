"""Compile GPL Quake map sources using the licensed shared texture dictionary. Tool: CC0."""
from pathlib import Path
import argparse,collections,concurrent.futures,hashlib,json,re,shutil,struct,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
URL='https://rome.ro/s/1996-quake-map-sources.zip'
def sha(d):return hashlib.sha256(d).hexdigest()
def blocks(text):
    depth=0;result=[];start=0
    for m in re.finditer(r'^\s*([{}])\s*$',text,re.M):
        if m[1]=='{':
            if depth==0:start=m.start()
            depth+=1
        else:
            depth-=1
            if depth==0:result.append(text[start:m.end()].strip())
    assert depth==0
    return result
def fields(block):return dict(re.findall(r'^"([^"\n]+)"\s*"([^"\n]*)"',block,re.M))
def setkey(block,key,value):
    pattern=r'^"'+re.escape(key)+r'"\s*"[^"\n]*"'
    return re.sub(pattern,lambda _:f'"{key}" "{value}"',block,flags=re.M) if re.search(pattern,block,re.M) else block.replace('{','{\n"'+key+'" "'+value+'"',1)
def build(a):
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);src=out/'sources';original=src/'original';adapted=src/'adapted';maps=out/'maps';logs=out/'logs'
    for p in [original,adapted,maps,logs]:p.mkdir(parents=True,exist_ok=True)
    archive=a.archive.read_bytes()
    if sha(archive)!='c2f0660617264e0918edc4a7c34dc66692ef396f2308c6cf9b6d12cfe595db7c':raise ValueError('Archive does not match the reviewed GPL source release')
    with zipfile.ZipFile(a.archive) as z:
        for n in z.namelist():
            if re.fullmatch(r'DM[1-7]\.MAP',n) or n in ['gnu.txt','release_readme.txt']:(original/n).write_bytes(z.read(n))
    shutil.copy2(original/'gnu.txt',out/'COPYING-GPL-2.0.txt');shutil.copy2(original/'release_readme.txt',out/'ORIGINAL-README.txt')
    pack=ROOT/'deathmatch/maps/texture_replacements'
    packed=(pack/'replacement-miptex.lmp').read_bytes()
    provenance=json.loads((pack/'manifest.json').read_text())['textures']
    textures={n:packed[r['offset']:r['offset']+r['size']] for n,r in provenance.items()}
    selected=sorted(p for p in original.glob('*.MAP') if re.fullmatch(r'DM[1-7]',p.stem))
    rows=[];used=set()
    for p in selected:
        if a.match and a.match.lower() not in p.stem.lower():continue
        text=p.read_text(encoding='latin1');result=[];changes=collections.Counter();mapping={}
        for block in blocks(text):
            e=fields(block);kind=e.get('classname','');flags=int(e.get('spawnflags','0'))
            if flags&2048 or kind.startswith('monster_') or kind in ['info_intermission','info_player_coop','item_key1','item_key2','item_sigil','trigger_changelevel','trigger_setskill','trigger_once','trigger_multiple','trigger_relay','trigger_counter','trigger_secret','info_null','event_lightning']:
                changes['removed '+kind]+=1;continue
            if kind=='worldspawn':
                for key,value in {'wad':'librequake.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'2048','_minlight':'36','_sunlight':'110','_sunlight2':'30','_sun_mangle':'0 -70 0','_bounce':'1','message':'Quake: '+e.get('message',p.stem)}.items():block=setkey(block,key,value)
            if kind.startswith('light'):
                # Bake switched lights on; FPSloppa does not execute Quake light-style programs.
                block=re.sub(r'^"(?:targetname|style)"[^\n]*\n?','',block,flags=re.M)
            if kind in ['func_door','func_door_secret']:
                block=setkey(block,'spawnflags',str(flags&~(8|16)));block=re.sub(r'^"(?:targetname|target|health)"[^\n]*\n?','',block,flags=re.M);changes['doors use proximity, unlocked']+=1
            if kind=='func_button':
                block=setkey(block,'classname','func_wall');changes['buttons static; progression removed']+=1
            result.append(block)
        def texture(m):
            old=m[2];new=old.lower();assert new in textures,"Missing reviewed counterpart: "+new;mapping[old]=provenance[new].get("librequake",provenance[new].get("generated"));used.add(new);return m[1]+new
        text=re.sub(r'(^\s*\([^\n]+?\)\s*\([^\n]+?\)\s*\([^\n]+?\)\s+)(\S+)',texture,'\n'.join(result)+'\n',flags=re.M)
        dest=adapted/('qsrc_'+p.stem.lower()+'.map');dest.write_text('// Modified for FPSloppa, 2026-09-11. GPL v2; see COPYING-GPL-2.0.txt.\n'+text)
        spawns=sum(fields(b).get('classname')=='info_player_deathmatch' for b in result)
        rows.append({'id':dest.stem,'original':p.name,'source_sha256':sha(p.read_bytes()),'adapted_sha256':sha(dest.read_bytes()),'spawns':spawns,'changes':dict(changes),'texture_mapping':mapping})
    if '+0button' in used:used.update(['+1button','+2button','+3button','+abutton'])
    wad=bytearray(b'WAD2'+bytes(8));directory=[]
    for name in sorted(used):
        tile=textures[name];offset=len(wad);wad.extend(tile);directory.append(struct.pack('<iiiBBH16s',offset,len(tile),len(tile),68,0,0,name.encode()))
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(adapted/'librequake.wad').write_bytes(wad)
    (src/'TEXTURE-SOURCES.json').write_text(json.dumps({n:provenance[n] for n in sorted(used)},indent=2)+'\n')
    for n in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO']:shutil.copy2(a.librequake.parent/'docs'/n,out/('LibreQuake-'+n+'.txt'))
    shutil.copytree(pack,out/'texture-dictionary',dirs_exist_ok=True)
    def compile_map(row):
        name=row['id'];path=adapted/(name+'.map');dest=maps/(name+'.bsp');print('COMPILE',name,flush=True)
        commands=[[str(a.compiler/'qbsp'),str(path),str(dest)],[str(a.compiler/'vis'),'-threads','2',str(dest)],[str(a.compiler/'light'),'-threads','2','-extra','-bspxlit',str(dest)]]
        try:
            for i,cmd in enumerate(commands):
                with (logs/(name+'-'+str(i)+'.log')).open('w') as log:r=subprocess.run(cmd,cwd=adapted,stdout=log,stderr=subprocess.STDOUT,timeout=180)
                if r.returncode:raise ValueError('Compiler stage '+str(i)+' exit '+str(r.returncode))
            data=dest.read_bytes();assert len(data)<=25_000_000;assert struct.unpack_from('<i',data)[0]==29
            row.update(status='compiled',sha256=sha(data),size=len(data))
        except Exception as e:row.update(status='failed',error=str(e))
        print('RESULT',name,row['status'],row.get('error',''),flush=True);return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(compile_map,rows))
    manifest={'source_url':URL,'archive_sha256':sha(archive),'license':'GPL-2.0 (maps), BSD-3-Clause (LibreQuake textures), generated original reliefs','compiler':'ericw-tools v0.18.1','maps':rows}
    (out/'BUILD.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--archive',required=True,type=Path);p.add_argument('--librequake',required=True,type=Path);p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--match',default='');build(p.parse_args())
