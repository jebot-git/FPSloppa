"""Original 24-channel orchestral action arrangement, editable in MilkyTracker.
XM layout follows MilkyTracker/resources/reference/xm-form.txt. CC0 samples.
"""
from pathlib import Path
import hashlib,json,math,struct,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/audio/copper-fuse'
MUSIC=ROOT/'deathmatch/audio/music'
RATE,BPM,BARS,CHANNELS=44100,150,64,24
N=round(BARS*4*60/BPM*RATE)
EVENTS=[]
INSTRUMENTS=[('violin_short',72,-.42),('cello_short',36,.25),('strings',72,-.28),('horn',59.92,-.15),('trumpet',60.1,.24),('flute',72,.35),('orchestral_snare',60,0),('kick',60,0),('crash',60,.32),('timpani',60,-.25)]

def sample(name):
    folder=OUT/'samples' if (OUT/'samples'/(name+'.wav')).exists() else MUSIC/'samples'
    with wave.open(str(folder/(name+'.wav'))) as f:
        assert f.getnchannels()==1 and f.getsampwidth()==2
        sr=f.getframerate();x=np.frombuffer(f.readframes(f.getnframes()),'<i2').astype(float)/32768
    x=x[:int(sr*(4.5 if name in ['strings','horn','flute'] else 2.5))]
    x-=x.mean();x/=max(abs(x).max(),.001)
    fade=min(len(x)//4,int(sr*.08));x[-fade:]*=np.linspace(1,0,fade)
    return np.rint(x*.88*32767).astype('<i2'),sr

def compose():
    EVENTS.clear();cells=np.zeros((BARS*16,CHANNELS,5),np.uint8)
    def note(ch,name,midi,bar,beat,length,vol):
        row=round(bar*16+beat*4);off=min(BARS*16-1,row+max(1,round(length*4)))
        instrument=next(i for i,s in enumerate(INSTRUMENTS) if s[0]==name)+1
        cells[row,ch]=[midi-11,instrument,16+vol,8,round((INSTRUMENTS[instrument-1][2]+1)*127.5)]
        if off>row and cells[off,ch,0]==0:cells[off,ch]=[97,0,0,0,0]
        EVENTS.append(dict(channel=ch,instrument=name,midi=midi,bar=bar,beat=beat,beats=length,volume=vol))
    # Explicit D minor / B-flat major / G minor / D minor / A major harmony.
    progression=[(38,3),(38,3),(34,4),(34,4),(43,3),(38,3),(45,4),(45,4)]
    for bar in range(BARS):
        root,third=progression[bar%8];triad=[root,root+third,root+7]
        bridge=32<=bar<40;climax=bar>=48;intro=bar<4;drive=not bridge and not intro
        for i in range(8):
            note(0,'cello_short',root+(12 if i%4==3 else 7 if i%4==1 else 0),bar,i*.5,.45,39 if i%4==0 else 28)
            if drive or i%2==0:
                note(2,'violin_short',triad[[0,2,1,2,0,1,2,1][i]]+24,bar,i*.5,.43,28 if i in [0,3,6] else 21)
                if climax:note(3,'violin_short',triad[[2,1,0,1,2,0,1,2][i]]+24,bar,i*.5,.43,17)
        # Chord beds release before changes; inversions minimize voice movement.
        tones=sorted((p+24 if p<41 else p+12) for p in triad)
        for i,pitch in enumerate(tones):note(5+i,'strings',pitch+12,bar,0,3.5,16 if drive else 22)
        rhythm=[(0,0,1.5),(1.75,2,.75),(3,1,.75)] if bar%2==0 else [(0,2,1),(1.5,1,.75),(2.5,0,1.25)]
        if not intro:
            for beat,degree,length in rhythm:
                note(9,'horn',triad[degree]+12,bar,beat,length,36 if drive else 29)
                if climax:note(10,'horn',triad[degree]+24,bar,beat,length,17)
        if drive:
            for beat in [0,1.5,3]:
                note(11,'trumpet',root+24,bar,beat,.45,23);note(12,'trumpet',root+31,bar,beat,.45,16)
        if bridge or 16<=bar<24:
            for i,degree in enumerate([2,1,0,1]):note(14,'flute',triad[degree]+36,bar,i,.75,16)
        for beat,vol in [(0,32),(1.5,24),(2,29),(3.5,22)]:note(16,'kick',48,bar,beat,.7,vol if not bridge else vol//2)
        if not intro:
            for beat,vol in [(1,23),(2.75,12),(3,27),(3.75,12)]:note(17,'orchestral_snare',60,bar,beat,.24,vol if not bridge else vol//2)
        if bar%4==3:
            for i in range(4):note(18,'orchestral_snare',60,bar,3+i*.25,.22,12+i*4)
        if bar%8==0 or climax and bar%4==0:note(19,'crash',55,bar,0,3,17)
        if bar%2==0:note(20,'timpani',round(root+12+(60-56.33)),bar,0,.75,17)
    cells[-1,23]=[0,0,0,11,0]
    return cells

def write_xm(path,cells):
    patterns=BARS//4
    header=b'Extended Module: '+b'Copper Fuse Orchestra'.ljust(20,b'\0')[:20]+b'\x1a'+b'FPSloppa XM Composer'.ljust(20,b'\0')[:20]+struct.pack('<H',0x104)
    header+=struct.pack('<I8H',276,patterns,0,CHANNELS,patterns,len(INSTRUMENTS),1,6,BPM)+bytes(range(patterns))+bytes(256-patterns)
    data=bytearray(header)
    for p in range(patterns):
        raw=cells[p*64:(p+1)*64].tobytes();data.extend(struct.pack('<IBHH',9,0,64,len(raw)));data.extend(raw)
    for name,root,pan in INSTRUMENTS:
        pcm,sr=sample(name);instrument=bytearray(263)
        struct.pack_into('<I22sBH',instrument,0,263,name.encode(),0,1);struct.pack_into('<I',instrument,29,40)
        for i,(time,vol) in enumerate([(0,64),(8,64),(20,0)]):struct.pack_into('<HH',instrument,129+i*4,time,vol)
        instrument[225]=3;instrument[227]=1;instrument[233]=3;struct.pack_into('<H',instrument,239,256)
        semitones=12*math.log2(sr/8363)+(60-root);relative=round(semitones);fine=round((semitones-relative)*128)
        raw=np.diff(np.concatenate(([0],pcm.astype(np.int32)))).astype('<i2').tobytes()
        sample_header=struct.pack('<IIIBbBBbB22s',len(raw),0,0,64,fine,16,round((pan+1)*127.5),relative,0,name.encode())
        data.extend(instrument);data.extend(sample_header);data.extend(raw)
    path.write_bytes(data)

def render():
    module=OUT/'Copper-Fuse-Orchestral.xm';write_xm(module,compose())
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(module),'-t',str(N/RATE+1),'-ar',str(RATE),'-ac','2','-f','f32le','-'])
    rendered=np.frombuffer(raw,'<f4').reshape(-1,2);assert len(rendered)>=N
    dry=rendered[:N].copy();tail=rendered[N:];dry[:len(tail)]+=tail
    audio=dry.copy()
    for seconds,gain in [(.043,.15),(.089,.12),(.151,.09),(.227,.055)]:audio+=np.roll(dry[:,::-1],round(seconds*RATE),axis=0)*gain
    return audio

def metadata():
    module=OUT/'Copper-Fuse-Orchestral.xm'
    return dict(arrangement='orchestral action',source_format='XM',source_file=str(module.relative_to(ROOT)),source_sha256=hashlib.sha256(module.read_bytes()).hexdigest(),channels=CHANNELS,instruments=len(INSTRUMENTS))
