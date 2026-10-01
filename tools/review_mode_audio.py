#!/usr/bin/env python3
"""Validate delivered PCM/Vorbis audio and render a level-matched listening reel."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
BANK=ROOT/'deathmatch/audio/modes'
RATE=32000


def decode(path,channels=1):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac',str(channels),'-ar',str(RATE),'-f','f32le','-'])
    return np.frombuffer(raw,dtype='<f4').reshape(-1,channels).astype(float)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=ROOT/'test-results/audio-review')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((BANK/'manifest.json').read_text());checks=[];failures=[]
    trims={name:float(value) for name,value in re.findall(r'"([^"]+)":\s*(-?[\d.]+)',(ROOT/'deathmatch/audio/weapon_levels.gd').read_text())}
    for row in manifest['outputs']:
        path=BANK/row['file'];ambient=row['kind']=='ambience';x=decode(path,2 if ambient else 1)
        peak=float(np.max(np.abs(x)));dc=float(np.max(np.abs(np.mean(x,axis=0))))
        item=dict(file=path.name,seconds=len(x)/RATE,peak_dbfs=20*np.log10(max(peak,1e-12)),dc=dc)
        if not np.isfinite(x).all() or peak>=.999:failures.append(path.name+': nonfinite/clipped')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:failures.append(path.name+': hash mismatch')
        if ambient:
            seam=float(np.max(np.abs(x[0]-x[-1])));typical=float(np.percentile(np.abs(np.diff(x,axis=0)),99))
            item.update(loop_seam=seam,adjacent_p99=typical)
            if seam>max(.003,typical*2):failures.append(path.name+': loop seam outlier')
        else:
            energy=float(np.sum(x*x)/RATE/row['cycle']);item['sustained_dbfs']=10*np.log10(max(energy,1e-18))
            if peak>10**(-5.95/20) or item['sustained_dbfs']> -19.95:failures.append(path.name+': exceeds weapon level budget')
            if max(abs(x[0,0]),abs(x[-1,0]))>.0001:failures.append(path.name+': endpoint click')
            key='res://deathmatch/audio/modes/'+path.name
            if key not in trims:failures.append(path.name+': missing runtime normalization')
            item['runtime_gain_db']=trims.get(key,0)
            item['normalized_peak_dbfs']=item['peak_dbfs']+trims.get(key,0)
            if item['normalized_peak_dbfs']> -2.95:failures.append(path.name+': normalized peak exceeds headroom')
        checks.append(item)
    # Dry authored reports at the game's -4 dB shot level, plus background beds
    # at their -12 dB playback level. This is a listening reel, not HRTF output.
    blocks=[];timeline=[];cursor=0.0
    selections={
        'CS: Glock, USP, MP5, AK, M4, M249, AWP, Deagle':[f'cs16_weapon_{i}_v0.wav' for i in [1,2,5,6,7,8,9,10]],
        'CS suppressor pairs: USP then M4':['cs16_weapon_2_v0.wav','cs16_weapon_2_alt_v0.wav','cs16_weapon_7_v0.wav','cs16_weapon_7_alt_v0.wav'],
        'Quake: shotguns, nailguns, rocket, lightning':[f'quake_weapon_{i}_v0.wav' for i in [2,3,5,7,6,8]],
        'UT: hammer, bio, shock beam/orb, flak, pulse':['ut99_weapon_0_v0.wav','ut99_weapon_1_v0.wav','ut99_weapon_3_v0.wav','ut99_weapon_3_alt_v0.wav','ut99_weapon_4_v0.wav','ut99_weapon_7_v0.wav'],
        'Tribes: blaster, plasma, disc, laser, mortar, repair':[f'tribes_weapon_{i}_v0.wav' for i in [0,1,3,5,7,8]],
    }
    for label,files in selections.items():
        block=np.zeros((int(len(files)*1.25*RATE),2))
        for i,name in enumerate(files):
            x=decode(BANK/name)[:,0];gain=10**(((-10 if name.startswith('cs16') and '_alt_' in name else -4)+trims['res://deathmatch/audio/modes/'+name])/20)
            start=int((i*1.25+.05)*RATE);count=min(len(x),len(block)-start);block[start:start+count]+=x[:count,None]*gain
        blocks.append(block);timeline.append(dict(start=cursor,end=cursor+len(block)/RATE,label=label));cursor+=len(block)/RATE
    for profile in ['tech','gothic','arena','desert','industrial','coast','alpine','rain']:
        x=decode(BANK/f'ambient_{profile}.ogg',2)[:8*RATE]*10**(-12/20)
        fade=int(.2*RATE);x[:fade]*=np.linspace(0,1,fade)[:,None];x[-fade:]*=np.linspace(1,0,fade)[:,None]
        blocks.append(x);timeline.append(dict(start=cursor,end=cursor+8,label='Ambience: '+profile));cursor+=8
    reel=np.concatenate(blocks);path=out/'mode-audio-audition.wav'
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.round(reel*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','5',str(path.with_suffix('.ogg'))],check=True)
    (out/'audio-validation.json').write_text(json.dumps(dict(clips=len(checks),failures=failures,clips_measured=checks,timeline=timeline),indent=2)+'\n')
    (out/'audition-timeline.txt').write_text('\n'.join(f"{r['start']:06.2f}–{r['end']:06.2f} {r['label']}" for r in timeline)+'\n')
    print(json.dumps(dict(clips=len(checks),failures=failures,audition=str(path))))
    raise SystemExit(bool(failures))


if __name__=='__main__':main()
