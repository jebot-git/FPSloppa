"""Record one isolated 5v5/six-round-cap overview movie per installed DE map."""
from pathlib import Path
import subprocess,json,time,os,signal,re,hashlib,argparse
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/de-shoulder-recordings';OUT.mkdir(exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--map');p.add_argument('--resume',action='store_true');args=p.parse_args()
selection=['de_varq_santorini','de_varq_inferno','de_varq_dust2']
catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())
rows=[next(r for r in catalog if r['id']==name) for name in selection if not args.map or name==args.map]

SINK='de_shoulder_capture';module=subprocess.check_output(['pactl','load-module','module-null-sink','sink_name='+SINK,'sink_properties=device.description=DE_Shoulder_Capture'],text=True).strip()
def stop(proc):
 if proc and proc.poll() is None:
  os.killpg(proc.pid,signal.SIGTERM)
  try:proc.wait(timeout=15)
  except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
def record(row):
 name=row['id'];folder=OUT/name;folder.mkdir(exist_ok=True);video=folder/(name+'-5v5.mp4')
 if args.resume and (folder/'verified.json').exists() and video.exists():
  previous=json.loads((folder/'verified.json').read_text())
  if previous.get('camera_version')==3:return previous
 for f in ['recording-ready.json','capture-started.json','complete.json','server.json','client.json']:(folder/f).unlink(missing_ok=True)
 cfg=(ROOT/'tools/de_penetration/santorini.cfg').read_text().replace('de_varq_santorini',name).replace('28981','28983').replace('Santorini',name)
 (folder/'match.cfg').write_text(cfg);server=client=rec=None
 try:
  common=['--script','tools/de_penetration/record_shoulder.gd','--','--record-map',name]
  def launch(params,log,env=None):return subprocess.Popen([str(ROOT/'run.sh'),*params],cwd=ROOT,env=env,stdout=(folder/log).open('w'),stderr=subprocess.STDOUT,start_new_session=True)
  server=launch(['--headless','--xr-mode','off',*common,'--server','--config',str(folder/'match.cfg')],'server.log')
  env=os.environ.copy();env['PULSE_SINK']=SINK
  client=launch(['--xr-mode','off','--rendering-method','mobile','--resolution','1280x720','--max-fps','30',*common,'--connect','127.0.0.1','--port','28983','--spectate','--name','Shoulder recorder'],'client.log',env)
  (folder/'pids.json').write_text(json.dumps(dict(server=server.pid,client=client.pid)))
  deadline=time.monotonic()+180
  while time.monotonic()<deadline and not (folder/'recording-ready.json').exists():
   if client.poll() is not None or server.poll() is not None:raise RuntimeError('Game stopped before ready; inspect logs')
   time.sleep(1)
  if not (folder/'recording-ready.json').exists():raise RuntimeError('Spectator readiness timed out')
  window=None
  for line in subprocess.check_output(['xwininfo','-root','-tree'],text=True).splitlines():
   m=re.search(r'(0x[0-9a-f]+).*?(\d+)x(\d+)\+',line)
   if not m:continue
   prop=subprocess.run(['xprop','-id',m[1],'_NET_WM_PID'],capture_output=True,text=True).stdout
   if re.search(r'=\s*'+str(client.pid)+r'\b',prop):window=m;break
  if window is None:raise RuntimeError('Game window not found')
  rec=subprocess.Popen(['ffmpeg','-y','-hide_banner','-loglevel','warning','-thread_queue_size','512','-f','x11grab','-framerate','30','-draw_mouse','0','-window_id',str(int(window[1],16)),'-video_size',window[2]+'x'+window[3],'-i',env.get('DISPLAY',':0'),'-thread_queue_size','512','-f','pulse','-i',SINK+'.monitor','-vf','scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2','-c:v','libx264','-threads','2','-preset','ultrafast','-crf','21','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(video)],stdin=subprocess.PIPE,stdout=(folder/'ffmpeg.log').open('w'),stderr=subprocess.STDOUT,start_new_session=True)
  time.sleep(2)
  if rec.poll() is not None:raise RuntimeError('Recorder failed to start')
  (folder/'capture-started.json').write_text(json.dumps(dict(window=window[1],time=time.time())))
  print(name,'recording',flush=True);deadline=time.monotonic()+1800
  while time.monotonic()<deadline and not (folder/'complete.json').exists():
   if rec.poll() is not None or client.poll() is not None:break
   time.sleep(1)
  if rec.poll() is None:rec.communicate(b'q\n',timeout=30)
  if not (folder/'complete.json').exists() or rec.returncode:raise RuntimeError('Match or recording incomplete')
  report=json.loads((folder/'complete.json').read_text());assert report['teams']==[5,5] and report['phase']=='finished' and report['round_cap']==6
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(video)]))
  decode=subprocess.run(['ffmpeg','-v','error','-threads','2','-i',str(video),'-f','null','-'],capture_output=True,timeout=180)
  if decode.returncode or decode.stderr:raise RuntimeError('Video decode failed: '+decode.stderr.decode()[-500:])
  report.update(video=str(video.relative_to(ROOT)),video_sha256=hashlib.sha256(video.read_bytes()).hexdigest(),duration=float(probe['format']['duration']),video_decode_verified=True,camera_version=3,status='recorded')
  (folder/'verified.json').write_text(json.dumps(report,indent=2)+'\n');print(name,'complete',report['scores'],report['duration'],flush=True);return report
 finally:stop(rec);stop(client);stop(server)
results=[]
try:
 for row in rows:
  try:result=record(row)
  except Exception as e:result=dict(map=row['id'],status='failed',error=str(e));print(result,flush=True)
  results.append(result);(OUT/'recordings.json').write_text(json.dumps(results,indent=2)+'\n')
finally:subprocess.run(['pactl','unload-module',module],check=False)
raise SystemExit(any(r['status']!='recorded' for r in results))
