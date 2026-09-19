"""Real renderer + headless server/uploader/viewer, each with an isolated asset root."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,tempfile,time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/map-previews';OUT.mkdir(parents=True,exist_ok=True)
godot=shutil.which('godot') or 'godot'
files=json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text())['files']
selected=[r for r in files if 'qsrc_dm1' in r['path'] or r['path'].startswith('vrm/')]
reports=[]
with tempfile.TemporaryDirectory(prefix='fps-map-previews-') as directory:
 temp=Path(directory)
 for case in ['tf_network_arena','untagged_arena']:
  source=temp/(case+'.bsp');source.write_bytes((ROOT/'maps/qsrc_dm6.bsp').read_bytes()+str(source).encode())
  digest=hashlib.sha256(source.read_bytes()).hexdigest()
  assets={role:temp/(case+'-'+role) for role in ['server','uploader','receiver']}
  for folder in assets.values():
   for entry in selected:
    target=folder/entry['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/entry['path'],target)
  def command(role,render=False):
   config=assets['uploader' if role=='prepare' else role]
   cmd=[godot,'--path',str(ROOT),'--xr-mode','off','--audio-driver','Dummy']
   cmd+=['--rendering-method','mobile','--rendering-driver','vulkan'] if render else ['--headless']
   return cmd+['--script','res://deathmatch/tests/map_preview_network.gd','--',role,str(source),digest,str(OUT/(case+'-'+role+'.json')),'--asset-root',str(config)]
  with (OUT/(case+'-prepare.log')).open('w') as log:
   prepared=subprocess.run(command('prepare',True),env=dict(os.environ,XDG_DATA_HOME=str(temp/'profiles-prepare')),stdout=log,stderr=subprocess.STDOUT,timeout=90)
  if prepared.returncode:raise SystemExit((OUT/(case+'-prepare.log')).read_text())
  preview=next((assets['uploader']/'maps/previews').glob('*.png'));shutil.copyfile(preview,OUT/(case+'-preview.png'))
  processes=[];handles=[]
  try:
   for role in ['server','uploader','receiver']:
    path=OUT/(case+'-'+role+'.log');log=path.open('w');handles.append(log)
    process=subprocess.Popen(command(role),env=dict(os.environ,XDG_DATA_HOME=str(temp/('profile-'+role))),stdout=log,stderr=subprocess.STDOUT)
    processes.append((role,process,path))
    if role=='server':
     deadline=time.monotonic()+20
     while time.monotonic()<deadline and process.poll() is None and 'DM_HOST_READY' not in path.read_text():time.sleep(.05)
   deadline=time.monotonic()+110
   for role,process,path in processes:
    process.wait(timeout=max(1,deadline-time.monotonic()))
    text=path.read_text();passed=process.returncode==0 and 'MAP_PREVIEW_NETWORK_RESULT' in text and 'SCRIPT ERROR' not in text
    reports.append({'case':case,'role':role,'passed':passed})
    print(case,role,passed,flush=True)
    if not passed:print(text[-6000:],flush=True)
  finally:
   for _,process,_ in processes:
    if process.poll() is None:process.terminate();process.wait(timeout=5)
   for handle in handles:handle.close()
 restart=temp/'restart'
 for entry in selected:
  target=restart/entry['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/entry['path'],target)
 with (OUT/'restart.log').open('w') as log:
  result=subprocess.run([godot,'--headless','--path',str(ROOT),'--xr-mode','off','--audio-driver','Dummy','--script','res://deathmatch/tests/map_import_restart.gd','--','--asset-root',str(restart)],env=dict(os.environ,XDG_DATA_HOME=str(temp/'profile-restart')),stdout=log,stderr=subprocess.STDOUT,timeout=45)
 passed=result.returncode==0 and 'MAP_IMPORT_RESTART_RESULT []' in (OUT/'restart.log').read_text()
 reports.append({'case':'ig_restart','role':'server','passed':passed})
 print('ig_restart server',passed,flush=True)
 if not passed:print((OUT/'restart.log').read_text()[-6000:])
(OUT/'network-summary.json').write_text(json.dumps(reports,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in reports) else 1)
