"""Run the isolated 10/11 suite serially; never builds/publishes production assets."""
from pathlib import Path
import argparse,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/candidates1011';HERE=Path(__file__).resolve().parent

def run(command,name,timeout=600):
 with (OUT/(name+'.log')).open('w') as log:
  process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  started=time.monotonic()
  while process.poll() is None:
   if time.monotonic()-started>timeout or 'SCRIPT ERROR:' in (OUT/(name+'.log')).read_text():
    process.terminate()
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill();process.wait()
    raise SystemExit(f'{name} failed or timed out; see {OUT/(name+".log")}')
   time.sleep(.25)
  code=process.returncode
 text=(OUT/(name+'.log')).read_text()
 if code or 'SCRIPT ERROR:' in text or 'Shader compilation failed' in text:raise SystemExit(f'{name} failed; see {OUT/(name+".log")}')
 print(name,'passed',flush=True)
def godot(script,headless=False):
 return ['godot',*(['--headless'] if headless else []),'--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT),'--rendering-method','mobile','--log-file',str(OUT/(script+'-engine.log')),'--script','res://tools/lighting_experiment/candidates1011/'+script+'.gd']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['prepare','capture','render','fixtures','audit','all']);a=p.parse_args();OUT.mkdir(exist_ok=True)
 if a.phase in ['prepare','all']:
  for name in ['bake','make_importer']:run([sys.executable,str(HERE/(name+'.py'))],name)
  run(godot('export',True),'export')
  for name in ['materials','shaders']:run([sys.executable,str(HERE/(name+'.py'))],name)
 if a.phase in ['capture','all']:run(godot('capture'),'capture')
 if a.phase in ['fixtures','all']:run(godot('fixtures'),'fixtures')
 if a.phase in ['render','all']:run(godot('render'),'render')
 if a.phase in ['audit','all']:run(godot('draw_audit'),'draw_audit')
if __name__=='__main__':main()
