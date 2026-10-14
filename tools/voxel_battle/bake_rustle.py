"""Author deterministic CC0 leaf-brush noise; no sampled recording is used."""
from pathlib import Path
import numpy as np
import wave
out=Path('deathmatch/audio/jungle');out.mkdir(exist_ok=True)
rate=24000
for variant in range(3):
 rng=np.random.default_rng(8137+variant);length=int(rate*.48)
 noise=rng.normal(0,1,length);freq=np.fft.rfftfreq(length,1/rate)
 band=(1-np.exp(-(freq/550)**2))*np.exp(-(freq/7000)**2)
 signal=np.fft.irfft(np.fft.rfft(noise)*band,n=length)
 t=np.arange(length)/rate;envelope=np.sin(np.pi*t/.48)**1.1
 envelope*=np.interp(t,np.linspace(0,.48,19),rng.uniform(.15,1,19))
 signal*=envelope;signal*=.55/max(abs(signal))
 with wave.open(str(out/f'rustle_{variant}.wav'),'wb') as wav:
  wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes((signal*32767).astype('<i2').tobytes())
(out/'SOURCES.md').write_text('Original CC0 procedural leaf-brush noise. No external recording or copyrighted sample. Rebuild: `python3 tools/voxel_battle/bake_rustle.py`; NumPy seeds 8137–8139, mono 24 kHz PCM16, 0.48 seconds each.\n')
