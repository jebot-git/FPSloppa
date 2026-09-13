"""Signal-level reference comparison; stores statistics, never reference audio.
Usage: python3 tools/compare_escape_velocity.py /tmp/reference.webm
"""
from pathlib import Path
import json, subprocess, sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/audio/escape-velocity'

def analyse(path):
    rate=22050;hop=220;window=1024
    x=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ar',str(rate),'-ac','2','-f','f32le','-']),dtype='<f4').reshape(-1,2)
    mono=x.mean(axis=1);frames=np.lib.stride_tricks.sliding_window_view(mono,window)[::hop]
    spectrum=np.abs(np.fft.rfft(frames*np.hanning(window),axis=1))
    freq=np.fft.rfftfreq(window,1/rate);power=(spectrum**2).sum(axis=0)
    bands={label:float(power[(freq>=low)&(freq<high)].sum()/power.sum()) for label,low,high in [('sub_and_kick',30,150),('bass_and_low_mid',150,800),('presence',800,3000),('treble',3000,11025)]}
    flux=np.maximum(0,np.diff(np.log1p(spectrum*10),axis=0)).sum(axis=1)
    flux-=flux.mean();size=1<<int(np.ceil(np.log2(len(flux)*2)))
    ac=np.fft.irfft(np.abs(np.fft.rfft(flux,size))**2,size)[:len(flux)]
    bpm=np.arange(90,181,.1);lag=60*rate/(hop*bpm)
    scores=np.interp(lag,np.arange(len(ac)),ac)+.4*np.interp(2*lag,np.arange(len(ac)),ac)
    best=[]
    for idx in np.argsort(scores)[::-1]:
        if all(abs(bpm[idx]-v)>3 for v in best):best.append(round(float(bpm[idx]),1))
        if len(best)==3:break
    length=(len(mono)//11025)*11025;rms=np.sqrt(np.mean(mono[:length].reshape(-1,11025)**2,axis=1))
    active=rms[rms>.01*rms.max()]
    return {'seconds':len(x)/rate,'estimated_tempo_candidates_bpm':best,'spectral_energy_fractions':bands,'rms_spread_p90_p10_db':float(20*np.log10(np.percentile(active,90)/np.percentile(active,10))),'stereo_correlation':float(np.corrcoef(x.T)[0,1])}

result={'method':'Whole-track spectral energy, onset-autocorrelation tempo candidates and half-second RMS distribution; not a perceptual listening test. Tempo can be ambiguous at half/double time.', 'reference_url':'https://www.youtube.com/watch?v=wQJlyQykD38','reference':analyse(Path(sys.argv[1])),'original_composition':analyse(OUT/'Escape-Velocity.wav')}
(OUT/'reference-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
