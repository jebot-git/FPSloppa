"""Generate an original, short mechanical round-countdown tick (CC0)."""
from pathlib import Path
import math,random,struct,wave
path=Path(__file__).resolve().parents[1]/'deathmatch/audio/round_tick.wav'
rng=random.Random(103);rate=48000;frames=[];filtered=0
for i in range(int(rate*.085)):
 t=i/rate;noise=rng.uniform(-1,1);filtered=.35*filtered+.65*noise
 value=.5*math.exp(-t*95)*(math.sin(2*math.pi*2450*t)+.28*math.sin(2*math.pi*3870*t))+.12*filtered*math.exp(-t*180)
 value*=min(1,t/.0008)*min(1,(.085-t)/.003)
 frames.append(struct.pack('<h',round(max(-1,min(1,value))*32767)))
with wave.open(str(path),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(frames))
print(path)
