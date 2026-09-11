"""Rebuild Doom-style weapons and recorded-foley pickups/jumps. Requires ffmpeg.
Pinned BSD Freedoom originals: tools/audio-sources/freedoom/SOURCES.json.
Existing Kenney and HaelDB recordings are CC0; no commercial Doom audio is used.
"""
from pathlib import Path
import array,hashlib,json,math,subprocess,wave
ROOT=Path(__file__).resolve().parents[1];AUDIO=ROOT/'deathmatch/audio';SOURCE=ROOT/'tools/audio-sources/freedoom';OUT=AUDIO/'doom-style';RATE=22050
OUT.mkdir(exist_ok=True);report=[]
def read(path,rate=1.0):
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-af',f'highpass=f=65,lowpass=f=8500,asetrate={int(RATE*rate)},aresample={RATE}','-f','f32le','-'])
 values=list(array.array('f',raw));peak=max(map(abs,values),default=0)
 start=next((i for i,x in enumerate(values) if abs(x)>max(.002,peak*.015)),0)
 return values[max(0,start-22):]
def piece(values,duration,gain=1):
 n=min(len(values),int(duration*RATE));out=[]
 for i,v in enumerate(values[:n]):out.append(v*gain*min(1,i/(RATE*.0015))*min(1,(n-i)/(RATE*.025)))
 return out
def mix(duration,layers):
 result=[0.0]*int(duration*RATE)
 for values,delay,gain in layers:
  start=int(delay*RATE)
  for i,v in enumerate(values[:len(result)-start]):result[start+i]+=v*gain
 return result
def save(name,values):
 mean=sum(values)/len(values);values=[v-mean for v in values]
 peak=max(map(abs,values));scale=10**(-4/20)/max(peak,1e-9)
 values=[v*scale*min(1,i/22)*min(1,(len(values)-i)/(RATE*.012)) for i,v in enumerate(values)]
 p=OUT/(name+'.wav')
 with wave.open(str(p),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(array.array('h',(round(v*32767) for v in values)).tobytes())
 report.append({'file':p.name,'seconds':len(values)/RATE,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'peak_dbfs':20*math.log10(max(map(abs,values)))})
sources={p.stem:read(p) for p in SOURCE.glob('*.wav')}
# Keep each report recognizable at its existing firing cadence. Mechanical tails
# are below the report, and do not imply a new reload mechanic.
for weapon,source,duration in [(1,'dssawful',.17),(2,'dspistol',.32),(3,'dsshotgn',.66),(4,'dsdshtgn',.94),(5,'dspistol',.20),(6,'dsrlaunc',.45),(7,'dsplasma',.20),(8,'dsbfg',.75)]:
 layers=[(piece(sources[source],duration),0,1)]
 if weapon==3:layers.append((piece(sources['dssgcock'],.27),.34,.22))
 if weapon==4:
  for key,delay in [('dsdbopn',.39),('dsdbload',.58),('dsdbcls',.76)]:layers.append((piece(sources[key],.16),delay,.22))
 save('weapon_'+str(weapon),mix(duration,layers))
save('explosion',piece(sources['dsbarexp'],.85))
metal=read(AUDIO/'recorded/impactMetal_light_000.ogg');boot=read(AUDIO/'recorded/footstep_concrete_002.ogg')
# All pickup layers are recorded/mechanical transients, with no sine-note motif.
pickups={
 'pickup_ammo':(.20,[(piece(sources['dsdbload'],.16),0,1),(piece(metal,.07),.08,.18)]),
 'pickup_weapon':(.32,[(piece(sources['dssgcock'],.20),0,1),(piece(sources['dsdbcls'],.12),.18,.65)]),
 'pickup_armor':(.30,[(piece(metal,.24),0,.75),(piece(boot,.14),.025,.5),(piece(sources['dsdbcls'],.10),.15,.2)]),
 'pickup_health':(.23,[(piece(boot,.14),0,.65),(piece(sources['dsdbopn'],.12),.07,.24)]),
 'pickup_mega':(.48,[(piece(metal,.22),0,.7),(piece(sources['dsdbload'],.20),.12,.65),(piece(sources['dsdbcls'],.14),.30,.8)])}
for name,(duration,layers) in pickups.items():save(name,mix(duration,layers))
for i in range(3):
 foot=read(AUDIO/f'recorded/footstep_concrete_{i:03d}.ogg');grunt=read(AUDIO/f'recorded/pain_{i}.wav',1.18)
 save('jump_'+str(i),mix(.34,[(piece(foot,.12),0,.7),(piece(grunt,.22),.045,.45)]))
 save('land_'+str(i),mix(.25,[(piece(foot,.21),0,1),(piece(boot,.14),.055,.45)]))
(OUT/'manifest.json').write_text(json.dumps({'sample_rate':RATE,'channels':1,'sources_revision':json.loads((SOURCE/'SOURCES.json').read_text())['revision'],'files':report},indent=2)+'\n')
print('Authored',len(report),'mono SFX; peaks at or below -4 dBFS')
