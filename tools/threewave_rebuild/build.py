"""Build six newly authored BSP29 CTF maps. Original ThreeWave files are NOT inputs."""
from pathlib import Path
import argparse, hashlib, json, re, struct, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from layouts import BUILDERS
from vesper.build import materials
OUT=ROOT/'maps/CTFStudies'
def sha(b):return hashlib.sha256(b).hexdigest()
def entity(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
def build(a,compiler,threads):
    target=OUT/a.name;target.mkdir(parents=True,exist_ok=True)
    logs=ROOT/'test-results/threewave'/a.name;logs.mkdir(parents=True,exist_ok=True)
    world={'classname':'worldspawn','message':a.title,'wad':'../materials.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_minlight':'28','_bounce':'1','worldtype':'0'}
    if a.name in ['ctf_confluence','ctf_skyfracture']:world['_fpsloppa_black_missing']='1'
    if a.sky:world.update(_sunlight='160',_sunlight2='48',_sun_mangle='35 -65 0')
    source='{\n'+entity(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'
    if a.detail:source+='{\n"classname" "func_detail"\n'+'\n'.join(a.detail)+'\n}\n'
    source+='\n'.join('{\n'+entity(fields)+'\n'+'\n'.join(brushes)+'\n}' for fields,brushes in a.models)+'\n'
    source+='\n'.join('{\n'+entity(e)+'\n}' for e in a.entities)+'\n'
    source='// Newly authored FPSloppa geometry. See ../README.md and material licences.\n'+source
    path=target/(a.name+'.map');path.write_text(source)
    names=set(re.findall(r'\) (\S+) [-\d.e+]+ [-\d.e+]+ 0 [\d.e+]+ [\d.e+]+',source))-{'trigger'}
    return {'a':a,'target':target,'logs':logs,'path':path,'names':names,'source':source}
def main():
    p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,default=Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin'));p.add_argument('--threads',type=int,default=4);p.add_argument('--only',type=int,nargs='*');p.add_argument('--source-only',action='store_true');args=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    jobs=[build(fn(),args.compiler,args.threads) for i,fn in enumerate(BUILDERS,1) if not args.only or i in args.only]
    names=set().union(*(j['names'] for j in jobs))
    # Preserve only textures still used by unselected maps during a partial build.
    if args.only:
        for source in OUT.glob('ctf_*/*.map'):
            names.update(re.findall(r'\) (\S+) [-\d.e+]+ [-\d.e+]+ 0 [\d.e+]+ [\d.e+]+',source.read_text()))
    names.discard('trigger')
    donors,provenance=materials(names);wad=bytearray(b'WAD2'+bytes(8));directory=[]
    # Invisible editor texture is authored here, so trigger-only models retain
    # valid bounds without a missing-texture fallback in the runtime importer.
    raw=struct.pack('<16s6I',b'trigger',16,16,40,296,360,376)+bytes([0])*340
    donors['trigger']=raw;names.add('trigger')
    provenance['trigger']={'source':'tools/threewave_rebuild/build.py','sha256':sha(raw),'license':'CC0-1.0','format':'generated invisible 16x16 editor miptex'}
    for name in sorted(names):
        raw=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (OUT/'materials.wad').write_bytes(wad);(OUT/'texture-sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
    for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','CC0-1.0.txt']:(OUT/name).write_bytes((ROOT/'maps/Pressureworks'/name).read_bytes())
    for j in jobs:
        a=j['a'];target=j['target'];bsp=ROOT/'maps'/(a.name+'.bsp')
        # Old leak markers must not mask a successful rebuild.
        bsp.with_suffix('.pts').unlink(missing_ok=True)
        if not args.source_only:
            for exe,flags in [('qbsp',[str(j['path']),str(bsp)]),('vis',['-threads',str(args.threads),str(bsp)]),('light',['-threads',str(args.threads),'-extra','-bspxlit',str(bsp)])]:
                with (j['logs']/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler.resolve()/exe),*flags],cwd=target,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
                assert not bsp.with_suffix('.pts').exists(),a.name+' leaked'
            data=bsp.read_bytes();assert struct.unpack_from('<i',data)[0]==29 and len(data)<25_000_000
            to,_=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,to)[0];audit=[]
            for i in range(count):
                offset=struct.unpack_from('<i',data,to+4+4*i)[0]
                if offset<0:continue
                at=to+offset;name=data[at:at+16].split(b'\0')[0].decode()
                if name=='trigger':continue
                assert name in donors and data[at:at+len(donors[name])]==donors[name],name
                audit.append({'name':name,'sha256':sha(donors[name])})
            (target/'texture-audit.json').write_text(json.dumps({'sha256':sha(data),'textures':audit},indent=2)+'\n')
        report={'id':a.name,'title':a.title,'original_reference':'ctf'+str(a.number),'sha256':sha(bsp.read_bytes()) if bsp.exists() else None,'source_sha256':sha(j['source'].encode()),'brushes':len(a.brushes),'rooms':len(a.rooms),'team_spawns':[len(s) for s in a.spawns],'flags':a.flags,'spawns':a.spawns,'views':a.views,'landmarks':a.landmarks,'routes':a.routes,'geometry':'newly authored; no original BSP geometry used as build input','textures':'../texture-sources.json'}
        (target/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('BUILT',a.name,'brushes',len(a.brushes),'rooms',len(a.rooms),flush=True)
if __name__=='__main__':main()
