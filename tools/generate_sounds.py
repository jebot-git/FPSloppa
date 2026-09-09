"""Original CC0 procedural arena SFX. No sampled recordings or third-party audio."""
from pathlib import Path
import math, random, wave, struct
OUT=Path(__file__).resolve().parents[1]/'deathmatch/audio'
OUT.mkdir(exist_ok=True)
RATE=22050
rng=random.Random(90491)
def render(name, length, kind, pitch=1):
    signal=[]; low=0.; phase=0.
    for i in range(int(length*RATE)):
        t=i/RATE; n=rng.uniform(-1,1);low=low*.88+n*.12
        if kind=='gun':
            v=(n*.50*math.exp(-t*55)+low*1.9*math.exp(-t*10)+math.sin(2*math.pi*(95*t-27*t*t)*pitch)*.7*math.exp(-t*18))
        elif kind=='shotgun':
            v=n*.65*math.exp(-t*18)+low*2.3*math.exp(-t*7)+math.sin(2*math.pi*60*t)*.7*math.exp(-t*10)
            for delay in [.34,.44]:
                if t>delay:v+=n*.26*math.exp(-(t-delay)*70)
        elif kind=='energy':
            phase+=2*math.pi*(700*math.exp(-t*5)+100)*pitch/RATE
            v=(math.sin(phase)+.3*math.sin(phase*2.01)+n*.3)*math.exp(-t*6)*.5
        elif kind=='saw':v=(math.sin(2*math.pi*85*t)+n*.75)*(.55+.45*math.sin(2*math.pi*24*t))*.4*min(1,t*100,(length-t)*50)
        elif kind=='blast':v=(low*3+n*.5*math.exp(-t*12)+math.sin(2*math.pi*48*t)*.7)*math.exp(-t*3.5)*min(1,t*300)
        elif kind=='flesh':v=(low*2.5+n*.2)*math.exp(-t*17)+math.sin(2*math.pi*(180*t-150*t*t))*.3*math.exp(-t*20)
        elif kind=='pain':
            phase+=2*math.pi*(150-65*t/length)*pitch/RATE
            v=(math.sin(phase)+.4*math.sin(phase*3)+.2*math.sin(phase*7)+n*.12)*math.sin(math.pi*t/length)**2*.5
        elif kind=='step':v=(low*2+n*.15)*math.exp(-t*30)*min(1,t*500)
        elif kind=='pickup':v=math.sin(2*math.pi*(640*t+900*t*t))*math.exp(-t*10)*.5
        else:v=(math.sin(2*math.pi*(120*t+1600*t*t))+low)*math.sin(math.pi*t/length)*.4
        signal.append(math.tanh(v))
    # Short, diffuse reflections make cracks less dry without changing shot timing.
    if kind in ('gun','shotgun','blast'):
        dry=signal[:]
        for delay,gain in [(.041,.16),(.079,.1),(.113,.06)]:
            lag=int(delay*RATE)
            for i in range(lag,len(signal)):signal[i]+=dry[i-lag]*gain
    peak=max(abs(x) for x in signal) or 1
    pcm=b''.join(struct.pack('<h',int(x/peak*28000)) for x in signal)
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setparams((1,2,RATE,0,'NONE','not compressed'));w.writeframes(pcm)
for i,(duration,kind,pitch) in enumerate([(.22,'flesh',1),(.3,'saw',1),(.4,'gun',1.5),(.7,'shotgun',1),(.9,'shotgun',.75),(.22,'gun',1.1),(.65,'blast',1),(.3,'energy',1.6),(1.,'energy',.45)]):render('weapon_'+str(i),duration,kind,pitch)
for name,duration,kind in [('flesh',.24,'flesh'),('gib',.6,'flesh'),('pain',.32,'pain'),('death',.7,'pain'),('explosion',1.2,'blast'),('step',.16,'step'),('land',.24,'step'),('pickup',.25,'pickup'),('teleport',.6,'warp'),('spawn',.5,'warp'),('ui',.07,'pickup')]:render(name,duration,kind)
print('Generated',len(list(OUT.glob('*.wav'))),'original WAV files')
