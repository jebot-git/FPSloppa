"""Rebuild the five original UT99 player archetypes from prior extractor jobs.
Authored topology regions keep all limb vertices in constrained hybrid IK.
No Unreal packages/extractor binaries are included in the shipped game.
"""
import argparse,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from convert import read_mesh,write_avatar
from soldier_ik import build as soldier

SPECS={
 'Soldier':dict(reference=25,skin=['blkt1','blkt2','blkt3','blkt4Malcom'],title='Male Soldier · Malcolm'),
 'Commando':dict(reference=25,skin=['cmdo1','cmdo2Blake','cmdo3','cmdo4'],title='Male Commando · Blake',body=[2],left=[3],right=[8],head=[5,6,13],neck=[],landmarks={'left':[[-.182,1.217,-.130],[-.115,.988,-.160],[.155,.801,-.200]],'right':[[.199,1.246,.129],[.193,1.00,.107],[.225,.835,-.090]],'neck':[.055,1.339,-.128],'head':[.060,1.425,-.190],'eye':[.070,1.515,-.270]}),
 'SGirl':dict(reference=609,skin=['army1','army2','army3','army4Lauren'],title='Female Soldier · Lauren',body=[0,1],left=[7,9,12,18,19],right=[8,2,16,17,21],head=[13,14,20,22,23],neck=[3],landmarks={'left':[[-.168,1.377,.072],[-.348,1.188,.084],[-.490,1.142,-.023]],'right':[[.121,1.377,.142],[.303,1.228,.215],[.472,1.225,.141]],'neck':[0,1.455,.025],'head':[.016,1.534,.043],'eye':[.060,1.610,-.043]}),
 'FCommando':dict(reference=609,skin=['cmdo1','cmdo2','cmdo4Anna'],title='Female Commando · Anna',body=[1,7],left=[15,16],right=[14,13],head=[3,5,9,17,18],neck=[],landmarks={'left':[[-.181,1.355,.110],[-.329,1.17,.093],[-.474,1.12,-.025]],'right':[[.174,1.360,.166],[.325,1.207,.231],[.467,1.20,.134]],'neck':[.02,1.445,.070],'head':[.035,1.535,.060],'eye':[.055,1.603,-.032]}),
 'Boss':dict(reference=25,skin=['boss1','boss2','boss3','boss4Xan','boss4Xan'],title='Boss · Xan Kriegor',body=[0,1],left=[11],right=[4],head=[6,7,12],neck=[],landmarks={'left':[[-.222,1.325,-.144],[-.185,1.045,-.161],[.162,.795,-.236]],'right':[[.224,1.352,.149],[.220,1.025,.132],[.213,.825,-.102]],'neck':[.032,1.350,-.070],'head':[.032,1.443,-.090],'eye':[.032,1.540,-.245]}),
}
def topology(p,corners):
 f=np.asarray([c[0] for c in corners]).reshape(-1,3);adj=[set() for _ in p]
 for tri in f:
  for i in tri:adj[i].update(int(n) for n in tri)
 seen=set();parts=[]
 for i in range(len(p)):
  if i in seen:continue
  todo=[i];part=set()
  while todo:
   n=todo.pop()
   if n in part:continue
   part.add(n);todo.extend(adj[n]-part)
  seen|=part
  if len(part)>1:parts.append(sorted(part))
 return parts

def authored_ik(positions,corners,spec):
 p=positions[spec['reference']];parts=topology(p,corners)
 labels=[set() for _ in p]
 for n,ids in enumerate(parts):
  for i in ids:labels[i].add(n)
 _,inverse=np.unique(np.round(p,5),axis=0,return_inverse=True)
 groups=[np.flatnonzero(inverse==n) for n in range(inverse.max()+1)]
 for ids in groups:
  merged=set().union(*(labels[int(i)] for i in ids))
  for i in ids:labels[int(i)]=merged
 profile=dict(spec['landmarks']);body=set(spec['body']);socket_ids=[]
 for key in ['left','right','neck']:
  point=np.array(profile[key][0] if key!='neck' else profile['neck'])
  eligible=[i for i,regions in enumerate(labels) if regions&body]
  # Three nearby torso points anchor translation, with an authored bind offset.
  distinct={int(inverse[i]):i for i in eligible}
  ids=sorted(distinct.values(),key=lambda i:np.linalg.norm(p[i]-point))[:3]
  socket_ids.append(ids)
 rows=[]
 for frame in positions:
  row=[]
  for key,ids in zip(['left','right','neck'],socket_ids):
   rest=np.array(profile[key][0] if key!='neck' else profile['neck'])
   row.extend((frame[ids].mean(0)+rest-p[ids].mean(0)).tolist())
  rows.append(row)
 profile['sockets']=rows;weights=[]
 if spec['reference']==609:
  # Dead9's first frame exposes both arms but carries a 58-degree head tilt.
  # Fit the rigid head to standing Breath1; preserve the original vertex frames.
  rigid=[13,14] if spec['title'].startswith('Female Soldier') else [5,17]
  ids=[i for part in rigid for i in parts[part] if p[i,1]>1.54]
  old=p[ids];neutral=positions[25,ids]
  u,_,v=np.linalg.svd((old-old.mean(0)).T@(neutral-neutral.mean(0)))
  rotation=v.T@u.T
  assert np.linalg.det(rotation)>.99
  qw=np.sqrt(1+np.trace(rotation))/2
  profile['head_correction']=[float((rotation[2,1]-rotation[1,2])/(4*qw)),float((rotation[0,2]-rotation[2,0])/(4*qw)),float((rotation[1,0]-rotation[0,1])/(4*qw)),float(qw)]
 def segment_distance(point,a,b):
  delta=b-a;t=np.clip(np.dot(point-a,delta)/np.dot(delta,delta),0,1)
  return np.linalg.norm(point-(a+t*delta))
 for point,regions in zip(p,labels):
  code=0;t=0.;amount=0.
  for side,number in [('left',1),('right',2)]:
   if not regions&set(spec[side]):continue
   code=number;amount=0. if regions&body else 1.
   shoulder,elbow,hand=map(np.array,profile[side])
   a=segment_distance(point,shoulder,elbow);b=segment_distance(point,elbow,hand)
   t=float(np.clip(.5+(a-b)/.09,0,1))
   # Remove shoulder shearing near the attachment ring.
   if amount and np.linalg.norm(point-shoulder)<.095:amount=float(np.clip(np.linalg.norm(point-shoulder)/.065,0,1))
   break
  if regions&(set(spec['head'])|set(spec['neck'])):
   code=3;amount=0. if regions&body else 1.
   neck=np.array(profile['neck']);head=np.array(profile['head']);t=float(np.clip((point[1]-neck[1])/(head[1]-neck[1]),0,1))
   # Long hair/antenna attachments follow the head as one rigid piece.
   if regions&({13,14,20,22,23} if spec['title'].startswith('Female Soldier') else {3,5,17,18} if spec['title'].startswith('Female Commando') else {6,13} if spec['title'].startswith('Male Commando') else {6,12}):t=1.
  weights.append([code,t,amount])
 for ids in groups:assert all(weights[i]==weights[ids[0]] for i in ids)
 return profile,weights,{'parts':[len(c) for c in parts],'socket_vertex_ids':socket_ids,'regions':{str(code):sum(w[0]==code for w in weights) for code in range(4)}}

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--extracted',type=Path,default=Path('test-results/ut99/base'));args=parser.parse_args()
 manifest=Path('deathmatch/avatars/models/manifest.json');rows=[r for r in json.loads(manifest.read_text()) if not r.get('base_model')]
 reports=[]
 for model,spec in SPECS.items():
  d=json.loads((args.extracted/model/'result.json').read_text());positions,corners,clips,ref=read_mesh(Path(d['mesh']),reference=spec['reference'])
  texts={Path(t).stem.lower():Path(t) for t in d['textures']}
  skins={slot:Image.open(texts[name.lower()]) for slot,name in enumerate(spec['skin'])}
  if model=='Soldier':ik=soldier(positions,corners);report={'regions':{str(code):sum(w[0]==code for w in ik[1]) for code in range(4)}}
  else:
   profile,weights,report=authored_ik(positions,corners,spec);ik=(profile,weights)
  output=Path('deathmatch/avatars/models/base')/(model.lower()+'.utavatar');output.parent.mkdir(exist_ok=True)
  info=write_avatar(output,positions,corners,skins,clips,'UT99 · '+spec['title'],'Epic Games / Digital Extremes','Original UT99 game asset terms; no CC0 claim',ref,None,ik)
  info.update(path='res://'+output.as_posix(),base_model=model,default_skin_slots=spec['skin'],source='Local original UT99 GOTY BotPack and matching skin package')
  rows.append(info);report.update(model=model,vertices=len(positions[0]),frames=len(positions),triangles=len(corners)//3,reference=ref,skin_slots=spec['skin'],hash=info['hash']);reports.append(report)
 manifest.write_text(json.dumps(rows,indent=2)+'\n');(args.extracted/'conversion-report.json').write_text(json.dumps(reports,indent=2)+'\n');print(json.dumps(reports,indent=2))
if __name__=='__main__':main()
