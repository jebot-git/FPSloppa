"""Capture current-game views of compiled source maps. Requires a graphical display."""
from pathlib import Path
import argparse,os,subprocess,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--match',default='qsrc_dm');a=p.parse_args();out=ROOT/'test-results/quake-source-previews';out.mkdir(parents=True,exist_ok=True)
for path in sorted(a.directory.resolve().glob('*.bsp')):
 if a.match not in path.stem:continue
 with (out/(path.stem+'.log')).open('w') as log:
  r=subprocess.run([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--path',str(ROOT),'--xr-mode','off','--rendering-method','gl_compatibility','--script','res://deathmatch/tests/quake_source_preview.gd','--',str(path),str(out/path.stem)],stdout=log,stderr=subprocess.STDOUT,timeout=180)
 print(path.stem,r.returncode,flush=True)
 if r.returncode:raise SystemExit(r.returncode)
 text=(out/(path.stem+'.log')).read_text()
 if 'ERROR:' in text:raise SystemExit('Engine error: '+path.stem)
 (out/(path.stem+'.json')).write_text(json.dumps({'map':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'views':'both teams: spawn and flag' if path.stem.startswith(('tf_','threewave_')) else 'four spread deathmatch spawns','images':[path.stem+'-spawn%d.png'%i for i in range(4)]},indent=2))
