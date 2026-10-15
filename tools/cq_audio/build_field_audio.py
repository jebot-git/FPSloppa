"""Edit licensed recordings into bounded mono cues and seamless ambience loops.
Requires ffmpeg + numpy. Sources: deathmatch/audio/cq_field/sources.json.
Populate tools/audio-sources/cq-field from its URLs, extract the two ZIPs there,
then run edit_field_sources.py with the Audacity MCP Python environment first.
"""
from pathlib import Path
import subprocess,json,hashlib,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2];CACHE=ROOT/'tools/audio-sources/cq-field';OUT=ROOT/'deathmatch/audio/cq_field';OUT.mkdir(parents=True,exist_ok=True)
RATE=24000;manifest={};used=set()
def decode(path,start=0,length=None,channels=1,high=50,low=11000,speed=1):
 args=['ffmpeg','-v','error','-ss',str(start),'-i',str(path)]
 if length:args+=['-t',str(length)]
 filters=f'highpass=f={high},lowpass=f={low}'
 if speed!=1:filters+=f',asetrate={RATE*speed},aresample={RATE}'
 args+=['-ac',str(channels),'-ar',str(RATE),'-af',filters,'-f','f32le','-']
 a=np.frombuffer(subprocess.check_output(args),dtype='<f4').copy().reshape(-1,channels)
 assert len(a)>0 and np.isfinite(a).all(),path
 return a
def source(key):
 used.add(key)
 return CACHE/next(r['file'] for r in sources if r['id']==key)
def sci(name):used.add('scifi');return CACHE/'scifi'/(name+'.ogg')
def master(name):used.add('blacklodge' if name in ['carbine','beam','assault'] else 'motor_loop' if name=='repair' else 'scifi');return CACHE/'edited'/(name+'.wav')
def gain(a,peak=.7,rms=None):
 a=a-a.mean(axis=0);factor=peak/max(np.abs(a).max(),1e-8)
 if rms is not None:factor=min(factor,rms/max(np.sqrt(np.mean(a*a)),1e-8))
 return a*factor
def loop(a,seconds=.15):
 n=min(int(seconds*RATE),len(a)//4);w=np.linspace(0,1,n)[:,None]
 return np.concatenate([a[n:-n],a[-n:]*(1-w)+a[:n]*w])
def fade(a,attack=.002,release=.05):
 a=a.copy();n=min(int(attack*RATE),len(a)//3);m=min(int(release*RATE),len(a)//3)
 if n:a[:n]*=np.linspace(0,1,n)[:,None]
 if m:a[-m:]*=np.linspace(1,0,m)[:,None]
 return a
def emit(name,a,inputs,looped=False,ogg=False,peak=.7,rms=None,edit=''):
 a=gain(a,peak,rms)
 if not looped:a=fade(a)
 path=OUT/(name+('.ogg' if ogg else '.wav'));tmp=OUT/('_'+name+'.wav') if ogg else path
 with wave.open(str(tmp),'wb') as f:f.setnchannels(a.shape[1]);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.round(a*32767).astype('<i2').tobytes())
 if ogg:
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(tmp),'-c:a','libvorbis','-q:a','4',str(path)],check=True);tmp.unlink()
 manifest[name]={'file':path.name,'sources':inputs,'loop':looped,'seconds':len(a)/RATE,'rate':RATE,'channels':a.shape[1],'peak_dbfs':float(20*np.log10(max(abs(a).max(),1e-9))),'rms_dbfs':float(20*np.log10(max(np.sqrt(np.mean(a*a)),1e-9))),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'edit':edit or 'trim, DC removal, band-limit, peak/RMS trim, short edge fades'+('; end-to-start crossfade' if looped else '')}
 print(name,round(len(a)/RATE,3))
sources=json.loads((OUT/'sources.json' if (OUT/'sources.json').exists() else CACHE/'sources.json').read_text())
for p in sorted(CACHE.glob('*-metadata.json')):sources.append(json.loads(p.read_text()))
sources=list({r['id']:r for r in sources}.values())
# Long environmental recordings retain stereo width and use compressed streams.
for name,key,start,seconds in [('forest_day','birds',12,50),('forest_night','night',24,54),('river','river',15,40),('rain','rain',15,40)]:
 a=loop(decode(source(key),start,seconds,channels=1 if name=='rain' else 2,high=90 if name=='rain' else 70),1.)
 emit(name,a,[key],True,name!='rain',.4,.045 if name in ['forest_day','forest_night'] else .09)
a=decode(source('thunder'),0,20.8,high=35,low=7000);energy=np.mean(a*a,axis=1);onset=np.flatnonzero(energy>energy.max()*.06)[0];a=a[max(0,onset-240):];emit('thunder',a,['thunder'],peak=.82)
# Real mechanical motors, and a pitched electrical drive for hovering hulls.
for name,key,speed,low in [('engine_heavy','heavy_engine',.85,6500),('engine_transport','heavy_engine',1.16,8000),('engine_hover','motor_loop',.8,5500)]:
 emit(name,loop(decode(source(key),speed=speed,low=low)),[key],True,peak=.5,rms=.16)
for name,key in [('engine_start','motor_start'),('engine_stop','motor_end')]:emit(name,decode(source(key)),[key],peak=.65)
# Sci-fi masters were filtered, trimmed and normalized through Audacity MCP.
for name,m,speed in [('carbine','carbine',1),('assault','assault',1.08),('beam','beam',1),('burst_pistol','carbine',1.25),('launcher','ordnance',.85),('guided_launcher','ordnance',1.1),('jetpack_ignite','jet_ignite',1)]:emit(name,decode(master(m),speed=speed),['blacklodge' if m in ['carbine','assault','beam'] else 'scifi'],edit='Audacity MCP trim, high/low-pass and normalize; resample/pitch, DC removal, edge fade')
# Retain the real firearm attack; the SMG has a shorter report and the scout a filtered suppressor tail.
recorded=ROOT/'deathmatch/audio/recorded/weapon_2_0.wav'
for name,length,low,speed,peak in [('pistol',.38,11000,1,.72),('smg',.14,9000,1.2,.64),('pistol_suppressed',.19,2300,1.12,.42)]:
 emit(name,decode(recorded,0,length,low=low,speed=speed),['tabasco_existing'],peak=peak)
# A sustained thrust texture with a mechanical core, not a repeated ignition transient.
a=decode(master('repair'));b=decode(sci('rocket_01'),.3,1.2,low=6000);b=np.resize(loop(b),a.shape)
emit('jetpack_thrust',loop(gain(a,.28)+gain(b,.45)),['motor_loop','scifi'],True,peak=.65,rms=.18)
emit('repair',loop(decode(master('repair'))),['motor_loop'],True,peak=.5,rms=.14)
for name,key,speed in [('magazine_out','clip2',.85),('magazine_in','clip1',1),('bolt_pull','bolt',.86),('bolt_release','bolt',1.3),('deploy','clip1',.68),('nvg_toggle','clip2',1.8)]:
 emit(name,decode(source(key),speed=speed),[key],peak=.65 if name!='nvg_toggle' else .45)
for name,sample,length,peak in [('cloak_on','teleport_01',.38,.5),('cloak_off','misc_11',.4,.45),('inject_start','misc_01',.3,.48),('revive','beep_02',None,.6),('supply','terminal_04',None,.5),('empty','terminal_07',None,.45),('lock_acquire','beep_03',None,.55),('lock_ready','beep_02',None,.6),('charge','misc_06',.35,.55),('energy_impact','shoot_02',None,.65),('ordnance_impact','explosion_01',None,.78)]:
 emit(name,decode(sci(sample),length=length),['scifi'],peak=peak)
emit('inject_loop',loop(decode(sci('loop_machine_03'),low=4500)),['scifi'],True,peak=.3,rms=.055)
# Water foley excerpts from the same river recording; filtered bed for submerged models.
for name,start,length in [('water_enter',10,.48),('water_exit',20,.48),('swim',30,.35)]:emit(name,decode(source('river'),start,length,high=180),['river'],peak=.55)
emit('submerged',loop(decode(source('river'),40,8,low=800)),['river'],True,True,.3,.07)
# Quiet site beds: machines for industrial/data sites; flowing water at the port.
a=decode(source('motor_loop'));a=np.tile(a,(8,1));emit('industrial',loop(a,.25),['motor_loop'],True,True,.25,.035)
# Existing project CC0 source is credited by original provenance too.
sources.append({'id':'tabasco_existing','author':'Tabasco','license':'CC0-1.0','page':'https://opengameart.org/content/gunshot-sounds','file':'deathmatch/audio/recorded/weapon_2_0.wav','sha256':hashlib.sha256(recorded.read_bytes()).hexdigest(),'source_quality':'existing project edit of original gunshot recording'})
(OUT/'sources.json').write_text(json.dumps(list({r['id']:r for r in sources}.values()),indent=2)+'\n');(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

# Latest user-directed weapon pass supersedes the original weapon masters.
from reauthor_weapons import build as build_weapon_reports
build_weapon_reports()
