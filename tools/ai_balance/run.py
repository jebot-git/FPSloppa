#!/usr/bin/env python3
"""Run the competitive study's priorities serially against an isolated project."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
GODOT='/tmp/fpsloppa-godot-official/Godot_v4.7.2-stable_linux.x86_64'
PHASES=['nav','koth','ctf','as','tf','cc_if']
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inputs(project):
 paths=[project/'project.godot',project/'deathmatch/arena.gd',project/'deathmatch/fighter.gd',project/'deathmatch/bots.gd']
 for folder in ['deathmatch/bot_ai','deathmatch/modes','deathmatch/movement','deathmatch/weapons','tools/ai_balance']:
  paths += list((project/folder).rglob('*.gd'))
 paths += [project/'maps'/(key+'.bsp') for key in ['qsrc_dm3','qsrc_dm6','koth_alichar','ctf_crownreach','as_frigate','tf_vesper','cc_basement']]
 paths += [project/'maps/navigation'/(key+'.res') for key in ['qsrc_dm3','qsrc_dm6','koth_alichar','ctf_crownreach','as_frigate','tf_vesper','cc_basement']]
 return {str(p.relative_to(project)):digest(p) for p in paths if p.is_file()}
def cases(phase):
 settings={'koth':('koth_alichar','koth','doom',600),'ctf':('ctf_crownreach','ctf','ut99',600),'as':('as_frigate','as','ut99',735),'tf':('tf_vesper','tf','quake',300),'cc':('cc_basement','cc','doom',300),'if':('qsrc_dm6','if','doom',300)}
 kinds=['cc','if'] if phase=='cc_if' else [phase]
 for kind in kinds:
  map_id,mode,rules,seconds=settings[kind]
  mixes={'balanced':['soldier','medic','engineer','scout'],'attack':['scout','scout','soldier','medic'],'heavy':['heavy','soldier','engineer','medic']} if kind=='tf' else {'default':[]}
  for mix,classes in mixes.items():
   for seed in ([7129] if kind=='tf' else [7129,9137]):
    for mirror in ([0] if kind=='cc' else [0,1]):
     key=f'{PHASES.index(phase)+1:02d}-{kind}-{mix}-{seed}-m{mirror}'
     yield key,dict(map=map_id,mode=mode,rules=rules,seconds=seconds,seed=seed,mirror=mirror,class_mix=classes,minutes=6 if kind=='as' else 60,profile_tick=True)
def main():
 p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);p.add_argument('--label',required=True);p.add_argument('--phase',choices=PHASES,required=True);p.add_argument('--resume',action='store_true');p.add_argument('--seconds',type=int);a=p.parse_args()
 out=ROOT/'test-results/ai-balance'/a.label;out.mkdir(parents=True,exist_ok=True)
 before=inputs(a.project);receipt=out/'inputs.json'
 if receipt.exists():assert json.loads(receipt.read_text())==before,'Isolated inputs changed; use a new label'
 else:receipt.write_text(json.dumps(before,indent=2)+'\n')
 trials=[('01-navigation-frozen',None)] if a.phase=='nav' else list(cases(a.phase))
 for key,opts in trials:
  path=out/(key+'.json');status=out/(key+'-status.json')
  if status.exists():
   previous=json.loads(status.read_text())
   if a.resume and previous['passed'] and path.exists():print('PRESERVED',key,flush=True);continue
   if not a.resume:raise RuntimeError('Existing trial; use --resume or a new label: '+key)
  if opts is not None:
   if a.seconds:opts['seconds']=a.seconds
   opts['output']=str(path);opts['input_receipt']='inputs.json'
  command=[GODOT,'--headless','--xr-mode','off','--fixed-fps','60','--path',str(a.project),'--script','res://tools/ai_balance/'+('navigation.gd' if opts is None else 'match.gd'),'--',str(path) if opts is None else json.dumps(opts)]
  start=time.monotonic();print('START',key,flush=True)
  with (out/(key+'.log')).open('w') as log:
   try:r=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ai-balance-data'),timeout=480);code=r.returncode
   except subprocess.TimeoutExpired:code=124
  errors=[s for s in (out/(key+'.log')).read_text().splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:'))]
  valid=code==0 and not errors and path.exists() and inputs(a.project)==before
  data=json.loads(path.read_text()) if valid else {}
  row={'case':key,'passed':valid,'exit_code':code,'errors':errors,'wall_seconds':round(time.monotonic()-start,2),'result_sha256':digest(path) if path.exists() else None}
  if opts is not None and valid:row.update(score=data['score'],simulated_seconds=data['simulated_seconds'],stage=data['as_stage'],checkpoint=data['as_checkpoint'],damage=data['balance']['damage_categories'],flag_takes=len(data['balance']['flag_carriers']))
  status.write_text(json.dumps(row,indent=2)+'\n');print(json.dumps(row),flush=True)
  if not valid:raise SystemExit(1)
if __name__=='__main__':main()
