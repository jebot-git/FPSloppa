"""Record only the spectator game window and its isolated game-audio sink."""
from pathlib import Path
import subprocess,json,time,os,signal,re,argparse
p=argparse.ArgumentParser();p.add_argument("--resume-render-pid",type=int);p.add_argument("--smooth-camera",action="store_true");options=p.parse_args()
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/('test-results/de-santorini-smooth-recording' if options.smooth_camera else 'test-results/de-santorini-recording')
OUT.mkdir(parents=True,exist_ok=True)
for name in ['recording-ready.json','capture-started.json','complete.json','server.json','client.json']:(OUT/name).unlink(missing_ok=True)
(OUT/'match.cfg').write_text((ROOT/'tools/de_penetration/santorini.cfg').read_text())
if 'santorini_capture' not in subprocess.check_output(['pactl','list','short','sinks'],text=True):
 subprocess.run(['pactl','load-module','module-null-sink','sink_name=santorini_capture','sink_properties=device.description=Santorini_Capture'],check=True)
def launch(args,log,env=None):
 if options.smooth_camera:args.append('--smooth-camera')
 return subprocess.Popen([str(ROOT/'run.sh'),*args],cwd=ROOT,env=env,stdout=(OUT/log).open('w'),stderr=subprocess.STDOUT,start_new_session=True)
server=launch(['--headless','--xr-mode','off','--script','tools/de_penetration/record_santorini.gd','--','--server','--config',str(OUT/'match.cfg')],'server.log')
env=os.environ.copy();env['PULSE_SINK']='santorini_capture'
client=launch(['--xr-mode','off','--rendering-method','mobile','--resolution','1280x720','--max-fps','30','--script','tools/de_penetration/record_santorini.gd','--','--connect','127.0.0.1','--port','28981','--spectate','--name','Match recorder'],'client.log',env)
(OUT/'pids.json').write_text(json.dumps({'server':server.pid,'client':client.pid}));print('Game launched',server.pid,client.pid,flush=True)
deadline=time.monotonic()+150
while time.monotonic()<deadline and not (OUT/'recording-ready.json').exists():
 if client.poll() is not None:raise RuntimeError('Client stopped before ready')
 time.sleep(1)
if not (OUT/'recording-ready.json').exists():raise RuntimeError('Spectator did not become ready')
windows=subprocess.check_output(['xwininfo','-root','-tree'],text=True);window=None
for line in windows.splitlines():
 m=re.search(r'(0x[0-9a-f]+).*?(\d+)x(\d+)\+',line)
 if not m:continue
 properties=subprocess.run(['xprop','-id',m[1],'_NET_WM_PID'],capture_output=True,text=True).stdout
 if re.search(r'=\s*'+str(client.pid)+r'\b',properties):window=m;break
if window is None:raise RuntimeError('Game window not found')
size=window[2]+'x'+window[3]
args=['ffmpeg','-y','-hide_banner','-loglevel','warning','-thread_queue_size','512','-f','x11grab','-framerate','30','-draw_mouse','0','-window_id',str(int(window[1],16)),'-video_size',size,'-i',env.get('DISPLAY',':0'),'-thread_queue_size','512','-f','pulse','-i','santorini_capture.monitor','-vf','scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2','-c:v','libx264','-preset','ultrafast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(OUT/'santorini-5v5.mp4')]
rec=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=(OUT/'ffmpeg.log').open('w'),stderr=subprocess.STDOUT);print('Recording',size,'window',window[1],flush=True)
time.sleep(2)
if rec.poll() is not None:raise RuntimeError('Recorder stopped before match')
(OUT/'capture-started.json').write_text(json.dumps({'window_id':window[1],'size':size,'video':'1280x720 30fps','audio':'isolated santorini_capture.monitor','started_utc':time.time()}))
deadline=time.monotonic()+1800
while time.monotonic()<deadline and not (OUT/'complete.json').exists():
 if rec.poll() is not None or client.poll() is not None:break
 time.sleep(1)
if rec.poll() is None:
 rec.communicate(b'q\n',timeout=30)
print('Recording finalized; complete:',(OUT/'complete.json').exists(),flush=True)
if options.resume_render_pid:
 try:os.kill(options.resume_render_pid,signal.SIGCONT)
 except ProcessLookupError:pass
raise SystemExit(0 if (OUT/'complete.json').exists() and rec.returncode==0 else 1)
