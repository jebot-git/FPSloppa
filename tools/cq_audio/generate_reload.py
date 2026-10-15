"""Original CC0 procedural magazine and bolt feedback; no source recordings."""
import wave,math,random,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'deathmatch/audio/equipment';out.mkdir(exist_ok=True)
rows={}
for name,duration,seed in [('magazine_out',.16,701),('magazine_in',.19,702),('bolt_pull',.22,703),('bolt_release',.16,704)]:
 rng=random.Random(seed);rate=24000;values=[]
 for i in range(int(duration*rate)):
  t=i/rate;slide='bolt' in name;env=math.sin(math.pi*t/duration)**2*math.exp(-t*(7 if slide else 12))
  click=math.exp(-max(0,t-.025)*90) if t>=.025 else 0
  value=(rng.uniform(-1,1)*(.2 if slide else .12)+.12*math.sin(2*math.pi*(1300 if slide else 850)*t))*env+.3*click*rng.uniform(-1,1)
  values.append(max(-1,min(1,value)))
 pcm=b''.join(int(v*32767).to_bytes(2,'little',signed=True) for v in values)
 path=out/(name+'.wav')
 with wave.open(str(path),'wb') as w:w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(pcm)
 rows[name]={'seconds':duration,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'license':'CC0 original procedural audio'}
(out/'reload-manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
