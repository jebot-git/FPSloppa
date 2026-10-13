"""Original procedural prototype pistol reports. CC0; no sampled CS recordings."""
import math,random,struct,wave
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'deathmatch/audio/cq_weapons';root.mkdir(parents=True,exist_ok=True)
rate=32000
for suppressed in [False,True]:
 rng=random.Random(742);samples=[];filtered=0.0
 for i in range(int(rate*.23)):
  t=i/rate;noise=rng.uniform(-1,1);filtered+=.14*(noise-filtered)
  crack=(filtered if suppressed else noise)*math.exp(-t*(85 if suppressed else 65))
  body=math.sin(2*math.pi*(210*t-240*t*t))*math.exp(-t*38)
  action=math.sin(2*math.pi*1700*t)*math.exp(-abs(t-.07)*230)*.12
  v=(crack*.7+body*.27+action)*(.38 if suppressed else .82)
  samples.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
 with wave.open(str(root/('pistol_suppressed.wav' if suppressed else 'pistol.wav')),'wb') as output:
  output.setnchannels(1);output.setsampwidth(2);output.setframerate(rate);output.writeframes(b''.join(samples))
