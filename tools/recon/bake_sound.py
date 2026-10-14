"""Original CC0 electronic recon acquisition warning, no sampled source."""
from pathlib import Path
import numpy as np,wave
rate=24000;t=np.arange(int(rate*.9))/rate
signal=np.zeros_like(t)
for onset,hz in [(0,880),(.18,1174.66),(.36,1568)]:
 u=t-onset;mask=(u>=0)&(u<.16);env=np.zeros_like(t);env[mask]=np.sin(np.pi*u[mask]/.16)**.6
 signal+=env*(np.sin(2*np.pi*hz*u)+.18*np.sin(4*np.pi*hz*u))
signal*=.65/np.max(np.abs(signal))
out=Path('deathmatch/audio/recon');out.mkdir(parents=True,exist_ok=True)
with wave.open(str(out/'spotted.wav'),'wb') as wav:
 wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes((signal*32767).astype('<i2').tobytes())
(out/'SOURCES.md').write_text('Original procedurally synthesized CC0 three-tone electronic recon detection warning; no external samples. Rebuild: `python3 tools/recon/bake_sound.py`. Mono 24 kHz PCM16, 0.9 seconds. The ascending radio alert plays locally for the newly spotted enemy, once per drone pass and player life.\n')
