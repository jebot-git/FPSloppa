"""Original CC0 procedural bronze gong: inharmonic modes, bloom and metallic wash."""
from pathlib import Path
import json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
rate=48000;seconds=5.5;t=np.arange(int(rate*seconds))/rate;rng=np.random.default_rng(3192026)
signal=np.zeros_like(t)
for index,ratio in enumerate([1,1.47,2.09,2.63,3.41,4.17,5.43,6.79,8.21,10.61,13.37,17.11]):
 frequency=94*ratio;amplitude=1/(1+index*.65);decay=3.8/(1+index*.12)
 envelope=(1-np.exp(-t/(.007+index*.001)))*np.exp(-t/decay)
 bloom=1+.55*np.exp(-((t-.38)/.29)**2)
 phase=2*np.pi*frequency*t+.7*np.sin(2*np.pi*(2.2+index*.27)*t)*np.exp(-t/1.3)
 signal+=amplitude*envelope*bloom*np.sin(phase+rng.uniform(-.2,.2))
noise=rng.standard_normal(t.size)
noise=np.convolve(noise,np.ones(7)/7,mode='same')
signal+=.5*noise*(1-np.exp(-t/.002))*np.exp(-t/.16)
# Quiet deterministic reflections widen the tail without an abrupt stereo pan.
left=signal.copy();right=signal.copy()
for delay,level in [(0.041,.14),(.071,.10),(.113,.075),(.179,.04)]:
 n=int(rate*delay);left[n:]+=level*signal[:-n];right[n+211:]+=level*signal[:-n-211]
audio=np.column_stack([left,right]);audio*=np.minimum(1,(seconds-t)/.6)[:,None];audio*=.79/np.max(np.abs(audio))
path=ROOT/'deathmatch/audio/round_gong.wav'
with wave.open(str(path),'wb') as output:
 output.setnchannels(2);output.setsampwidth(2);output.setframerate(rate);output.writeframes((audio*32767).astype('<i2').tobytes())
report={'path':str(path.relative_to(ROOT)),'seconds':seconds,'sample_rate':rate,'channels':2,'peak':float(np.abs(audio).max()),'rms':float(np.sqrt(np.mean(audio**2))),'clipped_samples':int((np.abs(audio)>=1).sum()),'seed':3192026,'license':'CC0-1.0; original procedural synthesis, no samples'}
(ROOT/'test-results/koth-rotation/gong.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
