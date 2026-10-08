"""Render every imported arena at 1080p using the actual runtime materials."""
from pathlib import Path
import hashlib,json,math,struct,subprocess,time
from build import ROOT,HERE,unpack,parse_entities
OUT=ROOT/'test-results/arena-gallery';OUT.mkdir(parents=True,exist_ok=True)
rows=json.loads((HERE/'conversions.json').read_text());plans=[]
for row in rows:
 parts,_=unpack((ROOT/'maps'/(row['id']+'.bsp')).read_bytes());bounds=struct.unpack_from('<6f',parts[14]);lo=[-bounds[4]/32,bounds[2]/32,-bounds[3]/32];hi=[-bounds[1]/32,bounds[5]/32,-bounds[0]/32];views=[]
 starts=[e for e in parse_entities(parts[0]) if e.get('classname')=='info_player_deathmatch']
 for i,e in enumerate(starts[:6]):
  q=list(map(float,e['origin'].split()));eye=[-q[1]/32,q[2]/32+.9,-q[0]/32];a=math.radians(float(e.get('angle','0')));target=[eye[0]-math.sin(a)*12,eye[1],eye[2]-math.cos(a)*12]
  views.append({'name':f'{i+4:02}-spawn-{i+1}','eye':eye,'target':target})
 plans.append({'id':row['id'],'mode':'dm','min':lo,'max':hi,'views':views})
(OUT/'plan.json').write_text(json.dumps(plans,indent=2)+'\n')
failures=[]
for row in rows:
 row=next(r for r in json.loads((HERE/'conversions.json').read_text()) if r['id']==row['id'])
 name=row['id'];prepared=ROOT/'test-results/arena-imports'/(name+'.json');deadline=time.monotonic()+1200
 while time.monotonic()<deadline:
  if prepared.exists() and json.loads(prepared.read_text()).get('bsp_sha256')==row['sha256']:break
  time.sleep(2)
 receipt=OUT/name/'renders.json'
 if receipt.exists() and json.loads(receipt.read_text()).get('bsp_sha256')==row['sha256']:print(name,'cached',flush=True);continue
 with (OUT/(name+'.log')).open('w') as f:
  try:code=subprocess.run([str(ROOT/'run.sh'),'--xr-mode','off','--audio-driver','Dummy','--rendering-method','mobile','--script','tools/arena_imports/render.gd','--',name],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=124
 if code or not receipt.exists() or 'MAP_GALLERY_DONE '+name not in (OUT/(name+'.log')).read_text():failures.append(name)
 print(name,code,flush=True)
print('Failed',failures,flush=True)
raise SystemExit(bool(failures))
