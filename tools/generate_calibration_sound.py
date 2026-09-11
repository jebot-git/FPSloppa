"""Original short calibration-complete bell jingle, CC0; standard library only."""
from pathlib import Path
import math, struct, wave
rate=32000;duration=.48;frames=[]
for n in range(int(duration*rate)):
 t=n/rate;v=0
 for at,freq in [(0,523.251),(.11,659.255),(.22,783.991)]:
  x=t-at
  if x>=0:v+=(math.sin(math.tau*freq*x)+.2*math.sin(math.tau*freq*2*x))*min(1,x/.008)*math.exp(-x*15)
 v*=min(1,(duration-t)/.04)
 frames.append(v)
gain=10**(-9/20)/max(abs(v) for v in frames)
path=Path(__file__).resolve().parents[1]/'deathmatch/audio/calibration_complete.wav'
with wave.open(str(path),'wb') as out:
 out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(b''.join(struct.pack('<h',round(v*gain*32767)) for v in frames))
