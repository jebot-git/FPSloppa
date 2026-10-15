"""Deterministic, seamless original jungle ambience; no music or recorded samples."""
from pathlib import Path
import numpy as np, subprocess,tempfile,wave
ROOT=Path(__file__).resolve().parents[2];rate=24000;seconds=32;n=rate*seconds;t=np.arange(n)/rate
rng=np.random.default_rng(940014)
for night in [False,True]:
 noise=rng.standard_normal(n);freq=np.fft.rfftfreq(n,1/rate)
 spectrum=np.fft.rfft(noise);spectrum*=np.exp(-freq/900)/(1+freq/80)
 air=np.fft.irfft(spectrum,n);air=air/max(np.std(air),1e-9)*.012
 signal=air.copy()
 for i in range(14 if night else 8):
  centre=rng.uniform(0,seconds);duration=rng.uniform(.15,.7);distance=(t-centre+seconds/2)%seconds-seconds/2
  env=np.exp(-(distance/duration)**2)*(.5+.5*np.sin(2*np.pi*(16 if night else 6)*distance))**4
  carrier=(round(rng.uniform(2800,5500)*seconds)/seconds)
  signal+=env*np.sin(2*np.pi*carrier*t+np.sin(2*np.pi*round(rng.uniform(2,8)*seconds)/seconds*t)*2)*(.022 if night else .016)
 data=np.int16(np.clip(signal,-.95,.95)*32767)
 with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
  with wave.open(tmp.name,'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data.tobytes())
  target=ROOT/'deathmatch/audio/jungle'/('night.ogg' if night else 'day.ogg')
  subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',tmp.name,'-c:a','libvorbis','-q:a','3',str(target)],check=True)
 print(target)
