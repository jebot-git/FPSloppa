"""Original grinding cue using the project's CC0 Kenney metal transient."""
from pathlib import Path
import subprocess,numpy as np,wave
root=Path(__file__).resolve().parents[1]/'deathmatch/audio'
sr=32000;n=int(sr*.22);t=np.arange(n)/sr
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/'recorded/impactMetal_light_000.ogg'),'-ac','1','-ar',str(sr),'-f','f32le','-'])
metal=np.frombuffer(raw,dtype='<f4');rng=np.random.default_rng(24019)
scrape=rng.normal(0,1,n);scrape=np.concatenate(([0],np.diff(scrape)))*.12
scrape+=.2*np.sin(2*np.pi*(1200*t+400*t*t))*(.5+.5*np.sin(2*np.pi*95*t))
for offset in [0,.035,.073,.11,.15]:
 i=int(offset*sr);k=min(len(metal),n-i);scrape[i:i+k]+=metal[:k]*2.2
scrape=np.tanh(scrape)*np.minimum(1,t/.008)*np.minimum(1,(.22-t)/.05)
scrape*=10**(-8/20)/max(np.max(np.abs(scrape)),1e-9)
with wave.open(str(root/'saw_grind.wav'),'wb') as out:
 out.setparams((1,2,sr,0,'NONE','not compressed'));out.writeframes(np.rint(scrape*32767).astype('<i2').tobytes())
print('Rendered 220 ms grinding cue; -8 dBFS peak')
