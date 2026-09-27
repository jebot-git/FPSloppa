#!/usr/bin/env python3
"""Real-time six-round 6v6 DE sessions, each with a visible ENet video client."""
from pathlib import Path
import argparse, datetime, json, os, subprocess, time
ROOT=Path(__file__).resolve().parents[2]
MAPS=(ROOT/'maps/de_maplist.txt').read_text().split()
def read(path):return json.loads(path.read_text())
def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--maps',nargs='+',choices=MAPS,default=MAPS)
 p.add_argument('--output',type=Path)
 p.add_argument('--smoke-seconds',type=int,default=0)
 a=p.parse_args()
 out=(a.output or ROOT/'recordings'/('de-map-series-'+datetime.datetime.now().strftime('%Y-%m-%dT%H-%M-%S'))).resolve()
 out.mkdir(parents=True,exist_ok=True);results=[]
 print('SERIES_OUTPUT',out,flush=True)
 for index,map_id in enumerate(a.maps):
  folder=out/map_id;folder.mkdir(exist_ok=False)
  options=dict(map=map_id,port=28990+index,seed=7129,output=str(folder),smoke_seconds=a.smoke_seconds)
  save(folder/'options.json',options)
  env=dict(os.environ,XDG_DATA_HOME=str(folder/'user-data'))
  base=['godot','--path',str(ROOT),'--xr-mode','off','--audio-driver','Dummy']
  server_cmd=base+['--headless','--log-file',str(folder/'server-engine.log'),'--script','res://tools/defusal/series_server.gd','--',json.dumps(options)]
  client_cmd=base+['--rendering-method','mobile','--rendering-driver','vulkan','--resolution','1280x720','--max-fps','60','--log-file',str(folder/'client-engine.log'),'--script','res://tools/defusal/series_view.gd','--',json.dumps(options)]
  print('START',map_id,flush=True)
  with (folder/'server.log').open('w') as slog,(folder/'client.log').open('w') as clog:
   server=subprocess.Popen(server_cmd,cwd=ROOT,env=env,stdout=slog,stderr=subprocess.STDOUT);client=None
   try:
    deadline=time.monotonic()+120
    while not (folder/'server-ready.json').exists():
     if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Server failed to become ready: '+str(folder))
     time.sleep(.25)
    client=subprocess.Popen(client_cmd,cwd=ROOT,env=env,stdout=clog,stderr=subprocess.STDOUT)
    deadline=time.monotonic()+1900
    while client.poll() is None:
     if time.monotonic()>deadline:raise RuntimeError('Live client exceeded time cap')
     if any('SCRIPT ERROR:' in (folder/(name+'.log')).read_text() for name in ['server','client']):raise RuntimeError('GDScript error; inspect '+str(folder))
     time.sleep(.5)
    if client.returncode:raise RuntimeError('Live client failed: '+str(folder))
    if 'SCRIPT ERROR:' in (folder/'client.log').read_text():raise RuntimeError('Client script error: '+str(folder))
    if a.smoke_seconds:server.terminate();server.wait(timeout=15)
    elif server.wait(timeout=30):raise RuntimeError('Server did not finish six rounds')
   finally:
    for process in [client,server]:
     if process is not None and process.poll() is None:
      process.terminate()
      try:process.wait(timeout=10)
      except subprocess.TimeoutExpired:process.kill();process.wait()
  view=read(folder/'view.json')
  # Video and audio come from this spectator alone, never the desktop mix.
  target=folder/'match.mp4'
  # The Dummy mix clock can drift from the wall-clock viewport stream. Align
  # their measured durations with a pitch-preserving tempo correction.
  tempo=view['audio_seconds']/view['seconds']
  subprocess.run(['ffmpeg','-nostdin','-y','-loglevel','error','-i',str(folder/'video-silent.mp4'),'-i',str(folder/'audio.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-af',f'atempo={tempo:.10f},apad','-shortest','-movflags','+faststart',str(target)],check=True,timeout=120)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(target)]))
  save(folder/'video.json',probe)
  assert any(s['codec_type']=='video' and s['width']==1280 and s['height']==720 for s in probe['streams'])
  assert any(s['codec_type']=='audio' for s in probe['streams'])
  assert abs(float(probe['format']['duration'])-view['seconds'])<.15
  if not a.smoke_seconds:
   receipt=read(folder/'match.json');assert receipt['completed'] and receipt['teams']==[6,6]
   subprocess.run(base+['--headless','--log-file',str(folder/'validation-engine.log'),'--script','res://tools/validate_defusal_recording.gd','--',str(folder/'match.fpsdemo')],cwd=ROOT,env=env,stdout=(folder/'validation.log').open('w'),stderr=subprocess.STDOUT,check=True,timeout=120)
  results.append(dict(map=map_id,video=str(target),seconds=view['seconds'],completed=view['completed'],duplicate_frames=view['duplicate_frames'],frames=view['frames']))
  save(out/'series.json',dict(format='6v6, six rounds per map, roles switch after round three',real_time=True,maps=results))
  print('DONE',map_id,'seconds',view['seconds'],'video',target,flush=True)
 print('SERIES_COMPLETE',out,flush=True)
if __name__=='__main__':main()
