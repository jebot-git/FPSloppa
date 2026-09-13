"""Original CC0 BA-2 stomps: planted mass, crushed asphalt, steel and baked reflections."""
from pathlib import Path
import json, hashlib, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).parent;RATE=44100

def noise(rng,t,low,high):
    frequencies=np.fft.rfftfreq(len(t),1/RATE)
    spectrum=np.fft.rfft(rng.normal(size=len(t)))
    spectrum*=np.exp(-(frequencies/high)**4)*(1-np.exp(-(frequencies/low)**4))
    data=np.fft.irfft(spectrum,n=len(t));return data/max(np.std(data),.0001)

def make(index):
    rng=np.random.default_rng(7210+index);t=np.arange(round(RATE*1.45))/RATE
    # Ground compression: broader, sustained weight rather than a short pitched knock.
    phase=2*np.pi*(34*t+18*.028*(1-np.exp(-t/.028)))
    mass=.90*np.sin(phase)*np.exp(-t/.29)
    mass+=.36*np.sin(phase*2.13)*np.exp(-t/.23)
    mass+=noise(rng,t,48,260)*.37*np.exp(-t/.24)
    mass+=noise(rng,t,110,480)*.20*np.exp(-t/.17)
    x=np.tanh(mass*1.45)*.95
    # Asphalt gives way under the plate: rough low-mid crush, followed by debris.
    crush=noise(rng,t,160,1750)
    grains=np.zeros_like(t)
    for at in [.005,.028,.049,.078,.114,.158,.211,.278,.35]:
        u=np.maximum(0,t-at)
        grains+=rng.uniform(.55,1.0)*np.exp(-u/rng.uniform(.016,.040))*(t>=at)*np.exp(-at/.18)
    x+=crush*grains*.25
    x+=noise(rng,t,450,3200)*.09*np.exp(-t/.095)
    # Lower steel resonances retain the mechanism without dominating the ground impact.
    for hz,gain,decay in [(103,.14,.36),(173,.11,.30),(291,.075,.23),(613,.035,.16),(1183,.02,.09)]:
        x+=gain*np.sin(2*np.pi*(hz*(1+index*.014))*t)*np.exp(-t/decay)
    x+=noise(rng,t,1200,5600)*.065*np.exp(-t/.012)
    for at,gain in [(.058,.09),(.13,.065),(.225,.035)]:
        u=np.maximum(0,t-at)
        x+=noise(rng,t,320,3000)*gain*np.exp(-u/.045)*(t>=at)
    x+=noise(rng,t,900,4300)*.023*np.exp(-((t-.23)/.12)**2)
    # Short, dark reflections baked offline: no extra runtime reverb bus or DSP.
    frequencies=np.fft.rfftfreq(len(x),1/RATE)
    dark=np.fft.irfft(np.fft.rfft(x)*np.exp(-(frequencies/1150)**2),n=len(x))
    wet=np.zeros_like(x)
    for delay,gain in [(.043,.13),(.081,.10),(.137,.075),(.207,.045)]:
        offset=round(delay*RATE);wet[offset:]+=dark[:-offset]*gain
    for delay in np.arange(.055,.62,.009):
        offset=round((delay+rng.uniform(-.003,.003))*RATE)
        wet[offset:]+=dark[:-offset]*rng.choice([-1.,1.])*.022*np.exp(-delay/.21)
    x+=wet
    x*=np.minimum(1,t/.0015)*np.minimum(1,(t[-1]-t)/.065)
    x-=x.mean();x*=10**(-1.5/20)/np.max(np.abs(x));x[0]=x[-1]=0
    samples=np.round(x*32767).astype('<i2');path=OUT/f'stomp_{index}.wav'
    with wave.open(str(path),'wb') as f:f.setparams((1,2,RATE,len(samples),'NONE','not compressed'));f.writeframes(samples.tobytes())
    return x,{'file':path.name,'seconds':len(x)/RATE,'sample_rate':RATE,'channels':1,'peak_dbfs':float(20*np.log10(np.max(np.abs(x)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

if __name__=='__main__':
    rows=[];preview=np.zeros(RATE*8)
    for i in range(3):
        x,row=make(i);rows.append(row)
        for j in range(i,8,3):
            at=round((.3+j*.7875)*RATE);n=min(len(x),len(preview)-at)
            if n>0:preview[at:at+n]+=x[:n]*.75
    with wave.open(str(OUT/'walking-preview.wav'),'wb') as f:f.setparams((1,2,RATE,len(preview),'NONE','not compressed'));f.writeframes(np.round(np.clip(preview,-1,1)*32767).astype('<i2').tobytes())
    assert np.max(np.abs(preview))<1, 'Overlapping footsteps clip the preview'
    (OUT/'manifest.json').write_text(json.dumps({'revision':'heavy-asphalt','license':'CC0-1.0','source':'Original procedural synthesis; no third-party recordings','reverb':'short dark reflections baked into mono samples','variants':rows},indent=2)+'\n')
    print(json.dumps(rows,indent=2))
