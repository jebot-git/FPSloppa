"""Compose/render Skyward Relay, an original ST hybrid electronic action loop.

NumPy + FFmpeg; existing CC0 isolated instrument recordings and original synths.
The reference recording is never read by this generator. --install selects ST.
"""
import argparse
import functools
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave

import numpy as np
import generate_metal_alternates as recorded
from generate_de_music import measure, write

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/audio/skyward-relay'
MUSIC = ROOT / 'deathmatch/audio/music'
AUDIT = ROOT / 'test-results/st-music'
RATE, BPM, BARS = 44100, 156, 80
BEAT = 60 / BPM
N = round(BARS * 4 * BEAT * RATE)
SEED = 270926
EVENTS = []
SOURCES = {}
SECTIONS = [(0, 8, 'Launch signal'), (8, 24, 'Low flight'),
            (24, 40, 'Flag run'), (40, 48, 'Above the clouds'),
            (48, 56, 'Re-entry'), (56, 72, 'Homeward surge'),
            (72, 80, 'Turnaround')]


@functools.lru_cache(None)
def sample(name):
    folder = ROOT / 'docs/audio/copper-fuse/samples' if name in ['horn', 'violin_short', 'cello_short', 'timpani'] else MUSIC / 'samples'
    path = folder / (name + '.wav')
    with wave.open(str(path)) as f:
        assert f.getnchannels() == 1 and f.getsampwidth() == 2
        sr = f.getframerate()
        x = np.frombuffer(f.readframes(f.getnframes()), '<i2').astype(np.float32) / 32768
    SOURCES[name] = dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), license='CC0-1.0')
    return x / max(float(abs(x).max()), .001), sr


def envelope(t, duration, attack=.008, release=.06):
    return np.minimum(t / attack, 1) * np.clip((duration - t) / release, 0, 1)


@functools.lru_cache(512)
def voice(name, midi, seconds, variant=0):
    t = np.arange(round(seconds * RATE)) / RATE
    f = 440 * 2 ** ((midi - 69) / 12)
    if name in ['horn', 'strings', 'violin_short', 'cello_short', 'timpani']:
        x, sr = sample(name)
        roots = dict(horn=59.92, strings=72, violin_short=72, cello_short=36, timpani=56.33)
        y = np.interp(t * sr * 2 ** ((midi - roots[name]) / 12), np.arange(len(x)), x, left=0, right=0)
        y *= envelope(t, seconds, .07 if name == 'strings' else .012, .15 if name in ['strings', 'horn'] else .04)
    elif name == 'sub':
        y = (np.sin(2 * np.pi * f * t) + .10 * np.sin(4 * np.pi * f * t)) * envelope(t, seconds, .008, .045)
    elif name == 'reactor_bass':
        # Band-limited detuned harmonics; synchronized brightness changes
        # supply movement without borrowing a sampled riff or bass patch.
        motion = (.5 + .5 * np.sin(2 * np.pi * (2 if variant % 2 else 1) * t / BEAT - .7)) ** 1.6
        y = np.zeros(len(t))
        for h in range(1, 17):
            if h * f > RATE * .42:break
            level = np.exp(-h / (2.2 + 7 * motion)) / h
            y += level * (np.sin(2 * np.pi * f * h * 1.002 * t) + .65 * np.sin(2 * np.pi * f * h * .998 * t + .3))
        y = np.tanh(y * 1.6) * envelope(t, seconds, .005, .04)
    elif name == 'signal':
        phase = 2 * np.pi * f * t
        y = np.sin(phase + 1.4 * np.sin(phase * 2) * np.exp(-t * 6))
        y += .18 * np.sin(phase * 1.003)
        y *= np.exp(-t * 3.5) * envelope(t, seconds, .008, .06)
    elif name == 'air_pad':
        y = sum(np.sin(2 * np.pi * f * ratio * t + offset) / (i + 1)
                for i, (ratio, offset) in enumerate([(1, 0), (1.003, .5), (.998, 1.3), (2, .2), (3, 1)]))
        y *= envelope(t, seconds, .35, .45) * (.8 + .2 * np.sin(2 * np.pi * .37 * t)) * .45
    else:
        raise ValueError(name)
    return y.astype(np.float32)


def compose():
    EVENTS.clear();rng = np.random.default_rng(SEED)
    buses = {name: np.zeros((N + 4 * RATE, 2), np.float32) for name in ['drums', 'sub', 'bass', 'brass', 'strings', 'signal', 'air']}

    def add(bus, x, beat, gain, pan=0):
        start = round(beat * BEAT * RATE)
        if start < 0:x = x[-start:];start = 0
        count = min(len(x), len(buses[bus]) - start)
        if count <= 0:return
        buses[bus][start:start+count, 0] += x[:count] * gain * math.sqrt((1-pan)/2)
        buses[bus][start:start+count, 1] += x[:count] * gain * math.sqrt((1+pan)/2)

    def note(bus, name, midi, beat, length, gain, pan=0, variant=0):
        add(bus, voice(name, midi, round(length * BEAT, 6), variant), beat, gain, pan)
        EVENTS.append(dict(bus=bus, instrument=name, midi=midi, beat=beat, beats=length, gain=gain, pan=pan))

    def drum(name, beat, gain, pan=0, pitch=1):
        # High-resolution CC0 drum hits already used by the shipped soundtrack.
        x = recorded.source(name)
        path = recorded.OUT / 'samples' / (name + '.wav')
        SOURCES['drum_' + name] = dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), license='CC0-1.0')
        if pitch != 1:x = np.interp(np.arange(0, len(x), pitch), np.arange(len(x)), x)
        add('drums', x, beat + rng.uniform(-.006, .006), gain * rng.uniform(.96, 1.04), pan)
        EVENTS.append(dict(bus='drums', instrument=name, beat=beat, gain=gain, pan=pan, pitch=pitch))

    harmony = [(42, 3), (42, 3), (38, 4), (38, 4), (45, 4), (45, 4), (40, 4), (37, 4)]
    # Independent eight-bar phrase, with longer answers than the bass rhythm.
    theme = [
        [(0, 66, 1.4), (1.75, 69, .65), (2.75, 73, 1.1)],
        [(0, 71, 1.8), (2.25, 68, .65), (3.25, 66, .65)],
        [(0, 69, 2.2), (2.75, 66, .65), (3.5, 64, .4)],
        [(0, 66, 1.4), (2, 62, 1.7)],
        [(0, 64, 1.4), (1.75, 69, 1.0), (3, 73, .75)],
        [(0, 76, 2.2), (2.75, 73, 1.0)],
        [(0, 71, 1.8), (2.25, 68, 1.4)],
        [(0, 68, 1.2), (1.5, 65, .7), (2.5, 61, 1.2)]]
    print('Composing 80 bars / 156 BPM', flush=True)
    for bar in range(BARS):
        base = bar * 4;phase = bar % 8;root, third = harmony[phase]
        launch = bar < 8;floating = 40 <= bar < 48;build = 48 <= bar < 56
        climax = 56 <= bar < 72;turn = bar >= 72
        weight = .60 if launch else .48 if floating else .75 if build else 1.0
        # Half-time backbeat, deliberate kick gaps and alternating offbeat hats.
        kicks = [0, 1.5, 2.75] if bar % 2 == 0 else [0, .75, 3.25, 3.75]
        if floating:kicks = [0] if phase % 2 == 0 else []
        if launch and bar < 4:kicks = [0, 2.75]
        for beat in kicks:drum('kick', base+beat, .92*weight)
        if not floating or phase >= 4:
            drum('snare', base+2, .88*weight)
            drum('snare', base+2.025, .18*weight, -.08, .84)
        if not floating and not launch:
            for beat in ([1.75, 3.5] if bar % 2 else [.75, 3.75]):drum('snare', base+beat, .12, .14, 1.05)
        for i in range(16):
            if (floating or launch) and i % 2:continue
            if turn and phase >= 6 and i % 2:continue
            drum('hat', base+i/4, (.18 if i % 4 == 0 else .08 if i % 2 else .12)*weight, -.30 if i % 2 else .32, 1.04)
        if phase == 0 and not floating:drum('crash', base, .33*weight, -.4 if bar % 16 else .4, .88)
        if phase == 7 and not floating:
            for i in range(4):drum('snare', base+3+i/4, .12+i*.045, -.18+i*.12, 1-i*.045)
        # Sub and articulated mid-bass are separate so distortion cannot bury
        # the fundamental. Kick ducking is applied in the mix below.
        rhythm = [(0, 0, .65), (.875, 7, .45), (1.5, 0, .35), (2.5, 12, .45), (3.25, third, .6)]
        if bar % 2:rhythm = [(0, 0, .9), (1.25, 0, .45), (2.75, 7, .4), (3.5, 0, .45)]
        if floating:rhythm = [(0, 0, 3.6)]
        if launch and bar < 4:rhythm = [(0, 0, 1.6), (2.75, 7, .8)]
        for beat, interval, length in rhythm:
            note('sub', 'sub', root-12+(12 if interval == 12 else 0), base+beat, length, .36*weight)
            if not floating:note('bass', 'reactor_bass', root+interval, base+beat, length, .27*weight, variant=bar%2)
        # Suspended high strings and original glass sequence leave space for
        # movement/combat cues; the main theme gets a brass answer at the peak.
        if bar % 2 == 0:
            for midi, pan in [(root+24, -.58), (root+third+24, .48), (root+31, .15)]:
                note('air', 'air_pad', midi, base, 7.7, .045 if not floating else .10, pan)
                note('strings', 'strings', midi, base, 7.3, .06 if not floating else .12, pan)
        if not floating:
            for i, beat in enumerate([0, .75, 1.5, 2.5, 3.25]):
                note('strings', 'cello_short', root+[0,7,12,third,7][i], base+beat, .42, .12*weight, -.25)
        if launch or floating or build or climax:
            for i, beat in enumerate([.5, 1.25, 2.5, 3.5]):
                pitch = root+[24,31,third+36,26][(i+bar%2)%4]
                note('signal', 'signal', pitch, base+beat, .65, .075 if climax else .11, -.5 if i%2 else .5)
        melodic = 24 <= bar < 40 or climax or turn and phase < 4
        if melodic:
            for beat, midi, length in theme[phase]:
                note('brass', 'horn', midi-12, base+beat, length, .34 if climax else .27, -.12)
                note('signal', 'signal', midi, base+beat, length, .12 if climax else .09, .18)
                if climax:note('strings', 'violin_short', midi+12, base+beat, min(length,.65), .08, .32)
        elif not launch and not floating and phase in [0, 3, 4, 7]:
            for beat in [0, 1.5]:
                note('brass', 'horn', root+12, base+beat, .65, .26*weight, -.15)
                note('brass', 'horn', root+19, base+beat, .65, .10*weight, .20)
        if phase in [0, 4]:note('drums', 'timpani', root, base, 1.6, .19*weight, -.15)
        if phase == 7 and not turn:
            crash = recorded.source('crash')[::-1].copy()
            crash *= np.linspace(0, 1, len(crash))**2
            add('air', crash, base+4-len(crash)/RATE/BEAT, .08, .4)
    # Wrap instrument tails before processing; no fade-out between loops.
    for key, x in buses.items():
        tail = x[N:];buses[key] = x[:N].copy();buses[key][:len(tail)] += tail

    def fx(x, filters):
        warm = 2*RATE
        y = recorded.process(np.concatenate([x[-warm:], x, x[:warm]]), filters)
        return y[warm:warm+N]

    print('Mixing bass, percussion, brass and atmosphere', flush=True)
    buses['bass'] = fx(buses['bass'], 'highpass=f=115,lowpass=f=2300,acompressor=threshold=0.25:ratio=2:attack=12:release=90')
    buses['sub'] = fx(buses['sub'], 'highpass=f=30,lowpass=f=160')
    buses['drums'] = fx(buses['drums'], 'highpass=f=35,equalizer=f=340:t=q:w=1:g=-3,acompressor=threshold=0.4:ratio=2.5:attack=12:release=85')
    buses['brass'] = fx(buses['brass'], 'highpass=f=200,lowpass=f=5800')
    buses['strings'] = fx(buses['strings'], 'highpass=f=300,lowpass=f=6800')
    buses['air'] = fx(buses['air'], 'highpass=f=550,lowpass=f=7400')
    buses['signal'] = fx(buses['signal'], 'highpass=f=600,lowpass=f=6500')
    for bus, delays in [('brass',[(.053,.12),(.113,.08),(.193,.05)]),
                        ('strings',[(.071,.22),(.149,.15),(.251,.08)]),
                        ('signal',[(BEAT*.75,.28),(BEAT*1.5,.14)]),
                        ('air',[(.173,.22),(.347,.16),(.563,.09)])]:
        dry = buses[bus].copy()
        for seconds, gain in delays:buses[bus] += np.roll(dry[:,::-1], round(seconds*RATE), axis=0)*gain
    duck = np.ones(N, np.float32)
    for e in EVENTS:
        if e['instrument'] != 'kick':continue
        start=round(e['beat']*BEAT*RATE);length=round(.16*RATE)
        idx=(np.arange(length)+start)%N
        duck[idx]=np.minimum(duck[idx], .60+.40*(1-np.exp(-np.arange(length)/RATE/.045)))
    buses['bass'] *= duck[:,None];buses['sub'] *= duck[:,None]
    mix = sum(buses.values())
    mix = fx(mix, 'highpass=f=28,equalizer=f=240:t=q:w=0.8:g=-2,acompressor=threshold=0.7:ratio=1.6:attack=22:release=140')
    return mix


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true');args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);AUDIT.mkdir(parents=True,exist_ok=True)
    mixed=compose();assert np.isfinite(mixed).all()
    raw=AUDIT/'skyward-relay-unmastered.wav'
    write(raw,mixed*.90/max(1,float(abs(mixed).max())))
    stats=measure(raw)
    norm='loudnorm=I=-20:TP=-3:LRA=10:linear=true'+''.join(':'+k+'='+stats[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
    norm+=f',afade=t=in:d=0.012,afade=t=out:st={N/RATE-.015:.9f}:d=0.015'
    dest=MUSIC/'skyward_relay.ogg' if args.install else OUT/'Skyward-Relay.ogg'
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-af',norm,'-ar',str(RATE),'-c:a','libvorbis','-q:a','5','-metadata','title=Skyward Relay','-metadata','artist=FPSloppa original music','-metadata','comment=Original CC0 ST composition; 80-bar loop',str(dest)],check=True)
    audio=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(dest),'-ar',str(RATE),'-ac','2','-f','f32le','-']),'<f4').reshape(-1,2)
    stats=measure(dest);seam=float(abs(audio[0]-audio[-1]).max())
    assert len(audio)==N and np.isfinite(audio).all() and abs(audio).max()<1
    assert abs(float(stats['input_i'])+20)<.6 and float(stats['input_tp'])<=-2.8 and seam<.003
    write(AUDIT/'loop-boundary.wav',np.concatenate([audio[-6*RATE:],audio[:6*RATE]]))
    write(AUDIT/'theme-preview.wav',audio[round(24*4*BEAT*RATE):round(40*4*BEAT*RATE)])
    row=dict(key='st',stem='skyward_relay',title='Skyward Relay',bpm=BPM,bars=BARS,duration=N/RATE,
             ogg_bytes=dest.stat().st_size,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),target_lufs=-20,
             measured_lufs=float(stats['input_i']),true_peak_dbtp=float(stats['input_tp']),loop=True,
             loop_offset=0,loop_step=seam,sample_rate=RATE,license='CC0-1.0',seed=SEED,
             generator='tools/generate_st_music.py --install',source_format='recorded-sample-and-synthesis-arrangement',
             source_file='skyward_relay.score.json',sections=[dict(start_bar=a,end_bar=b,name=c) for a,b,c in SECTIONS])
    (MUSIC/'skyward_relay.score.json' if args.install else OUT/'score.json').write_text(json.dumps(dict(row,events=EVENTS),indent=2)+'\n')
    (OUT/'sources.json').write_text(json.dumps(SOURCES,indent=2)+'\n')
    if args.install:
        rows=[r for r in json.loads((MUSIC/'scores.json').read_text()) if r['key']!='st']+[row]
        (MUSIC/'scores.json').write_text(json.dumps(rows,indent=2)+'\n')
    (AUDIT/'render.json').write_text(json.dumps(row,indent=2)+'\n')
    print(json.dumps(row,indent=2),flush=True)


if __name__=='__main__':main()
