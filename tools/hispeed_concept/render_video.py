"""Render the same recorded AS playthrough from three cameras. Godot + ffmpeg."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('demo',type=Path);p.add_argument('bsp',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--end',type=float);p.add_argument('--renderer',default='gl_compatibility',choices=['gl_compatibility','mobile']);p.add_argument('--views',nargs='+',default=['first','chase','trackside'],choices=['first','chase','trackside','vrm-chase']);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
godot=os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
for view in a.views:
    output=a.output/('hispeed-as-'+view+'.mp4')
    if output.exists():raise SystemExit('Refusing to overwrite '+str(output))
    with tempfile.TemporaryDirectory(prefix='hispeed-movie-',dir=a.output) as tmp:
        avi=Path(tmp).resolve()/'capture.avi'
        print('RENDER',view,flush=True)
        with (a.output/(view+'-render.log')).open('w') as log:
            subprocess.run([godot,'--path',str(ROOT),'--xr-mode','off','--rendering-method',a.renderer,'--audio-driver','Dummy','--resolution','1440x900','--fixed-fps','30','--disable-vsync','--write-movie',str(avi),'--script','res://deathmatch/tests/hispeed_movie.gd','--',str(a.demo.resolve()),str(a.bsp.resolve()),view,*([str(a.end)] if a.end is not None else [])],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
        log_text=(a.output/(view+'-render.log')).read_text()
        if 'SCRIPT ERROR:' in log_text or 'ERROR:' in log_text.split('Demo movie complete')[0] or not avi.exists():raise RuntimeError('Movie render failed; inspect '+view+'-render.log')
        print('ENCODE',view,flush=True)
        with (a.output/(view+'-encode.log')).open('w') as log:
            subprocess.run(['ffmpeg','-nostdin','-n','-i',str(avi),'-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(output)],stdout=log,stderr=subprocess.STDOUT,check=True)
        print('VIDEO',output,output.stat().st_size,flush=True)
