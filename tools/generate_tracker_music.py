"""Title/lobby eight-channel tracker scores and archived industrial arrangements, CC0. Requires numpy and FFmpeg.
Recorded CC0 instruments and provenance: deathmatch/audio/music/SOURCES.md.
Run with title/lobby mode keys; gameplay now uses generate_metal_alternates.py.
"""
from pathlib import Path
import hashlib, json, math, struct, subprocess, sys, tempfile, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'deathmatch/audio/music'
RATE=3546895/428; REF=130.81278265
# Each mode has its own key, progression, motif, tempo, rhythm and arrangement.
SCORES=[
 dict(key='title',stem='dead_air',title='Dead Air',root=0,bpm=68,bars=32,style='ambient',chords=[0,1,0,6],motif=[7,1,0,10,8,5,1,0],scale=[0,1,3,5,7,8,10]),
 dict(key='lobby',stem='please_hold',title='Please Hold',root=0,bpm=112,bars=48,style='lounge',chords=[0,9,2,7,4,9,2,7],motif=[1,2,1,0,1,2],scale=[0,2,4,5,7,9,11]),
 dict(key='dm',stem='iron_circuit',title='Iron Circuit II',root=4,bpm=138,bars=64,style='industrial',chords=[0,1,0,-1],motif=[0,1,7,5,3,1,0,10],scale=[0,1,3,5,7,8,10]),
 dict(key='tdm',stem='pressure_lock',title='Pressure Lock II',root=2,bpm=128,bars=64,style='march',chords=[0,-1,0,1],motif=[0,7,10,9,7,5,3,2],scale=[0,2,3,5,7,9,10]),
 dict(key='ctf',stem='dark_relay',title='Signal Runner',root=2,bpm=146,bars=64,style='breaks',chords=[0,1,0,6],motif=[7,10,12,9,7,5,3,2],scale=[0,2,3,5,7,9,10]),
 dict(key='koth',stem='high_ground',title='High Ground',root=7,bpm=116,bars=64,style='halftime',chords=[0,-2,0,1],motif=[0,3,7,10,7,5,3,0],scale=[0,2,3,5,7,8,10]),
 dict(key='ig',stem='foundry_run',title='Needlepoint',root=6,bpm=166,bars=64,style='jungle',chords=[0,1,0,-1],motif=[0,12,7,10,3,7,2,0],scale=[0,2,3,5,7,8,10]),
 dict(key='ft',stem='cryostasis',title='Cryostasis',root=0,bpm=104,bars=64,style='ice',chords=[0,1,0,6],motif=[12,7,3,2,10,7,5,2],scale=[0,2,3,5,7,8,10]),
 dict(key='cc',stem='carousel_of_teeth',title='Carousel of Teeth',root=11,bpm=152,bars=64,style='machine',chords=[0,1,-1,6],motif=[0,1,6,7,6,3,1,0],scale=[0,1,3,5,6,8,10]),
 dict(key='tf',stem='breach_protocol',title='Breach Protocol',root=0,bpm=124,bars=64,style='siege',chords=[0,1,0,6],motif=[0,7,3,5,10,8,7,3],scale=[0,2,3,5,7,8,10]),
]

RIFFS={
  'industrial':([0,3,6,8,10,14],[0,0,1,0,0,6]),
  'march':([0,2,6,8,10,14],[0,0,0,1,0,-1]),
  'breaks':([0,3,7,10,14],[0,1,0,6,1]),
  'halftime':([0,3,8,11],[0,0,6,1]),
  'jungle':([0,2,7,8,11,14],[0,1,0,0,6,1]),
  'ice':([0,10],[0,1]),
  'machine':([0,2,3,6,8,11,14],[0,0,1,0,6,1,-1]),
  'siege':([0,6,8,10,14],[0,0,1,0,6])}
for score in SCORES:
    if score["style"] in RIFFS:
        score["rhythm"],score["motif"]=RIFFS[score["style"]]
    if score["style"]!="lounge":score.pop("scale",None)


def source(name):
    with wave.open(str(OUT/'samples'/(name+'.wav'))) as f:
        assert f.getnchannels()==1 and f.getsampwidth()==2
        data=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        return data,f.getframerate()

def recorded(name,duration,pitch=1,drive=1,attack=.003,reverse=False):
    data,sr=source(name)
    if reverse:data=data[::-1].copy()
    t=np.arange(int(duration*RATE)//2*2)/RATE
    values=np.interp(t*sr*pitch,np.arange(len(data)),data,left=0,right=0)
    peak=max(np.max(np.abs(values)),1e-9);values/=peak
    if drive>1:values=np.tanh(values*drive)/math.tanh(drive)
    values*=np.minimum(1,t/attack)*np.minimum(1,(duration-t)/.08)
    return values

def samples():
    # Real flute/piano fundamentals were measured before tuning; VSCO octave
    # labels differ from MIDI names. No oscillator stands in for an instrument.
    piano=recorded('piano',3.8,REF/277.18263)
    strings=recorded('strings',5.5,REF/523.25113,attack=.7)
    guitar=recorded('guitar',2.4,REF/110,attack=.3)
    pad=strings.copy();pad[:len(guitar)]+=.23*guitar
    metal=recorded('anvil',2.0,.38,attack=.05)
    entries=[('Rusty kick',recorded('kick',.55),56),('Rusty snare',recorded('snare',.48),38),
      ('Rusty hat',recorded('hat',.13),19),('Growly bass',recorded('bass',1.0,REF/55),43),
      ('Distant viola',pad,22),('Upright piano',piano,34),
      ('Breathing flute',recorded('flute',3.4,REF/523.25113,attack=.035),27),
      ('Muted guitar',recorded('mute',.55,REF/110,drive=2.0),34),
      ('Anvil resonance',metal,18),('Rusty crash',recorded('crash',1.1),21),
      ('Reverse guitar',recorded('guitar',1.5,REF/110,attack=.35,reverse=True),19),
      ('Brushed snare',recorded('snare',.38,1.1,attack=.05),14),
      ('Warm piano',piano*.7+np.concatenate((np.zeros(180),piano[:-180]))*.2,31)]
    # Dedicated dark instruments leave the lounge's recorded palette intact.
    chug=recorded('mute',.55,REF/110,drive=4.5)
    fifth=recorded('mute',.55,REF/110*1.4983,drive=3.5)
    power=np.tanh((chug+.45*fifth)*2)
    drone=recorded('guitar',3.3,REF/110,drive=3,attack=.6)
    resonance=recorded('anvil',3.3,.17,attack=.3)
    drone=.7*drone+.24*resonance
    entries += [('Rust power fifth',power,44),('Corroded drone',drone,25),
      ('Crushed kick',recorded('kick',.6,.86,drive=2.8),52),
      ('Factory snare',recorded('snare',.55,.84,drive=3),37),
      ('Overdriven bass',recorded('bass',1.0,REF/55,drive=2.7),40)]
    result=[]
    for name,values,volume in entries:
        values=values/max(1,np.max(np.abs(values)))
        packed=np.clip(np.rint(values*116),-127,127).astype('i1').tobytes()
        assert len(packed)<=131070 and len(packed)%2==0
        result.append((name,packed,volume))
    return result

def cell(note=None,instrument=0,volume=None,effect=0,param=0):
    period=0 if note is None else round(856*2**(-max(0,min(59,note))/12))
    if volume is not None:effect=12;param=volume
    return bytes([(instrument&0xf0)|((period>>8)&15),period&255,((instrument&15)<<4)|effect,param&255])

def lounge_pattern(score,pindex):
    events=[[cell() for _ in range(8)] for _ in range(64)]
    total=score['bars']//4;sparse=pindex==0 or pindex in [total//2,total//2+1]
    def put(row,ch,note,inst,vol):events[row][ch]=cell(note,inst,vol)
    # Cmaj7 Am7 Dm7 G7 / Em7 Am7 Dm7 G7. Minor chords and the dominant
    # need a minor seventh; the previous universal major seventh clashed.
    for bar in range(4):
        absolute=pindex*4+bar;degree=absolute%8;r=bar*16
        base=score['chords'][degree]
        minor=degree in [1,2,4,5,6]
        third=3 if minor else 4;seventh=11 if degree==0 else 10
        tones=[base,base+third,base+7,base+seventh]
        # Root/fifth bass; the last pickup anticipates the next chord's root.
        steps=[0,8] if sparse else [0,6,8,14]
        for i,step in enumerate(steps):
            note=score['chords'][(degree+1)%8] if step==14 else base+(7 if i%2 else 0)
            put(r+step,3,note,4,29)
        for step in [0,7,12]:
            # Compact, correctly spelled third/seventh shells, then fifth.
            low=24+(base+third)%12
            upper=24+(base+(seventh if step==7 else 7))%12
            if upper<=low:upper+=12
            put(r+step,4,low,13,25)
            put(r+step,5,upper,13,20)
        for step in [0,10]:put(r+step,0,12,1,25)
        for step in [4,12]:put(r+step,1,12,12,14)
        if not sparse:
            for step in range(0,16,2):put(r+step,2,12,3,8)
        steps=[0,6,10] if sparse else [0,3,6,8,11,14]
        # A small hummable contour follows each chord's root/third/fifth.
        # Reserve sevenths for the quiet accompaniment, not held melody notes.
        contour=[1,2,1,0,1,2] if absolute%2==0 else [2,1,0,1,2,0]
        melody=[24+tone%12 for tone in tones[:3]]
        for i,step in enumerate(steps):
            note=melody[contour[i]]
            put(r+step,6,note,7,23)
            if step+3<15:put(r+step+3,7,note,7,7)
        # Clear the delayed voice before the next harmony arrives.
        events[r+15][7]=cell(volume=0)
    if pindex==0:
        events[0][0]=cell(12,1,effect=15,param=score['bpm'])
        for ch,pan in enumerate([112,144,180,128,64,192,112,164]):events[1][ch]=cell(effect=8,param=pan)
    return b''.join(b''.join(row) for row in events)


def pattern(score,pindex):
    if score['style']=='lounge':return lounge_pattern(score,pindex)
    events=[[cell() for _ in range(8)] for _ in range(64)]
    style=score['style'];ambient=style=='ambient';total=score['bars']//4
    sparse=ambient or pindex==0 or pindex in [total//2,total//2+1]
    peak=not sparse and pindex>=total-4
    def put(row,ch,note,inst,vol):
        events[row][ch]=cell(note,inst,vol)
    for bar in range(4):
        absolute=pindex*4+bar;r=bar*16;key=score['root']
        # Long pedal centres, chromatic movement and unresolved intervals keep
        # tension without the previous bright rising melodies / major triads.
        shift=score['chords'][(absolute//4)%len(score['chords'])]
        base=max(0,key+shift)
        put(r,4,base+12,15,13 if ambient else 16 if sparse else 19)
        interval=1 if style in ['ambient','ice','machine'] else 6
        if bar%2==0:put(r+5,5,base+12+interval,5,8 if ambient else 10)
        if ambient:
            if bar%2==0:put(r,3,base,18,18)
            if bar in [1,3]:put(r+7,7,base,11,13)
            if bar==3:put(r+12,2,pindex%3,9,10)
            continue
        # Distinct drum signatures: marching, broken beats, half-time weight,
        # frantic machinery and a slow, exposed freeze-tag pulse.
        kicks=[0] if sparse else {
          'industrial':[0,3,8,10], 'march':[0,6,8,11], 'breaks':[0,6,10],
          'halftime':[0,3,10], 'jungle':[0,3,10,14], 'ice':[0,10],
          'machine':[0,2,8,11,14], 'siege':[0,6,8,14]}[style]
        snares=[8] if style in ['halftime','ice'] or sparse else [4,12]
        for step in kicks:put(r+step,0,12,16,36 if sparse else 51)
        for step in snares:put(r+step,1,12,17,24 if sparse else 36)
        if not sparse:
            # No constant disco hat on the heavy arrangements.
            hats=range(0,16,2) if style in ['breaks','jungle','machine'] else [2,6,10,14]
            for step in hats:put(r+step,2,9,3,10 if step%4 else 15)
            if style in ['jungle','breaks']:
                for step in [7,11,15]:put(r+step,1,12,17,14)
            if bar%2==1:put(r+15,7,3 if style=='ice' else 7,9,16)
            if bar==3 and pindex!=total-1:
                for step in [14,15]:put(r+step,1,11,17,26+(step-14)*6)
        if peak and bar==0:put(r,2,7,10,18)
        # Palm-muted root riffs replace flute/piano leads. Each motif uses a
        # different syncopation; semitone / tritone accents stay unresolved.
        steps,notes=score["rhythm"],score["motif"]
        if sparse:steps=[0] if bar%2==0 else [10];notes=[0]
        for i,step in enumerate(steps):
            offset=notes[(i+(2 if pindex>=total//2 and bar%2 else 0))%len(notes)]
            note=max(0,base+offset)
            put(r+step,3,note,18,28 if sparse else 39)
            if not (pindex==0 and bar<2):
                inst=15 if sparse or style=='ice' else 14
                put(r+step,6,note+12,inst,18 if sparse else 27 if style=='ice' else 40 if peak else 35)
        if bar==2 and pindex%2==1:put(r+12,7,base+1,11,16)
        if pindex==total-1 and bar==3:
            for row in range(r+12,64):
                for ch in [0,1,2,3,6,7]:events[row][ch]=cell()
    if pindex==0:
        events[0][0]=cell(effect=15,param=score['bpm']) if ambient else cell(12,16,effect=15,param=score['bpm'])
        for ch,pan in enumerate([112,144,180,128,64,192,112,164]):events[1][ch]=cell(effect=8,param=pan)
    return b''.join(b''.join(row) for row in events)

def module(score,instruments,repeat=1):
    if score['style']=='lounge':instruments=instruments[:13]
    out=bytearray(score['title'].encode()[:20].ljust(20,b'\0'))
    for i in range(31):
        name,data,vol=instruments[i] if i<len(instruments) else ('',b'',0)
        out.extend(name.encode()[:22].ljust(22,b'\0'));out.extend(struct.pack('>HBBHH',len(data)//2,0,vol,0,1))
    count=score['bars']//4;order=list(range(count))*repeat
    out.extend(bytes([len(order),0])+bytes(order).ljust(128,b'\0')+b'8CHN')
    for p in range(count):out.extend(pattern(score,p))
    for _,data,_ in instruments:out.extend(data)
    return out

def render(score,instruments):
    stem=score['stem'];mod=OUT/(stem+'.mod');mod.write_bytes(module(score,instruments))
    duration=score['bars']*4*60/score['bpm']
    # A second arranged cycle gives the delay its preceding loop's tails.
    # Discard the first cycle and decoder end padding for a seamless loop.
    with tempfile.TemporaryDirectory(prefix='fpsloppa-score-') as temp:
        work=Path(temp)/'cycles.mod';work.write_bytes(module(score,instruments,2))
        wet='.14' if score['style']=='lounge' else '.33' if score['style']=='ambient' else '.23'
        delay='aecho=0.85:0.85:73|149|293:0.10|0.08|'+wet
        filters=f'{delay},highpass=f=38,lowpass=f=11500,atrim=start={duration}:end={duration*2},asetpts=PTS-STARTPTS,afade=t=in:d=0.008,afade=t=out:st={duration-.008}:d=0.008'
        target=-22 if score['key']=='title' else -21 if score['key']=='lobby' else -19
        norm=f'loudnorm=I={target}:TP=-3:LRA=10'
        result=subprocess.run(['ffmpeg','-hide_banner','-i',str(work),'-af',filters+','+norm+':print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
        measurement=json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]
        linear=norm+':linear=true'+''.join(':'+k+'='+measurement[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
        dest=OUT/(stem+'.ogg')
        subprocess.run(['ffmpeg','-y','-v','error','-i',str(work),'-map_metadata','-1','-af',filters+','+linear,'-ar','32000','-ac','2','-c:a','libvorbis','-q:a','2','-metadata','title='+score['title'],'-metadata','artist=FPSloppa original score','-metadata','comment=Original eight-channel tracker composition; CC0 1.0',str(dest)],check=True)
    row={**score,'duration':round(duration,3),'mod_bytes':mod.stat().st_size,'ogg_bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'target_lufs':target,'render_measurement':measurement}
    print(score['key'],score['title'],row['duration'],'seconds',row['ogg_bytes'],'bytes',flush=True)
    return row

def main():
    instruments=samples();wanted=sys.argv[1:] or ["title","lobby"]
    if any(key not in ["title","lobby"] for key in wanted):raise SystemExit("Gameplay uses tools/generate_metal_alternates.py; prior industrial renders are archived under docs/audio/industrial-originals")
    if wanted and any(k not in [s['key'] for s in SCORES] for k in wanted):raise SystemExit('Unknown mode key')
    rows=[]
    for score in SCORES:
        if not wanted or score['key'] in wanted:rows.append(render(score,instruments))
    manifest=OUT/'scores.json'
    if wanted and manifest.exists():
        old=json.loads(manifest.read_text());old={r['key']:r for r in old};old.update({r['key']:r for r in rows});rows=[old[s['key']] for s in SCORES if s['key'] in old]
    manifest.write_text(json.dumps(rows,indent=2)+'\n')
if __name__=='__main__':main()
