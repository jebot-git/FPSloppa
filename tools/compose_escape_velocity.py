"""Render an original big-beat / sci-fi rock audition; does not install game music.
Uses existing CC0 recorded instruments, NumPy and FFmpeg. No reference-song audio.
"""
from pathlib import Path
import functools, hashlib, json, math, subprocess, wave
import numpy as np
import generate_metal_alternates as metal

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/audio/escape-velocity'
RATE=44100; BPM=136; BEAT=60/BPM; STEP=BEAT/4; BARS=64
DURATION=BARS*4*BEAT+3
RNG=np.random.default_rng(440913)
EVENTS=[]
N=round(DURATION*RATE)
BUSES={key:np.zeros((N,2),np.float32) for key in ['drums','guitars','bass','lead','strings','electronics']}

@functools.lru_cache(None)
def orchestra(name):
    with wave.open(str(ROOT/'deathmatch/audio/music/samples'/f'{name}.wav')) as f:
        sr=f.getframerate();x=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float32)/32768
    return x/max(np.max(np.abs(x)),.001),sr

@functools.lru_cache(256)
def strings(midi,seconds):
    x,sr=orchestra('strings');t=np.arange(round(seconds*RATE))/RATE
    ratio=440*2**((midi-69)/12)/523.25113
    y=np.interp(t*sr*ratio,np.arange(len(x)),x,left=0,right=0)
    y*=np.minimum(t/.07,1)*np.minimum((seconds-t)/.16,1)
    return y.astype(np.float32)

@functools.lru_cache(256)
def synth(midi,seconds):
    t=np.arange(round(seconds*RATE))/RATE;f=440*2**((midi-69)/12)
    # A quiet, glassy, original sequencer voice behind the real instruments.
    x=np.sin(2*np.pi*f*t+1.6*np.sin(2*np.pi*f*2*t)*np.exp(-t*9))
    x*=np.minimum(t/.003,1)*np.minimum((seconds-t)/.04,1)*np.exp(-t*6)
    return x.astype(np.float32)

def add(bus,sample,at,gain=1,pan=0):
    start=round(at*RATE)
    if start<0:sample=sample[-start:];start=0
    count=min(len(sample),N-start)
    if count<=0:return
    BUSES[bus][start:start+count,0]+=sample[:count]*gain*math.sqrt((1-pan)/2)
    BUSES[bus][start:start+count,1]+=sample[:count]*gain*math.sqrt((1+pan)/2)

def event(bus,midi,at,length,gain,pan=0,instrument=None):
    if bus=='strings':audio=strings(midi,round(length,4))
    elif bus=='electronics':audio=synth(midi,round(length,4))
    else:audio=metal.note(instrument or 'bass',midi,round(length,4))
    add(bus,audio,at,gain,pan)
    EVENTS.append(dict(bus=bus,midi=midi,beat=round(at/BEAT,3),duration=round(length,4),instrument=instrument))

def drum(name,at,gain,pan=0,pitch=1):
    x=metal.source(name)
    if pitch!=1:x=np.interp(np.arange(0,len(x),pitch),np.arange(len(x)),x).astype(np.float32)
    add('drums',x,at+RNG.uniform(-.002,.002),gain*RNG.uniform(.94,1.04),pan)

def chord(root,at,length,gain,muted=True):
    for side,take in [(-.83,'a'),(.83,'b')]:
        for semitone,level in [(0,.74),(7,.42),(12,.13)]:
            event('guitars',root+semitone,at+(0 if side<0 else .007)+RNG.uniform(-.0015,.0015),length,gain*level,side,('mute_' if muted else 'guitar_')+take)

SECTIONS=[(0,8,'Ignition'),(8,24,'Main drive'),(24,32,'Orbital breakdown'),(32,40,'Rebuild'),(40,56,'Full thrust'),(56,64,'Exit burn')]

def compose(loop=False):
    for name in ['guitar_a','guitar_b','mute_a','mute_b']:metal.TUNING[name]=metal.fundamental(name)
    print('Instrument tuning',metal.TUNING,flush=True)
    progression=[(40,3),(40,3),(36,4),(38,4),(40,3),(40,3),(36,4),(35,4)]
    for bar in range(BARS):
        at=bar*4*BEAT;phase=bar%8;root,third=progression[phase]
        intro=bar<8 and not loop;breakdown=24<=bar<32;rebuild=32<=bar<40;peak=40<=bar<56;outro=bar>=56 and not loop
        level=.48 if intro else .45 if breakdown else .70 if rebuild else 1
        if outro:level=.85 if bar<60 else .48
        # Sixteenth-note funk/breakbeat: backbeat, syncopated kicks, low ghost
        # snares, hat openings and new fills every fourth/eighth bar.
        kicks=[0,3,6,8,11] if bar%2==0 else [0,2,7,10,14]
        snares=[4,12];ghosts=[7,10,15] if bar%2==0 else [3,9,14]
        if intro and bar<4:kicks=[0,10];snares=[];ghosts=[]
        if breakdown:kicks=[0];snares=[8] if phase>=4 else [];ghosts=[]
        if outro and bar>=62:kicks=[0];snares=[];ghosts=[]
        for step in kicks:drum('kick',at+step*STEP,.72*level)
        for step in snares:
            drum('snare',at+step*STEP+.004,1.05*level,.05)
            drum('snare',at+step*STEP+.015,.18*level,-.08,.88)
        for step in ghosts:drum('snare',at+step*STEP,.13*level,-.1,1.06)
        for step in range(16):
            if breakdown and step%4:continue
            if intro and bar<4 and step%2:continue
            if outro and bar>=62:continue
            gain=(.38 if step%4==0 else .24 if step%2==0 else .13)*(.55 if breakdown else .9)
            swing=.011 if step%2 else 0
            drum('hat',at+step*STEP+swing,gain,-.32 if step%2==0 else .32,1+.02*(step%3-1))
        if phase in [0,4] and not breakdown:drum('crash',at,.50*level,-.55 if phase==0 else .55)
        if phase==7 and not breakdown:
            for step,gain in [(13,.25),(14,.38),(14.5,.24),(15,.51),(15.5,.33)]:drum('snare',at+step*STEP,gain*level,0,1-.035*(step-13))
        # Original two-bar low-string question/answer, with silence between
        # attacks to leave the chopped drums audible.
        rhythm=[0,2,3,6,8,11,14] if bar%2==0 else [0,3,5,8,10,12,15]
        notes=[0,0,12,7,0,third,2] if bar%2==0 else [0,0,7,0,10,7,-1]
        if phase==7:notes=[0,0,7,0,4,2,0]
        if intro:rhythm=[0,6,10] if bar>=4 else [0];notes=[0,7,0]
        if breakdown:rhythm=[0,10];notes=[0,7]
        if outro and bar>=60:rhythm=[0,8] if bar<63 else [0];notes=[0,0]
        for index,step in enumerate(rhythm):
            pitch=root+notes[index%len(notes)]
            remaining=(rhythm[index+1]-step if index+1<len(rhythm) else 16-step)*STEP
            accent=(step in [0,8] and phase in [0,3,4,7]) or breakdown or bar==63
            length=min(1.8,remaining*(1.1 if accent else .72))
            if breakdown:
                for interval,volume in [(12,.32),(19,.18)]:event('lead',pitch+interval,at+step*STEP,max(.2,length),volume,-.1,'guitar_a')
            else:chord(pitch,at+step*STEP,max(.065,length),level,not accent)
            event('bass',pitch-12,at+step*STEP,max(.07,remaining*.95),.70*level,instrument='bass')
        # A distinct original melodic hook, not the reference theme's tune.
        if (8<=bar<24 or peak or loop and bar<8) and phase in [0,1,4,5,6,7]:
            hook=[(0,12,2),(3,third+12,1),(5,14,2),(8,7,3),(12,10,1),(14,12,2)] if bar%2==0 else [(0,19,3),(4,17,2),(7,third+12,2),(10,14,1),(12,12,4)]
            for step,interval,length in hook:
                event('lead',root+interval,at+step*STEP,length*STEP*.90,.40 if peak else .32,.05,'guitar_b')
                if peak:event('strings',root+interval+12,at+step*STEP,length*STEP+.10,.085,-.30)
        # Orchestral swells punctuate the rhythm instead of blanketing the mix.
        if phase in [0,2,4,6] or breakdown:
            duration=3.9*BEAT if breakdown else 2.5*BEAT
            gain=.15 if breakdown else .085 if intro else .09
            for semitone,pan in [(12,-.45),(third+12,.4),(19,-.12),(26,.25)]:
                event('strings',root+semitone,at,duration,gain,pan)
        if breakdown or rebuild or intro or peak:
            steps=range(0,16,2) if not breakdown else [0,3,6,10,14]
            arp=[12,19,26,third+24,19,14,24,19]
            for index,step in enumerate(steps):event('electronics',root+arp[index%len(arp)],at+step*STEP,.24,.06 if peak else .10,(-.65 if index%2 else .65))
        if not breakdown and phase in [1,3,7] and bar>=8:
            # Scrub only our CC0 guitar recording: no sampled reference record.
            duration=.24;t=np.arange(round(duration*RATE))/RATE
            positions=RATE*(.065+.065*(1-np.cos(4*np.pi*t/duration))*.5)
            source=metal.source('guitar_a')
            scratch=np.interp(positions,np.arange(len(source)),source)
            scratch*=np.sin(np.pi*t/duration)**2
            add('electronics',scratch.astype(np.float32),at+13.5*STEP,.18,-.25)
        if bar in [7,23,39,55]:
            reverse=metal.source('crash')[::-1].copy();reverse*=np.linspace(0,1,len(reverse))
            add('electronics',reverse,at+4*BEAT-len(reverse)/RATE,.15,.2)
    if not loop:
        # The audition retains its original ending; the gameplay loop resolves
        # the last bar's B chord into the first bar's E instead.
        end=63*4*BEAT
        chord(40,end,3.8,.65,False)
        event('bass',28,end,3.6,.5,instrument='bass')
        for note,pan in [(52,-.4),(59,.4),(66,-.1)]:event('strings',note,end,4.8,.13,pan)
    if loop:
        frames=round(BARS*4*BEAT*RATE)
        for key,x in BUSES.items():
            tail=x[frames:].copy();BUSES[key]=x[:frames].copy()
            BUSES[key][:len(tail)]+=tail
    def fx(x,filters):
        if not loop:return metal.process(x,filters)
        # Warm filter/compressor state from the end of the same musical cycle.
        warm=2*RATE
        result=metal.process(np.concatenate([x[-warm:],x,x[:warm]]),filters)
        return result[warm:warm+len(x)]

    print('Processing instrument buses',flush=True)
    BUSES['guitars']=fx(BUSES['guitars'],'highpass=f=100,volume=5,asoftclip=type=tanh:oversample=2,equalizer=f=380:t=q:w=1:g=-4,equalizer=f=1900:t=q:w=1:g=2,lowpass=f=5800')
    BUSES['lead']=fx(BUSES['lead'],'highpass=f=260,volume=3.0,asoftclip=type=tanh,lowpass=f=6300')
    BUSES['bass']=fx(BUSES['bass'],'highpass=f=34,volume=2,asoftclip=type=tanh,lowpass=f=1800')
    BUSES['drums']=fx(BUSES['drums'],'highpass=f=32,acompressor=threshold=0.3:ratio=3:attack=8:release=65:makeup=1.3,equalizer=f=350:t=q:w=1:g=-2,equalizer=f=4200:t=q:w=1:g=3,highshelf=f=5000:g=3')
    BUSES['strings']=fx(BUSES['strings'],'highpass=f=350,lowpass=f=6500')
    for bus,delays in [('lead',[(BEAT*.75,.20),(BEAT*1.5,.10)]),('electronics',[(BEAT*.75,.25),(BEAT*1.5,.13)]),('strings',[(.059,.17),(.131,.12),(.239,.08)]),('drums',[(.029,.08),(.061,.05)])]:
        dry=BUSES[bus].copy()
        for seconds,gain in delays:
            delay=round(seconds*RATE)
            if loop:BUSES[bus]+=np.roll(dry[:,::-1],delay,axis=0)*gain
            else:BUSES[bus][delay:]+=dry[:-delay,::-1]*gain
    weights={'drums':.86,'guitars':.34,'bass':.30,'lead':.35,'strings':.50,'electronics':.32}
    mixed=sum(BUSES[k]*v for k,v in weights.items())
    # Preserve punch, roll off DC and tame occasional layered transients.
    mixed=fx(mixed,'highpass=f=40,equalizer=f=110:t=q:w=0.8:g=-3,equalizer=f=2100:t=q:w=0.8:g=3,highshelf=f=4500:g=4,acompressor=threshold=0.62:ratio=2:attack=18:release=110')
    if not loop:
        fade=round(.06*RATE);mixed[:fade]*=np.linspace(0,1,fade)[:,None]
        fade=round(2.8*RATE);mixed[-fade:]*=np.linspace(1,0,fade)[:,None]
    return mixed

def measure(path):
    r=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.JSONDecoder().raw_decode(r.stderr[r.stderr.rfind('{'):])[0]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    mixed=compose();assert np.isfinite(mixed).all()
    raw=OUT/'mix-unmastered.wav';scale=.90/max(float(np.max(np.abs(mixed))),1)
    with wave.open(str(raw),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(np.rint(mixed*scale*32767).astype('<i2').tobytes())
    stats=measure(raw)
    af='loudnorm=I=-18:TP=-2:LRA=11:linear=true'+''.join(':'+k+'='+stats[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
    master=OUT/'Escape-Velocity.wav'
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-af',af,'-ar',str(RATE),'-c:a','pcm_s16le',str(master)],check=True)
    for extension,codec,quality in [('mp3','libmp3lame',['-b:a','192k']),('ogg','libvorbis',['-q:a','5'])]:
        subprocess.run(['ffmpeg','-y','-v','error','-i',str(master),'-c:a',codec,*quality,'-metadata','title=Escape Velocity','-metadata','artist=FPSloppa original music concept','-metadata','comment=Original sample-based composition; CC0 instruments',str(OUT/('Escape-Velocity.'+extension))],check=True)
    audit={}
    for extension in ['wav','mp3','ogg']:
        path=OUT/('Escape-Velocity.'+extension);reading=measure(path)
        decoded=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar',str(RATE),'-ac','2','-']),dtype='<f4').reshape(-1,2)
        assert np.isfinite(decoded).all() and np.max(np.abs(decoded))<1
        assert abs(float(reading['input_i'])+18)<1 and float(reading['input_tp'])<-.9
        audit[extension]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'seconds':len(decoded)/RATE,'lufs':float(reading['input_i']),'true_peak_dbtp':float(reading['input_tp']),'stereo_correlation':float(np.corrcoef(decoded.T)[0,1])}
    result={'title':'Escape Velocity','bpm':BPM,'metre':'4/4','bars':BARS,'key':'E minor with C/D/B movement','sections':[{'title':label,'from_seconds':round(start*4*BEAT,2),'to_seconds':round(end*4*BEAT,2)} for start,end,label in SECTIONS], 'audio':audit,'events':EVENTS,'tuning_hz':metal.TUNING,'source_notices':['../metal-alternates/sources.json','../../../deathmatch/audio/music/samples/vsco-sources.json']}
    (OUT/'score.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(audit,indent=2),flush=True)

if __name__=='__main__':main()
