"""Check exported PCK/APK payloads independently of the source asset directory."""
from pathlib import Path
import os,subprocess,tempfile,json,zipfile,shutil
root=Path(__file__).resolve().parents[1];builds=root.parent/'Builds';reports=[]
godot=os.environ.get('GODOT_BIN') or shutil.which('godot') or str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')
with tempfile.TemporaryDirectory(prefix='fpsloppa-pack-audit-') as tmp:
 project=Path(tmp);(project/'project.godot').write_text('config_version=5\n')
 shutil.copy2(root/'deathmatch/tests/package_contents.gd',project/'audit.gd')
 for folder,name in [('Linux','FPSloppa.pck'),('Windows','FPSloppa.pck'),('Server','FPSloppaServer.pck')]:
  result=subprocess.run([godot,'--headless','--xr-mode','off','--path',tmp,'--script',str(project/'audit.gd'),'--',str(builds/folder/name)],capture_output=True,text=True,timeout=90)
  (root/'test-results'/('release05-pack-'+folder+'.log')).write_text(result.stdout+result.stderr)
  lines=[s for s in result.stdout.splitlines() if s.startswith('PACKAGE_AUDIT ')]
  assert result.returncode==0 and lines and 'SCRIPT ERROR' not in result.stderr and 'ERROR:' not in result.stderr,result.stdout+result.stderr
  reports.append(json.loads(lines[-1].split(' ',1)[1]));print(folder,'PCK passed',flush=True)
for target in ['Quest','Pico']:
 path=builds/'Android'/('FPSloppa-'+target+'.apk')
 with zipfile.ZipFile(path) as archive:
  assert archive.testzip() is None
  forbidden=[n for n in archive.namelist() if Path(n).suffix.lower() in ['.bsp','.vrm','.pak'] or 'AD-NOTICES' in n or Path(n).name.startswith('ad_arena_')]
  assert not forbidden,forbidden
  for name in ['flame.json','flame2.json','LICENCE.txt','CREDITS.txt','SOURCES.json']:assert 'assets/deathmatch/maps/librequake-props/'+name in archive.namelist(),name
  reports.append({'apk':str(path),'files':len(archive.namelist()),'failures':[]});print(target,'APK passed',flush=True)
(root/'test-results/release05-pack-audit.json').write_text(json.dumps(reports,indent=2)+'\n')
