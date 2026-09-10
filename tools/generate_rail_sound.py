# Deterministic original railgun transient; no third party audio.
import math, random, struct, wave
r=random.Random(129);rate=44100;frames=[];phase=0
for i in range(int(rate*.65)):
 t=i/rate;phase+=2*math.pi*(1800*math.exp(-t*12)+110)/rate
 v=(r.uniform(-1,1)*math.exp(-t*48)*.6+math.sin(phase)*math.exp(-t*8)*.3+math.sin(phase*2.71)*math.exp(-t*14)*.12)*min(1,t*1500)
 frames.append(struct.pack('<h',int(max(-1,min(1,v))*25000)))
from pathlib import Path
with wave.open(str(Path(__file__).resolve().parents[1]/'deathmatch/audio/weapon_9.wav'),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(frames))
