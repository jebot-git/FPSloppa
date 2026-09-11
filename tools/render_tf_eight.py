"""Render the recorded TF ability simulation with phase-directed player cameras."""
from pathlib import Path
import argparse,os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('demo',type=Path);p.add_argument('bsp',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--renderer',default='gl_compatibility',choices=['gl_compatibility','mobile']);p.add_argument('--views',nargs='+',default=['chase'],choices=['first','chase']);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
godot=os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
for view in a.views:
    output=a.output/('tf-turtler-'+view+'.mp4')
    if output.exists():raise SystemExit('Refusing to overwrite '+str(output))
    with tempfile.TemporaryDirectory(prefix='tf-movie-',dir=a.output) as tmp:
        avi=Path(tmp).resolve()/'capture.avi'
        print('RENDER',view,flush=True)
        with (a.output/(view+'-render.log')).open('w') as log:
            subprocess.run([godot,'--path',str(ROOT),'--xr-mode','off','--rendering-method',a.renderer,'--audio-driver','Dummy','--resolution','1280x800','--fixed-fps','30','--disable-vsync','--write-movie',str(avi),'--script','res://deathmatch/tests/tf_eight_movie.gd','--',str(a.demo.resolve()),str(a.bsp.resolve()),view],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
        log_text=(a.output/(view+'-render.log')).read_text()
        if 'SCRIPT ERROR:' in log_text or 'ERROR:' in log_text.split('Demo movie complete')[0] or not avi.exists():raise RuntimeError('Movie render failed; inspect '+view+'-render.log')
        print('ENCODE',view,flush=True)
        with (a.output/(view+'-encode.log')).open('w') as log:
            subprocess.run(['ffmpeg','-nostdin','-n','-i',str(avi),'-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(output)],stdout=log,stderr=subprocess.STDOUT,check=True)
        print('VIDEO',output,output.stat().st_size,flush=True)
