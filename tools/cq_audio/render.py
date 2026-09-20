"""Original CQ orchestral score + procedural environmental loops.
Run fetch_samples.py first. Requires NumPy and FFmpeg; no runtime synthesis.
"""
from pathlib import Path
import argparse,functools,hashlib,json,math,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'deathmatch/audio/cq'; WORK=ROOT/'test-results/cq-audio-render'
RATE=44100
ROWS=json.loads((Path(__file__).parent/'samples.json').read_text())

def decode(path):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','2','-ar',str(RATE),'-f','f32le','-']),dtype='<f4').reshape(-1,2)

def write(path,x):
    with wave.open(str(path),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())

@functools.lru_cache(None)
def source(name):
    r=next(r for r in ROWS if r['name']==name)
    path=Path(__file__).parent/'samples'/(name+'.wav')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==r['sha256'],name
    x=decode(path).mean(axis=1)
    # Remove leading recording silence but preserve the instrument's attack.
    onset=np.flatnonzero(abs(x)>.025*abs(x).max())
    if len(onset):x=x[max(0,int(onset[0]) - int(.008*RATE)):]
    x=x/max(.001,float(abs(x).max()))
    freq=None
    if r['midi'] is not None:
        expected=440*2**((r['midi']-69)/12)
        segment=x[round(.08*RATE):round(.5*RATE)]
        spectrum=abs(np.fft.rfft(segment*np.hanning(len(segment)),131072))
        bins=np.fft.rfftfreq(131072,1/RATE)
        candidates=expected*2**(np.linspace(-35,35,141)/1200)
        scores=sum(np.interp(candidates*h,bins,spectrum)/h for h in range(1,7))
        freq=float(candidates[np.argmax(scores)])
    return x.astype(np.float32),freq

@functools.lru_cache(384)
def note(group,midi,seconds,cents=0):
    candidates=[r for r in ROWS if r['group']==group]
    row=min(candidates,key=lambda r:abs(r['midi']-midi))
    x,freq=source(row['name']);ratio=440*2**((midi-69+cents/100)/12)/freq
    length=round(seconds*RATE);t=np.arange(length)/RATE
    position=t*RATE*ratio
    if position[-1]>=len(x) and 'short' not in group:
        # Overlap two sustain windows instead of stretching the instrument attack.
        begin=round(.35*RATE);period=min(round(.65*RATE),(len(x)-begin)//2)
        phase=np.maximum(0,position-begin)
        a=begin+np.mod(phase,period);b=begin+np.mod(phase+period*.5,period)
        blend=.5-.5*np.cos(2*np.pi*np.mod(phase,period)/period)
        sustain=np.interp(a,np.arange(len(x)),x)*(1-blend)+np.interp(b,np.arange(len(x)),x)*blend
        y=np.interp(position,np.arange(len(x)),x,right=0)
        cross=np.clip((position-begin)/(.12*RATE),0,1);y=y*(1-cross)+sustain*cross
    else:y=np.interp(position,np.arange(len(x)),x,right=0)
    attack=.008 if 'short' in group else .045 if group in ('horn','trumpet','trombone') else .11
    release=min(seconds*.28,.18 if 'short' not in group else .07)
    y*=np.clip(t/attack,0,1)*np.clip((seconds-t)/release,0,1)
    return y.astype(np.float32)

class Score:
    def __init__(self,bpm,bars,seed):
        self.bpm=bpm;self.bars=bars;self.beat=60/bpm;self.frames=round(bars*4*self.beat*RATE)
        self.rng=np.random.default_rng(seed);self.mix=np.zeros((self.frames,2),np.float32);self.events=[]
    def add(self,x,beat,gain,pan):
        at=round(beat*self.beat*RATE);indices=(at+np.arange(len(x)))%self.frames
        # Loop tails wrap into the next cycle; no artificial silence at the join.
        self.mix[indices,0]+=x*gain*math.sqrt((1-pan)/2)
        self.mix[indices,1]+=x*gain*math.sqrt((1+pan)/2)
    def n(self,group,midi,beat,length,gain,pan=0):
        jitter=float(self.rng.uniform(-.009,.009))/self.beat
        velocity=float(self.rng.uniform(.91,1.04))
        self.add(note(group,midi,round(length*self.beat,4)),beat+jitter,gain*velocity,pan)
        self.events.append([group,midi,round(beat,3),round(length,3),gain])
    def drum(self,group,beat,gain,pan=0,ratio=1):
        x,_=source(group)
        if ratio!=1:x=np.interp(np.arange(0,len(x),ratio),np.arange(len(x)),x).astype(np.float32)
        self.add(x,beat,gain*float(self.rng.uniform(.90,1.04)),pan)
    def finish(self):
        # Small diffuse hall, baked and circular so the loop reverberation continues.
        dry=self.mix.copy()
        for delay,level in [(0.043,.085),(.071,.07),(.113,.055),(.173,.047),(.271,.032),(.419,.024),(.631,.014)]:
            self.mix+=np.roll(dry,round(delay*RATE),axis=0)[:,::-1]*level
        return self.mix

# Original eight-bar horn statement, followed by an independently voiced answer.
MELODY=[[(0,69,1.5),(1.5,65,.5),(2,67,1),(3,74,1)],[(0,72,2),(2,69,1.5),(3.5,67,.5)],
 [(0,65,1),(1,69,1),(2,70,1.5),(3.5,69,.5)],[(0,67,2.5),(3,64,1)],
 [(0,65,1.5),(1.5,67,.5),(2,69,2)],[(0,72,1),(1,74,1.5),(2.5,72,.5),(3,69,1)],
 [(0,70,1.5),(2,67,1),(3,65,1)],[(0,64,1.5),(2,61,1),(3,64,1)]]
PROGRESSION=[(38,3),(38,3),(34,4),(36,4),(43,3),(34,4),(36,4),(33,4)]

def combat():
    s=Score(144,64,92126)
    for bar in range(64):
        root,third=PROGRESSION[bar%8];at=bar*4
        bridge=32<=bar<40;peak=bar>=48;level=.70 if bridge else 1.0
        # Antiphonal eighth-note strings and 3+3+2 accents, with moving inner voices.
        pattern=[0,7,12,third+12,7,12,2,7] if bar%2==0 else [12,7,third+12,7,0,7,10,7]
        for i,step in enumerate(pattern):
            s.n('violin_short',root+24+step%12,at+i*.5,.40,.18*level*(1.22 if i in (0,3,6) else 1),-.58)
            s.n('cello_short',root+12+(0 if i%3==0 else 7),at+i*.5+.025,.43,.19*level,.35)
            if peak:s.n('violin_short',root+36+step%12,at+i*.5+.018,.35,.08,.55)
        for shift in (0,7):s.n('cello',root+shift,at,3.85,.13,.25)
        if not bridge:
            for beat,length in [(0,.85),(1.5,.42),(3,.78)]:
                for interval in (0,7,12):s.n('trombone',root+12+interval,at+beat,length,.13,-.22)
        else:
            s.n('violin',root+24+third,at,3.8,.20,-.4)
        motif=MELODY[bar%8]
        for offset,pitch,length in motif:
            if bridge:pitch-=12
            if 16<=bar<32:pitch=pitch-12 if bar%8<4 else pitch
            s.n('horn',pitch-12,at+offset,length*.96,.39*level,-.18)
            s.n('horn',pitch-12,at+offset+.019,length*.94,.14*level,.22)
            if peak or 24<=bar<32:s.n('trumpet',pitch,at+offset+.012,length*.87,.17,.34)
            if bridge:s.n('violin',pitch+12,at+offset,length,.13,-.42)
        if bar%8 in (2,3,6):
            for off,pitch in [(1,root+31),(2.5,root+36),(3.5,root+34)]:s.n('trumpet',pitch,at+off,.43,.13,.35)
        for beat,gain in [(0,.65),(1.5,.34),(2.5,.48)]:s.drum('bass_drum',at+beat,gain*level)
        for beat in (1,3):s.drum('snare',at+beat,.22*level,.10)
        for beat in (0,1.5,3):s.drum('timpani',at+beat,.20*level,-.25,1 if bar%2==0 else .89)
        if bar%4==3:
            for i in range(6):s.drum('snare',at+2.5+i*.25,.06+i*.018,.08)
        if bar%8==0:s.drum('cymbal',at,.23,-.25)
        if bar%8==7:
            for i in range(8):s.drum('timpani',at+2+i*.25,.06+i*.017,-.25)
    return s

def menu():
    s=Score(72,24,92226)
    for bar in range(24):
        root,third=PROGRESSION[bar%8];at=bar*4
        for interval,gain,pan in [(12,.19,.27),(19,.095,.12)]:s.n('cello',root+interval,at,4.08,gain,pan)
        for interval,gain,pan in [(24,.10,-.45),(third+24,.105,-.15),(31,.065,.40)]:
            s.n('violin',root+interval,at+.03,4.1,gain,pan)
        # The action motif appears in long, restrained phrases between silences.
        if bar%8 not in (3,7):
            motif=MELODY[bar%8]
            for off,pitch,length in (motif[:1] if bar<8 else motif[::2]):
                s.n('horn_soft',pitch-12,at+off,min(length*1.8,4-off),.32,-.16)
        if bar%2==0:
            for beat,gain in [(0,.075),(2,.045),(3.5,.028),(3.75,.020)]:s.drum('snare_soft',at+beat,gain,.20)
        if bar%4==0:s.drum('bass_drum',at,.10)
        if bar>=16 and bar%2==1:s.n('violin',MELODY[bar%8][0][1]+12,at+1,2.8,.085,-.35)
    return s

THEMES={
 'cathedral':(110,.2,.10,.22), 'bastion':(82,.55,.12,.08),
 'arcology':(72,.25,.27,.12),'data':(148,.72,.06,.06),
 'docks':(54,.18,.70,.15),'foundry':(62,.80,.13,.30),
 'garden':(96,.12,.55,.05),'market':(88,.27,.44,.15),
 'observatory':(132,.27,.19,.05),'reactor':(48,.95,.08,.07),
 'transit':(78,.57,.50,.22),
}

def ambience(theme):
    hum,machine,air,metal=THEMES[theme];seconds=64;n=seconds*RATE
    rng=np.random.default_rng(93000+list(THEMES).index(theme));t=np.arange(n)/RATE
    f=np.fft.rfftfreq(n,1/RATE);mix=np.zeros((n,2),np.float32)
    for ch in range(2):
        white=rng.normal(size=n);spectrum=np.fft.rfft(white)
        response=(f/45)**2/(1+(f/45)**2)/(1+(f/(420+air*1800))**2)
        noise=np.fft.irfft(spectrum*response,n).astype(np.float32);noise/=max(.001,float(np.std(noise)))
        swell=.7+.18*np.sin(2*np.pi*t/seconds*3+ch)+.12*np.sin(2*np.pi*t/seconds*7+.8*ch)
        mix[:,ch]+=noise*swell*.09*(.4+air)
        for harmonic,level in [(1,.08),(2,.018),(3,.009)]:
            freq=round(hum*harmonic*seconds)/seconds
            mix[:,ch]+=np.sin(2*np.pi*freq*t+.22*ch)*level*machine*(.85+.15*np.sin(2*np.pi*t/seconds))
        # Long, soft mechanical/traffic pass-bys; no gunshots, voices or musical pulse.
        for k in range(5):
            center=(k+.5)*seconds/5+rng.uniform(-3,3);width=rng.uniform(1.5,3.5)
            env=np.exp(-((t-center)/width)**2)
            mix[:,ch]+=noise*env*.09*(air+.15)
        # Sparse cable / sheet-metal resonances, kept well behind the air bed.
        for k in range(7):
            start=rng.uniform(0,seconds);tt=np.mod(t-start,seconds)
            for hz,amp in [(173,.028),(311,.016),(527,.006)]:
                mix[:,ch]+=np.sin(2*np.pi*hz*tt)*np.exp(-tt/(.7 if theme!='cathedral' else 2.4))*amp*metal
    return mix

def loudness(path,target):
    p=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af',f'loudnorm=I={target}:TP=-3:LRA=14:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.JSONDecoder().raw_decode(p.stderr[p.stderr.rfind('{'):])[0]

def master(key,x,target,title,score=None):
    OUT.mkdir(exist_ok=True,parents=True);WORK.mkdir(exist_ok=True,parents=True)
    x-=np.mean(x,axis=0);x*=.80/max(.001,float(abs(x).max()))
    raw=WORK/(key+'.wav');write(raw,x)
    stats=loudness(raw,target);gain=target-float(stats['input_i'])
    # Prefer preserving orchestral dynamics to squeezing every track to a target.
    gain=min(gain,-3.2-float(stats['input_tp']))
    dest=OUT/(key+'.ogg')
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-af',f'volume={gain}dB',
        '-c:a','libvorbis','-q:a','5','-metadata','title='+title,'-metadata','artist=FPSloppa original score',
        '-metadata','comment=Original composition and CC0 VSCO instrument recordings; not reference soundtrack audio',str(dest)],check=True)
    decoded=decode(dest);measured=loudness(dest,target)
    seam=float(abs(decoded[0]-decoded[-1]).max())
    assert len(decoded)==len(x),(key,'Encoded loop duration changed')
    assert np.isfinite(decoded).all() and abs(decoded).max()<1
    assert float(measured['input_tp'])<=-2.5
    assert seam<.02,(key,seam)
    row=dict(file=dest.name,title=title,duration=len(decoded)/RATE,bytes=dest.stat().st_size,
        sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),sample_rate=RATE,channels=2,
        measured_lufs=float(measured['input_i']),true_peak_dbtp=float(measured['input_tp']),loop_step=seam,loop=True)
    if score:
        row.update(bpm=score.bpm,bars=score.bars)
        (OUT/(key+'.score.json')).write_text(json.dumps(dict(bpm=score.bpm,bars=score.bars,events=score.events),indent=2)+'\n')
    write(WORK/(key+'-seam.wav'),np.concatenate([decoded[-3*RATE:],decoded[:3*RATE]]))
    print(json.dumps(row),flush=True);return row

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    manifest=OUT/'manifest.json';rows=json.loads(manifest.read_text())['tracks'] if manifest.exists() else {}
    for key,title,make,target in [('combat','Iron Vespers',combat,-19),('menu','Standards at Dusk',menu,-27)]:
        if args.only and key not in args.only:continue
        s=make();rows[key]=master(key,s.finish(),target,title,s)
    for theme in THEMES:
        if args.only and theme not in args.only:continue
        rows[theme]=master(theme,ambience(theme),-35,'Vesper: '+theme.title())
    metadata=dict(license='CC0-1.0',generator='python3 tools/cq_audio/render.py',tracks=rows,
        district_themes={str(r['id']):r['theme'] for r in json.loads((ROOT/'maps/CampaignDistricts/manifest.json').read_text())['districts']})
    manifest.write_text(json.dumps(metadata,indent=2)+'\n')
if __name__=='__main__':main()
