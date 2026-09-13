#!/usr/bin/env python3
"""Visible, bounded matched 6v6 TITANBALL experiments; raw results stay local."""
import argparse, json, os, subprocess, time
from pathlib import Path
root=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser()
p.add_argument('--profiles',nargs='+',default=['tf'],choices=['tf'])
p.add_argument('--seconds',type=int,default=1030)
p.add_argument('--seed',type=int,default=7129)
p.add_argument('--speed',type=int,default=4,choices=[1,2,4])
p.add_argument('--headless',action='store_true')
p.add_argument('--record',action='store_true',help='Record the game viewport at 30 fps and encode an MP4 after the round')
p.add_argument('--name',default='live')
a=p.parse_args()
if a.record and a.headless:p.error('--record requires a visible renderer')
out=root/'test-results/titanball/simulation';out.mkdir(parents=True,exist_ok=True)
for profile in a.profiles:
 name=f'{a.name}-{profile}-{a.seed}'
 options={'profile':profile,'revision':a.name,'seconds':a.seconds,'seed':a.seed,'speed':a.speed,'record':a.record,'output':str(out/(name+'.json'))}
 cmd=['godot','--path',str(root),'--xr-mode','off','--audio-driver','Dummy','--script','res://tools/titanball/simulation/match.gd']
 cmd+=['--headless','--fixed-fps','60'] if a.headless else ['--rendering-method','mobile','--rendering-driver','vulkan','--max-fps','60']
 if a.record:cmd+=['--write-movie',str(out/(name+'.avi')),'--fixed-fps','30','--disable-vsync']
 print('START',name,flush=True)
 with (out/(name+'.log')).open('w') as log:
  with subprocess.Popen(cmd+['--',json.dumps(options)],cwd=root,env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ba2-data'),stdout=log,stderr=subprocess.STDOUT) as child:
   deadline=time.monotonic()+1800
   while child.poll() is None:
    time.sleep(1)
    if 'SCRIPT ERROR:' in (out/(name+'.log')).read_text() or time.monotonic()>deadline:
     child.terminate();break
   child.wait(timeout=10)
   result=child
 content=(out/(name+'.log')).read_text()
 if result.returncode or 'SCRIPT ERROR:' in content or 'TB_SIM_RESULT' not in content:
  print(content[-8000:],flush=True);raise SystemExit(result.returncode or 1)
 data=json.loads((out/(name+'.json')).read_text())
 print('DONE',name,'winner=',data['winner'],'progress=',data['progress'],'seconds=',data['seconds'],flush=True)
 if a.record:
  video=out/(name+'.mp4')
  with (out/(name+'-encode.log')).open('w') as log:
   subprocess.run(['ffmpeg','-nostdin','-y','-i',str(out/(name+'.avi')),'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-threads','4','-c:a','aac','-b:a','160k','-movflags','+faststart',str(video)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(video)]))
  (out/(name+'-video.json')).write_text(json.dumps(probe,indent=2)+'\n')
  print('VIDEO',video,flush=True)
