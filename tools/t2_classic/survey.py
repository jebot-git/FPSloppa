#!/usr/bin/env python3
"""Physics-survey marker clearances and apply reviewed bounded corrections.

Geometry is unchanged. QBSP -onlyents preserves lighting and visibility lumps.
Corrections are retained in placements.json and replayed by subsequent builds.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,math,struct
from sources import HERE,LOCAL,parse
ROOT=HERE.parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('map');p.add_argument('--pads',action='store_true');p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();key=a.map
 folder=ROOT/'maps/T2Classic'/key;log=ROOT/'test-results/t2-classic'/key
 with (log/'survey.log').open('w') as out:subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--script','tools/t2_classic/repair_pads.gd' if a.pads else 'tools/t2_classic/repair_points.gd','--',key],cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,check=True,timeout=180)
 repairs=json.loads((log/'repairs.json').read_text())['repairs']
 if not repairs:print(key,'no corrections');return
 probes=json.loads((folder/'probes.json').read_text());source=(folder/(key+'.map')).read_text()
 manifest=json.loads((HERE/'sources.json').read_text());entry=next(r for r in manifest['maps'] if r['id']==key)
 items=parse((LOCAL/entry['mission']).read_text());flag=next(r for r in items if r.get('dataBlock')=='FLAG' and any(x.lower()=='team1' for x in r['parents']))
 fx,fy,_=map(float,flag['position'].split());f=probes['flags'][0]['position'];center=[fx-f[0],fy+f[2]]
 path=HERE/'placements.json';saved=json.loads(path.read_text()) if path.exists() else {}
 def origin(v):return '%g %g %g'%(-v[2]*32,-v[0]*32,(v[1]+.7)*32)
 for row in repairs:
  old=' '.join(map(str,row['from'])) if a.pads else origin(row['from']);new=' '.join(map(str,row['to'])) if a.pads else origin(row['to'])
  # Replace only the exact matching point origin; portals sharing it move too.
  count=0
  def replace(m):
   nonlocal count
   if math.dist(list(map(float,m[2].split())),list(map(float,old.split())))<.2:
    count+=1;return m[1]+new+m[3]
   return m[0]
  field='vehicle_spawn' if a.pads else 'origin'
  source=re.sub(r'("'+field+r'"\s+")([^"\n]+)(")',replace,source)
  if not count:raise ValueError('Missing origin '+old)
  if not a.pads:probes[row['category']][row['index']]['position']=row['to']
  probes['portals']=[row['to'] if sum((a-b)**2 for a,b in zip(p,row['from']))<.001 else p for p in probes['portals']]
  def world(v):return [v[0]+center[0],center[1]-v[2],v[1]]
  saved.setdefault(key,[]).append({'from':world(row['from']),'to':world(row['to']),'reason':'Compiled capsule/floor survey','category':row['category']})
 (folder/(key+'.map')).write_text(source);(folder/'probes.json').write_text(json.dumps(probes,indent=2)+'\n');path.write_text(json.dumps(saved,indent=2)+'\n')
 bsp=ROOT/'maps'/(key+'.bsp')
 raw=bsp.read_bytes();lumps=[struct.unpack_from('<II',raw,4+i*8) for i in range(15)];at=(max(o+n for o,n in lumps)+3)&~3
 extensions=[]
 if raw[at:at+4]==b'BSPX':
  for i in range(struct.unpack_from('<I',raw,at+4)[0]):
   name,offset,length=struct.unpack_from('<24sII',raw,at+8+i*32);extensions.append((name,raw[offset:offset+length]))
 with (log/'onlyents.log').open('w') as out:subprocess.run([str(a.compiler/'qbsp'),'-bsp2','-onlyents',str(folder/(key+'.map')),str(bsp)],stdout=out,stderr=subprocess.STDOUT,check=True)
 # ericw 0.18.1 -onlyents drops BSPX; reattach unchanged lighting extensions.
 if extensions:
  raw=bytearray(bsp.read_bytes());raw.extend(bytes((-len(raw))%4));start=len(raw)
  raw.extend(b'BSPX'+struct.pack('<I',len(extensions))+bytes(32*len(extensions)))
  for i,(name,data) in enumerate(extensions):
   offset=len(raw);raw.extend(data);raw.extend(bytes((-len(raw))%4));struct.pack_into('<24sII',raw,start+8+i*32,name,offset,len(data))
  bsp.write_bytes(raw)
 report=json.loads((folder/'manifest.json').read_text());report.update(bsp_sha256=hashlib.sha256(bsp.read_bytes()).hexdigest(),bytes=bsp.stat().st_size,flags=probes['flags']);(folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 # Registration is run once after the build batch, avoiding competing writers.
 print(key,len(repairs),'bounded corrections',flush=True)
if __name__=='__main__':main()
