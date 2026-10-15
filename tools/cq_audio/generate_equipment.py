"""Original quiet NVG detent and cloak coil sounds; deterministic, mono, CC0."""
from pathlib import Path
import numpy as np,wave,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'deathmatch/audio/equipment';OUT.mkdir(parents=True,exist_ok=True)
rate=24000;rng=np.random.default_rng(941014);rows={}
for name,length in [('nvg_toggle',.11),('cloak_on',.38)]:
 t=np.arange(round(rate*length))/rate
 noise=rng.normal(0,1,len(t));noise=np.convolve(noise,np.ones(5)/5,mode='same')
 if name=='nvg_toggle':
  y=noise*np.exp(-t*85)*np.minimum(1,t/.0015)+.2*np.sin(2*np.pi*940*t)*np.exp(-t*70)
  a=np.maximum(0,t-.036);y+=.32*noise*np.exp(-a*120)*(t>=.036)*np.minimum(1,a/.001)
 else:
  env=np.sin(np.pi*t/length)**2
  phase=2*np.pi*(210*t+170*t*t);y=(.36*np.sin(phase)+.12*np.sin(phase*2.1)+noise*.35)*env*np.exp(-t*4)
 y*=.7/max(np.max(np.abs(y)),1e-8);y[-240:]*=np.linspace(1,0,240)
 p=OUT/(name+'.wav');pcm=(np.clip(y,-1,1)*32767).astype('<i2')
 with wave.open(str(p),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm.tobytes())
 rows[name]={'seconds':length,'sample_rate':rate,'channels':1,'peak':float(max(abs(y))),'rms':float(np.sqrt(np.mean(y*y))),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
