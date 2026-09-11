"""Original CC0 metal scores. Pass --install to select the rendered set in-game.
Requires numpy and FFmpeg. Prepared recorded instruments live beside the renders.
"""
from pathlib import Path
import argparse, functools, hashlib, json, math, subprocess, tempfile, wave, shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/audio/metal-alternates';RATE=44100
SCORES=[
 dict(key='dm',name='Iron Teeth',stem='dm_iron_teeth',current='iron_circuit',bpm=138,bars=64,root=40,style='thrash'),
 dict(key='cc',name='Chain Drive',stem='cc_chain_drive',current='carousel_of_teeth',bpm=152,bars=64,root=38,style='groove'),
 dict(key='ft',name='Cold Anvil',stem='ft_cold_anvil',current='cryostasis',bpm=104,bars=64,root=36,style='doom'),
 dict(key='tdm',name='Breach Formation',stem='tdm_breach_formation',current='pressure_lock',bpm=128,bars=64,root=38,style='march'),
 dict(key='ctf',name='Redline Relay',stem='ctf_redline_relay',current='dark_relay',bpm=146,bars=64,root=40,style='gallop'),
 dict(key='koth',name='Crowned in Rust',stem='koth_crowned_in_rust',current='high_ground',bpm=116,bars=64,root=36,style='sludge'),
 dict(key='ig',name='Razor Current',stem='ig_razor_current',current='foundry_run',bpm=166,bars=64,root=42,style='speed'),
 dict(key='tf',name='Siege Engine',stem='tf_siege_engine',current='breach_protocol',bpm=124,bars=64,root=37,style='battle'),
]

@functools.lru_cache(None)
def source(name):
    with wave.open(str(OUT/'samples'/(name+'.wav'))) as f:
        assert f.getframerate()==RATE and f.getnchannels()==1
        x=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float32)/32768
    return x/max(float(np.max(np.abs(x))),.001)

def fundamental(name):
    x=source(name)[int(RATE*.1):int(RATE*.38)]
    n=1<<int(np.ceil(np.log2(len(x)*2)))
    z=np.fft.rfft(x,n);c=np.fft.irfft(z*np.conj(z),n)
    lo=int(RATE/100);hi=int(RATE/70);i=lo+np.argmax(c[lo:hi])
    correction=.5*(c[i-1]-c[i+1])/(c[i-1]-2*c[i]+c[i+1])
    return RATE/(i+correction)
TUNING={}

@functools.lru_cache(512)
def note(name,midi,seconds):
    data=source(name);freq=440*2**((midi-69)/12)
    pitch=freq/(TUNING[name] if name in TUNING else 55)
    times=np.arange(int(seconds*RATE))/RATE
    x=np.interp(times*RATE*pitch,np.arange(len(data)),data,left=0,right=0)
    # Audible pick attack, explicit palm-mute decay and a short release.
    x*=np.minimum(1,times/.002)*np.minimum(1,(seconds-times)/.025)
    if name.startswith('mute'):x*=np.exp(-times*8)
    return x.astype(np.float32)

def process(x,filters):
    channels=1 if x.ndim==1 else x.shape[1]
    raw=subprocess.run(['ffmpeg','-v','error','-f','f32le','-ar',str(RATE),'-ac',str(channels),'-i','pipe:0','-af',filters,'-f','f32le','-ar',str(RATE),'-ac',str(channels),'pipe:1'],input=x.astype('<f4').tobytes(),capture_output=True,check=True).stdout
    return np.frombuffer(raw,dtype='<f4').reshape((-1,channels))[:len(x)].copy().squeeze()

def put(bus,sample,at,gain=1):
    start=max(0,round(at*RATE));n=min(len(sample),len(bus)-start)
    if n>0:bus[start:start+n]+=sample[:n]*gain

def compose(score):
    step=60/score['bpm']/4;duration=score['bars']*16*step
    n=round((duration+3)*RATE);left=np.zeros(n,np.float32);right=left.copy();bass=left.copy();drums=np.zeros((n,2),np.float32)
    rng=np.random.default_rng({'dm':771,'cc':772,'ft':773,'tdm':774,'ctf':775,'koth':776,'ig':777,'tf':778}[score['key']]);events=[]
    def drum(name,at,level,pan=0):
        raw=source(name);gain_l=math.sqrt((1-pan)/2);gain_r=math.sqrt((1+pan)/2)
        put(drums[:,0],raw,at,level*gain_l);put(drums[:,1],raw,at+.002,level*gain_r)
    for bar in range(score['bars']):
        start=bar*16*step;phase=bar%8;style=score['style'];root=score['root']
        exposed=bar in range(32,40);intro=bar<4;peak=bar>=48
        # Riffs are guitar phrases, with open chord accents answering muted
        # low-string pedals. Distinct eight-bar responses and a middle break.
        if style=='thrash':
            steps=[0,2,3,4,6,8,10,11,12,14];notes=[0,0,0,3,0,0,0,0,6,5]
            if phase>=4:notes=[0,0,0,1,0,0,0,0,5,3]
            kicks=[0,2,3,6,8,10,11,14];snares=[4,12];opens=[4,12,14]
        elif style=='groove':
            steps=[0,2,3,6,8,11,12,14];notes=[0,0,1,0,0,6,5,1]
            if phase>=4:notes=[0,0,3,1,0,1,0,-2]
            kicks=[0,2,3,6,10,11,14];snares=[8];opens=[6,12]
        elif style=='march':
            steps=[0,2,4,6,8,10,12,14];notes=[0,0,3,0,0,1,5,3] if phase<4 else [0,0,1,0,0,6,3,1]
            kicks=[0,3,6,8,11,14];snares=[4,12];opens=[4,12]
        elif style=='gallop':
            steps=[0,2,3,4,6,7,8,10,11,12,14];notes=[0,0,0,7,5,5,0,0,0,3,1] if phase<4 else [0,0,0,5,3,3,0,0,0,1,0]
            kicks=[0,2,3,6,8,10,11,14];snares=[4,12];opens=[4,7,12,14]
        elif style=='sludge':
            steps=[0,3,6,8,10,14];notes=[0,0,6,0,5,1] if phase<4 else [0,0,1,0,3,6]
            kicks=[0,3,10,14];snares=[8];opens=[6,8,14]
        elif style=='speed':
            steps=[0,1,2,4,6,7,8,9,10,12,14,15];notes=[0,0,0,1,0,0,0,0,0,6,3,1] if phase<4 else [0,0,0,3,0,0,0,0,0,5,1,0]
            kicks=[0,2,3,6,8,10,11,14];snares=[4,12];opens=[4,12]
        elif style=='battle':
            steps=[0,3,4,6,8,11,12,14];notes=[0,0,5,3,0,0,6,1] if phase<4 else [0,0,3,1,0,0,5,3]
            kicks=[0,3,6,8,10,14];snares=[4,12];opens=[4,6,12,14]
        else:
            steps=[0,6,8,14];notes=[0,0,1,6] if phase>=4 else [0,0,3,1]
            kicks=[0,3,10];snares=[8];opens=[0,8]
        if phase==7 and not intro:
            notes[-2:]=[6,1] if style!='doom' else [1,0]
        if exposed:
            steps=[0,8] if style!='doom' else [0];notes=[0,1];opens=steps;kicks=[0];snares=[8]
        if intro and bar<2:
            steps=[0,8];notes=[0,0];opens=[8];kicks=[0];snares=[]
        for i,beat in enumerate(steps):
            pitch=root+notes[i%len(notes)]
            until=(steps[i+1]-beat if i+1<len(steps) else 16-beat)*step
            opened=beat in opens
            length=min(2.4,until*(1.04 if opened else .72))
            length=max(.065,length)
            at=start+beat*step
            gain=.65 if exposed else .87 if intro else 1.0
            # Independent recorded takes, different picking offsets and slight
            # dynamics create the width; no duplicate-with-delay pseudo stereo.
            for bus,take,delay in [(left,'a',0),(right,'b',.009)]:
                instrument=('guitar_' if opened else 'mute_')+take
                timing=at+delay+rng.uniform(-.002,.002)
                for interval,level,offset in [(0,.67,0),(7,.42,.003),(12,.16,.006)]:
                    put(bus,note(instrument,pitch+interval,round(length,4)),timing+offset,gain*level*rng.uniform(.94,1.0))
            put(bass,note('bass',pitch-12,round(max(.07,until*.94),4)),at,.65 if exposed else .87)
            events.append({'beat':round(bar*4+beat/4,2),'root_midi':pitch,'articulation':'open power chord' if opened else 'palm mute','duration':round(length,4)})
        for beat in kicks:drum('kick',start+beat*step,.83 if exposed else 1.12)
        for beat in snares:drum('snare',start+beat*step,.80 if exposed else 1.02,0.06)
        if not intro or bar>=2:
            for beat in range(0,16,2):drum('hat',start+beat*step,.12 if exposed else .18 if beat%4 else .25,-.35)
        if bar%4==0 and not exposed:drum('crash',start,.33 if intro else .45,(-.6 if bar%8==0 else .6))
        if phase==7 and not exposed:
            for beat in [13,14,15]:drum('snare',start+beat*step,.46+.10*(beat-13),.1)
            if style!='doom':
                for beat in [12,13,14,15]:drum('kick',start+beat*step,.8)
        if peak and style in ['thrash','gallop','speed'] and phase%2:
            for beat in [1,9]:drum('kick',start+beat*step,.75)
    # Amp saturation runs after chord voices combine, followed by speaker-like
    # filtering: low-end tightening, low-mid cut and guitar presence.
    amp='highpass=f=85,volume=7,asoftclip=type=tanh:oversample=2,equalizer=f=430:t=q:w=1:g=-4,equalizer=f=1700:t=q:w=0.8:g=3,lowpass=f=5200:p=2,lowpass=f=6500:p=2'
    left=process(left,amp);right=process(right,amp)
    bass=process(bass,'highpass=f=32,volume=1.8,asoftclip=type=tanh,lowpass=f=2100,equalizer=f=85:t=q:w=1:g=2')
    drums=process(drums,'highpass=f=35,equalizer=f=3300:t=q:w=0.8:g=2')
    # Tight guitars remain forward; only the drum room has a short stereo tail.
    room=drums.copy()
    for seconds,level in [(.037,.10),(.071,.065)]:
        delay=round(seconds*RATE);room[delay:]+=drums[:-delay,::-1]*level
    mixed=np.column_stack((left*.50+right*.045+bass*.34,right*.50+left*.045+bass*.34))+room*.70
    # Fold the render's tail into the beginning, then remove the sample-edge click.
    frames=round(duration*RATE);tail=mixed[frames:];mixed=mixed[:frames].copy();mixed[:len(tail)]+=tail
    fade=round(.008*RATE);mixed[:fade]*=np.linspace(0,1,fade)[:,None];mixed[-fade:]*=np.linspace(1,0,fade)[:,None]
    return mixed,events,duration

def master(score,mixed,events,duration):
    with tempfile.TemporaryDirectory(prefix='fpsloppa-metal-') as td:
        path=Path(td)/'mix.wav';peak=max(1,float(np.max(np.abs(mixed))))
        with wave.open(str(path),'wb') as f:
            f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(np.rint(mixed/peak*30000).astype('<i2').tobytes())
        norm='loudnorm=I=-19:TP=-3:LRA=10'
        measured=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af',norm+':print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
        stats=json.JSONDecoder().raw_decode(measured.stderr[measured.stderr.rfind('{'):])[0]
        af=norm+':linear=true'+''.join(':'+k+'='+stats[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
        dest=OUT/(score['stem']+'.ogg')
        subprocess.run(['ffmpeg','-y','-v','error','-i',str(path),'-af',af,'-ar','44100','-c:a','libvorbis','-q:a','3','-metadata','title='+score['name'],'-metadata','artist=FPSloppa alternate metal score','-metadata','comment=Original CC0 composition; recorded CC0 instruments',str(dest)],check=True)
    return {**score,'duration':round(duration,3),'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'target_lufs':-19,'events':events}

def install(rows):
    music=ROOT/'deathmatch/audio/music';archive=ROOT/'docs/audio/industrial-originals'
    keys={row['key'] for row in rows}
    if keys!={s['key'] for s in SCORES}:raise SystemExit('Render all eight metal scores before installing')
    # Preserve the complete prior soundtrack once for A/B comparison. The two
    # title/lobby renders remain byte-identical in the active music directory.
    if not archive.exists():
        archive.mkdir(parents=True)
        for source_file in music.iterdir():
            if source_file.is_file():shutil.copy2(source_file,archive/source_file.name)
    manifest=json.loads((music/'scores.json').read_text())
    installed={}
    for row in rows:
        dest=music/(row['current']+'.ogg');shutil.copy2(OUT/(row['stem']+'.ogg'),dest)
        source_path=music/(row['current']+'.score.json')
        source_path.write_text(json.dumps(row,indent=2)+'\n')
        legacy_mod=music/(row['current']+'.mod')
        if legacy_mod.exists():legacy_mod.replace(archive/legacy_mod.name)
        installed[row['key']]={k:v for k,v in row.items() if k!='events'}
        installed[row['key']].update(stem=row['current'],title=row['name'],ogg_bytes=dest.stat().st_size,source_format='recorded-sample-arrangement',source_file=source_path.name,sample_rate=RATE,generator='tools/generate_metal_alternates.py')
    manifest=[installed.get(row['key'],row) for row in manifest]
    (music/'scores.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Installed eight gameplay tracks; title/lobby and archived comparisons preserved',flush=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('modes',nargs='*',help='Optional mode keys to render')
    parser.add_argument('--install',action='store_true',help='Install all eight rendered gameplay scores; preserve title/lobby')
    args=parser.parse_args()
    if set(args.modes)-{s['key'] for s in SCORES}:parser.error('Unknown mode key')
    OUT.mkdir(parents=True,exist_ok=True)
    for name in ['guitar_a','guitar_b','mute_a','mute_b']:TUNING[name]=fundamental(name)
    print('Measured guitar fundamentals:',TUNING,flush=True)
    manifest=OUT/'scores.json'
    prior=json.loads(manifest.read_text())['scores'] if manifest.exists() else []
    rows={row['key']:row for row in prior}
    for score in SCORES:
        if args.modes and score['key'] not in args.modes:continue
        mixed,events,duration=compose(score);row=master(score,mixed,events,duration);rows[row['key']]=row
        print(score['name'],row['duration'],'seconds',row['bytes'],'bytes',flush=True)
    ordered=[rows[s['key']] for s in SCORES if s['key'] in rows]
    manifest.write_text(json.dumps({'tuning_hz':TUNING,'scores':ordered},indent=2)+'\n')
    if args.install:install(ordered)
if __name__=='__main__':main()
