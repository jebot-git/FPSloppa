"""Generate FPSloppa's original short flag-capture fanfare (CC0)."""
from pathlib import Path
import math, wave, struct
rate=48000
notes=[(0,.20,261.63),(.17,.20,392.0),(.34,.75,523.25),(.34,.75,659.25),(.34,.75,783.99)]
samples=[]
for i in range(int(rate*1.25)):
 t=i/rate; value=0.0
 for start,duration,freq in notes:
  x=t-start
  if 0<=x<duration:
   env=min(1,x/.018)*min(1,(duration-x)/.18)*math.exp(-1.8*x)
   value+=env*(math.sin(math.tau*freq*x)+.22*math.sin(math.tau*freq*2*x)+.09*math.sin(math.tau*freq*3*x))
 samples.append(value)
peak=max(abs(s) for s in samples)
path=Path(__file__).resolve().parents[1]/'deathmatch/audio/flag_capture.wav'
with wave.open(str(path),'wb') as out:
 out.setparams((1,2,rate,0,'NONE','not compressed'))
 out.writeframes(b''.join(struct.pack('<h',round(s/peak*.60*32767)) for s in samples))
print(path)
