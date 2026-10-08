from pathlib import Path
import json,struct,math,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'tools/arena_imports'));from build import unpack,parse_entities
for name in sys.argv[1:]:
 folder=HERE/'local/candidates'/(name if name.startswith('as_ut_') else 'koth_ut_'+name);path=folder/(folder.name+'.bsp');parts,_=unpack(path.read_bytes());entities=parse_entities(parts[0]);bounds=struct.unpack_from('<6f',parts[14]);lo=[-bounds[4]/32,bounds[2]/32,-bounds[3]/32];hi=[-bounds[1]/32,bounds[5]/32,-bounds[0]/32];views=[]
 for i,e in enumerate([x for x in entities if x.get('classname') in ['info_player_team1','info_player_team2']][:6]):
  q=list(map(float,e['origin'].split()));eye=[-q[1]/32,q[2]/32+.9,-q[0]/32];a=math.radians(float(e.get('angle','0')));target=[eye[0]-math.sin(a)*12,eye[1],eye[2]-math.cos(a)*12];views.append(dict(name=f'{i+4:02}-spawn-{i+1}',eye=eye,target=target))
 hills=[x for x in entities if x.get('classname')in ['info_koth_control','info_as_objective']]
 for i,e in enumerate(hills[:3]):
  q=list(map(float,e['origin'].split()));eye=[-q[1]/32,q[2]/32+.9,-q[0]/32];target=[eye[0]+5,eye[1]-.5,eye[2]+10];views.append(dict(name=f'{10+i:02}-'+('objective' if name.startswith('as_ut_') else 'hill')+f'-{i+1}',eye=eye,target=target))
 (folder/'render-plan.json').write_text(json.dumps(dict(mode='as' if name.startswith('as_ut_') else 'koth',min=lo,max=hi,views=views)))
 out=ROOT/('test-results/as-gallery' if name.startswith('as_ut_') else 'test-results/koth-gallery');out.mkdir(exist_ok=True)
 with (out/(folder.name+'.log')).open('w') as f:run=subprocess.run([str(ROOT/'run.sh'),'--xr-mode','off','--audio-driver','Dummy','--rendering-method','mobile','--script','tools/unreal_imports/render.gd','--','res://'+str(path.relative_to(ROOT))],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=180)
 print(name,run.returncode,flush=True)
