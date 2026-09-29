"""Original seamless Scout turbine loop; no third-party recording samples."""
from pathlib import Path
import math, struct, wave
rate=24000;seconds=2;data=[]
for i in range(rate*seconds):
 t=i/rate
 # Integer frequencies make a seamless two-second loop.
 v=.34*math.sin(math.tau*75*t)+.16*math.sin(math.tau*150*t)+.08*math.sin(math.tau*225*t)
 v+=.06*math.sin(math.tau*602*t+1.2*math.sin(math.tau*8*t))
 data.append(int(v*22000))
p=Path(__file__).resolve().parents[2]/'deathmatch/vehicles/tribes/turbine.wav'
with wave.open(str(p),'wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(struct.pack('<%dh'%len(data),*data))
