"""Original CC0 jet ignition and periodic thrust bed."""
from pathlib import Path
import wave,math,random,json,hashlib
out=Path(__file__).resolve().parents[2]/'deathmatch/audio/equipment';rows={}
for name,seconds in [('jetpack_ignite',.28),('jetpack_thrust',1.)]:
 rate=24000;rng=random.Random(825 if seconds==1 else 826);values=[];smooth=0.
 for i in range(int(rate*seconds)):
  t=i/rate;smooth=.8*smooth+.2*rng.uniform(-1,1)
  signal=.4*smooth+.12*math.sin(2*math.pi*96*t)+.07*math.sin(2*math.pi*192*t)+.035*math.sin(2*math.pi*384*t)
  if seconds!=1:signal=(signal+rng.uniform(-.3,.3))*math.sin(math.pi*t/seconds)**2
  values.append(max(-1,min(1,signal)))
 path=out/(name+'.wav')
 with wave.open(str(path),'wb') as w:w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(int(v*32767).to_bytes(2,'little',signed=True) for v in values))
 rows[name]={'seconds':seconds,'license':'CC0 original procedural audio','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(out/'jetpack-manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
