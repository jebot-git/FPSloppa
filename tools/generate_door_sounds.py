"""Author short CC0 motor/latch cues using the project's CC0 Kenney metal sample."""
from pathlib import Path
import array
import math
import random
import subprocess
import wave

ROOT=Path(__file__).resolve().parents[1]
RATE=22050

def main():
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'deathmatch/audio/recorded/impactMetal_light_000.ogg'),'-ac','1','-ar',str(RATE),'-f','s16le','-'])
    latch=[v/32768 for v in array.array('h',raw)]
    for name,closing in [('door_open',False),('door_close',True)]:
        rng=random.Random(740+closing);values=[];phase=0.;low=0.
        for i in range(int(.78*RATE)):
            t=i/RATE;n=rng.uniform(-1,1);low=.86*low+.14*n
            envelope=min(1,t/.04)*max(0,min(1,(.62-t)/.09))
            frequency=(145-65*t/.62) if closing else (85+70*t/.62)
            phase+=math.tau*frequency/RATE
            motor=(.18*math.sin(phase)+.09*math.sin(phase*3)+low*.6+n*.05)*envelope
            value=motor
            for onset,gain in [(0,.35),(.58,.75 if closing else .55)]:
                at=i-int(onset*RATE)
                if 0<=at<len(latch):value+=latch[at]*gain
            values.append(value*min(1,(.78-t)/.025))
        peak=max(abs(v) for v in values)
        pcm=array.array('h',(round(v/peak*23170) for v in values))
        path=ROOT/'deathmatch/audio'/f'{name}.wav'
        with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
        rms=math.sqrt(sum((v/peak)**2 for v in values)/len(values))*.7071
        print(name,'duration=.78 peak=-3.01 dBFS rms=%.2f dBFS'%(20*math.log10(rms)))

if __name__=='__main__':main()
