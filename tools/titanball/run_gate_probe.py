import argparse,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--label',default='before');a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=root/'test-results/titanball';out.mkdir(exist_ok=True)
with (out/f'gate-{a.label}.log').open('w') as log:
 result=subprocess.run(['godot','--path',str(root),'--xr-mode','off','--audio-driver','Dummy','--rendering-method','mobile','--rendering-driver','vulkan','--script','res://tools/titanball/gate_probe.gd','--',a.label],env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ba2-data'),stdout=log,stderr=subprocess.STDOUT,timeout=120)
text=(out/f'gate-{a.label}.log').read_text();print(text[-12000:]);raise SystemExit(result.returncode or (1 if 'SCRIPT ERROR:' in text else 0))
