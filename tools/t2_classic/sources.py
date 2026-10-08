#!/usr/bin/env python3
"""Fetch pinned Classic mission, terrain and DIF geometry inputs; never execute missions."""
from pathlib import Path
import argparse, concurrent.futures, hashlib, json, re, subprocess, urllib.request
HERE=Path(__file__).resolve().parent
LOCAL=HERE/'local'
COMMIT='abe5198e5020554fe1f1620231c188d48f00f045'
BASE=f'https://raw.githubusercontent.com/exogen/t2-mapper/{COMMIT}/'
PACK='docs/base/@vl2/Classic_maps_v1.vl2/'

def parse(source):
    # A non-executing object/field reader. Comments and quoted strings are tokens,
    # so braces or "new" inside a mission quote cannot create phantom entities.
    pattern=re.compile(r'//[^\n]*|/\*.*?\*/|new\s+(\w+)\s*\(([^)]*)\)\s*\{|([\w]+(?:\[\d+\])?)\s*=\s*("(?:\\.|[^"\\])*"|[^;{}]+)\s*;|\};',re.S)
    stack=[];result=[]
    for m in pattern.finditer(source):
        if m[0].startswith(('//','/*')):continue
        if m[1]:stack.append({'class':m[1],'name':m[2].strip(),'parents':[r['name'] for r in stack]})
        elif m[3] and stack:
            value=m[4].strip()
            stack[-1][m[3]]=value[1:-1] if value.startswith('"') else value
        elif m[0]=='};' and stack:result.append(stack.pop())
    if stack:raise ValueError('Unclosed mission objects')
    return result

def fetch(path):
    out=LOCAL/path
    if not out.exists():
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_bytes(urllib.request.urlopen(BASE+urllib.parse.quote(path,safe='/@'),timeout=90).read())
    return out

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--node',default='node');a=parser.parse_args()
    LOCAL.mkdir(parents=True,exist_ok=True)
    tree=LOCAL/'tree.json'
    if not tree.exists():tree.write_bytes(urllib.request.urlopen(f'https://api.github.com/repos/exogen/t2-mapper/git/trees/{COMMIT}?recursive=1',timeout=90).read())
    paths=[r['path'] for r in json.loads(tree.read_text())['tree'] if r['type']=='blob']
    missions=sorted(p for p in paths if p.startswith(PACK+'missions/') and p.endswith('.mis'))
    def resolve(name,folder):
        name=name.replace('\\','/').split('/')[-1].lower()
        found=[p for p in paths if p.lower().endswith('/'+name) and '/'+folder+'/' in p.lower()]
        found.sort(key=lambda p:(not p.startswith(PACK),not p.startswith('docs/base/@vl2/'+folder+'.vl2/'),len(p),p))
        if not found:raise ValueError(f'Missing {folder}/{name}')
        return found[0]
    manifest={'repository':'https://github.com/exogen/t2-mapper','commit':COMMIT,'catalog':'https://playt2.com/maps','pack':'Classic_maps_v1.vl2','maps':[],'files':{}}
    needed=set(missions)|{'src/dif/dif.ts'}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(fetch,missions))
    for path in missions:
        source=fetch(path).read_text(encoding='utf-8-sig');items=parse(source)
        title=re.search(r'//\s*DisplayName\s*=\s*([^\r\n]+)',source,re.I)[1].strip()
        terrain=next(r for r in items if r['class']=='TerrainBlock')
        ter=resolve(terrain['terrainFile'],'terrains');needed.add(ter)
        interiors={r['interiorFile']:resolve(r['interiorFile'],'interiors') for r in items if r['class']=='InteriorInstance'}
        needed.update(interiors.values())
        slug=re.sub('[^a-z0-9]','',title.lower())
        manifest['maps'].append({'id':'ctf_t2_'+slug,'title':title,'mission':path,'terrain':ter,'interiors':interiors,'existing':{'raindance':'ctf_raindance','stonehenge':'ctf_stonehenge'}.get(slug,'')})
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(fetch,sorted(needed)))
    for path in sorted(needed):manifest['files'][path]={'sha256':hashlib.sha256(fetch(path).read_bytes()).hexdigest(),'bytes':fetch(path).stat().st_size}
    lock=HERE/'sources.json'
    if lock.exists():
        previous=json.loads(lock.read_text())
        if previous!=manifest:raise ValueError('Pinned source receipt changed')
    else:lock.write_text(json.dumps(manifest,indent=2)+'\n')
    script="""import {parseDIF} from './src/dif/dif.ts';
import {readFileSync,writeFileSync} from 'node:fs';
const paths=JSON.parse(readFileSync('../sources.json','utf8')).files;
for (const path of Object.keys(paths).filter(p=>p.endsWith('.dif'))) {
 const b=readFileSync(path);const d=parseDIF(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)).interiors[0];
 for(const key of ['lightMaps','normalLightMapIndices','alarmLightMapIndices']) delete d[key];
 writeFileSync(path+'.json',JSON.stringify(d));
}
"""
    subprocess.run([a.node,'--experimental-strip-types','--input-type=module','-'],input=script,text=True,cwd=LOCAL,check=True)
    print(json.dumps({'maps':len(missions),'interiors':sum(p.endswith('.dif') for p in needed),'files':len(needed)}))
if __name__=='__main__':main()
