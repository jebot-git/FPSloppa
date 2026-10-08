from pathlib import Path
import subprocess,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
reports=[]
for row in json.loads((HERE/'installed.json').read_text()):
 name=row['id'];log=ROOT/'test-results/arena-imports'/(name+'-prepare.log')
 with log.open('w') as f:
  code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/arena_imports/prepare.gd','--',name,'--keep-navigation'],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=600).returncode
 report=json.loads((ROOT/'test-results/arena-imports'/(name+'.json')).read_text());assert code==0 and not report['failures'],name
 reports.append(report);print(name,'bake+mips+BC7+ASTC verified',flush=True)
(HERE/'assets.json').write_text(json.dumps(reports,indent=2)+'\n')
