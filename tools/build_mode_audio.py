#!/usr/bin/env python3
"""Author deterministic mode-specific SFX and loopable ambience. Requires numpy/ffmpeg."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import sys
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deathmatch/audio/modes'
RATE=32000
SOURCES={}


def read(path):
    path=ROOT/path
    SOURCES[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-f','f32le','-'])
    return np.frombuffer(raw,dtype='<f4').astype(float)


def band(x,low,high):
    f=np.fft.rfftfreq(len(x),1/RATE)
    response=1/np.sqrt(1+(f/high)**8)
    if low:response*=1/np.sqrt(1+(low/np.maximum(f,.01))**8)
    return np.fft.irfft(np.fft.rfft(x)*response,n=len(x))


def noise(rng,n,low=80,high=6500):
    x=band(rng.normal(size=n),low,high)
    return x/max(np.sqrt(np.mean(x*x)),1e-9)


def fit(x,n,pitch=1):
    return np.interp(np.arange(n)*pitch,np.arange(len(x)),x,left=0,right=0)


def save(name,x,cycle=None,ambience=False,ceiling=-20):
    x=x-np.mean(x,axis=0)
    if not ambience:
        edge=min(int(.008*RATE),len(x)//4)
        x[:32]*=np.linspace(0,1,32);x[-edge:]*=np.linspace(1,0,edge)
        energy=np.sum(x*x)/RATE/max(cycle,.06)
        gain=min(10**(-6/20)/max(np.max(np.abs(x)),1e-9),10**(ceiling/20)/max(math.sqrt(energy),1e-9))
    else:
        gain=min(10**(-14/20)/max(np.max(np.abs(x)),1e-9),10**(-25/20)/max(np.sqrt(np.mean(x*x)),1e-9))
    x*=gain
    wav=OUT/(name+'.wav')
    with wave.open(str(wav),'wb') as w:
        w.setnchannels(2 if x.ndim==2 else 1);w.setsampwidth(2);w.setframerate(RATE)
        w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
    path=wav
    if ambience:
        path=wav.with_suffix('.ogg')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(path)],check=True)
        wav.unlink()
    return dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),seconds=len(x)/RATE,
        peak_dbfs=20*np.log10(max(np.max(np.abs(x)),1e-9)),rms_dbfs=20*np.log10(max(np.sqrt(np.mean(x*x)),1e-9)),
        cycle=cycle,sustained_dbfs=10*np.log10(max(np.sum(x*x)/RATE/cycle,1e-18)) if cycle else None)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    natural={name:read('tools/audio-sources/natural-weapons/'+name+'.wav') for name in
             ['pistol9','pistol45','magnum','ak','carbine','smg','shotgun','autoshotgun','sniper','rifle','shotguncock','rifle-reload','bubbles','water']}
    metals=[read(f'deathmatch/audio/recorded/impactMetal_light_{i:03d}.ogg') for i in range(5)]
    wind=read('tools/audio-sources/ambience/wind.wav')
    factory=read('tools/audio-sources/ambience/factory-edited.wav')
    for name,x in natural.items():
        # Trim recorded foley onset as well as reports; retain irregular decay.
        onset=np.flatnonzero(np.abs(x)>.03*np.max(np.abs(x)))[0]
        natural[name]=x[max(0,onset-32):]/max(np.max(np.abs(x)),1e-9)
    catalog={};manifest=[]
    # duration, fundamental, character, firing cycle. Timbre varies by weapon role.
    cs=[(.22,600,'swish',.4),(.20,190,'pistol',.2),(.23,150,'pistol',.225),(.62,85,'shotgun',.875),
        (.38,110,'shotgun',.25),(.15,220,'rifle',.075),(.27,105,'rifle',.0955),(.21,155,'rifle',.0875),
        (.30,95,'rifle',.1),(.75,65,'rifle',1.45),(.35,100,'pistol',.3),(.14,270,'rifle',.066)]
    quake=[(.27,450,'swish',.5),(.27,450,'swish',.5),(.42,105,'chunk',.5),(.6,70,'chunk',.7),
        (.34,80,'launcher',.6),(.13,360,'nail',.1),(.48,60,'launcher',.8),(.14,250,'nail',.1),(.15,85,'electric',.1),(.6,1800,'laser',.8)]
    ut=[(.42,65,'hammer',.8),(.38,160,'bio',.35),(.25,160,'pistol',.4),(.48,1250,'shock',.7),
        (.55,95,'chunk',.9),(.13,280,'rifle',.1),(.5,75,'launcher',.9),(.19,740,'pulse',.12),
        (1.05,42,'launcher',2),(.5,110,'rifle',.7),(.32,1050,'disc',.35),(.42,1550,'warp',.5)]
    ut_alt=[(.27,110,'hammer',.5),(.65,95,'bio',.35),(.2,185,'pistol',.2),(.53,380,'pulse',.7),
        (.4,70,'launcher',.9),(.10,350,'rifle',.06),(.35,110,'launcher',.9),(.15,220,'electric',.1),
        (1.05,42,'launcher',2),ut[9],(.42,620,'disc',.35),(.35,2100,'warp',.5)]
    tribes=[(.3,650,'pulse',.3),(.42,175,'plasma',.6),(.17,230,'rifle',.2),(.65,900,'disc',1.5),
        (.38,90,'launcher',1),(.5,1800,'laser',.6),(.14,120,'electric',.1),(.85,45,'launcher',2.5),
        (.15,440,'repair',.1),(.22,180,'swish',.5),(.28,140,'mechanical',.5),(.12,1100,'target',.2)]
    banks=[('cs16',cs),('quake',quake),('ut99',ut),('tribes',tribes)]
    specs=[]
    for rules,rows in banks:
        for slot,row in enumerate(rows):specs.append((f'{rules}_weapon_{slot}',rules,row))
    specs += [(f'ut99_weapon_{i}_alt','ut99',v) for i,v in enumerate(ut_alt)]
    specs += [(f'cs16_weapon_{i}_alt','cs16',(cs[i][0],cs[i][1],'suppressed',cs[i][3])) for i in [2,7]]
    for rules in ['quake','ut99','tribes']:
        specs.extend([(rules+'_explosion',rules,(1.1,48,'blast',.7)),(rules+'_bounce',rules,(.18,380,'mechanical',.2))])
    specs.append(('ut99_combo','ut99',(1.2,100,'combo',.7)))
    for key,rules,(duration,freq,character,cycle) in specs:
        catalog[key]=[]
        for variant in range(3 if rules=='cs16' else 2):
            rng=np.random.default_rng(int.from_bytes(hashlib.sha256((key+str(variant)).encode()).digest()[:8],'little'))
            n=int(duration*RATE);t=np.arange(n)/RATE;p=1+rng.uniform(-.016,.016)
            # Texture and transient come from recordings, not a shared FM chirp.
            metal=metals[variant%len(metals)]
            mech=fit(natural['rifle-reload'],n,p*1.1)
            impact=fit(metal,n,p*.65)
            blast=fit(natural['shotgun'],n,p*.72)
            slot=int(key.split('_')[2]) if '_weapon_' in key else -1
            if character in ['pistol','rifle','shotgun','chunk','suppressed']:
                if rules=='cs16':
                    source_name={1:'pistol9',2:'pistol45',3:'shotgun',4:'autoshotgun',5:'smg',6:'ak',7:'carbine',8:'rifle',9:'sniper',10:'magnum',11:'smg'}[slot]
                elif character in ['shotgun','chunk']:source_name='shotgun' if slot in [2,4] else 'autoshotgun'
                else:source_name='pistol45' if character=='pistol' else 'sniper' if slot==9 else 'smg'
                x=fit(natural[source_name],n,p*(.88 if rules=='quake' else 1.0))
                # Keep the direct crack and recorded body; tails get shorter with cadence.
                x*=np.exp(-t*(2.5 if cycle<.2 else .65))
                if character=='suppressed':
                    x=band(x,110,1900)*.8+band(mech,500,7200)*.10*np.exp(-t*15)
                elif rules=='quake':
                    x=band(x,65,5200)
                elif rules=='ut99':x=band(x,55,7800)+impact*.10*np.exp(-t*12)
                if character in ['shotgun','chunk'] and cycle>.45:
                    delay=int(min(.23,duration*.42)*RATE)
                    cock=fit(natural['shotguncock'],n,p*1.15)*.16
                    x[delay:]+=cock[:-delay]
                else:
                    delay=int(.038*RATE);x[delay:]+=.055*mech[:-delay]*np.exp(-t[:-delay]*18)
            elif character=='swish':
                # Recorded air/handling with only a quiet broadband extension.
                air=fit(wind[int((3+variant)*RATE):],n,p*1.8)
                air=air/max(np.max(np.abs(air)),1e-9)
                x=band(air,350,6800)*np.sin(np.pi*t/duration)**1.5+.07*mech*np.exp(-t*12)
            elif character in ['launcher','blast','hammer']:
                x=band(blast,40,3100)*(.9 if character=='blast' else .7)
                x+=band(impact,90,6200)*(.65 if character=='hammer' else .12)
                if character=='launcher':
                    air=fit(wind[int((4+variant)*RATE):],n,.7)
                    air=air/max(np.max(np.abs(air)),1e-9)
                    x+=band(air,180,3500)*.09*(1-np.exp(-t*90))*np.exp(-t*8)
            elif character=='nail':
                x=band(fit(natural['smg'],n,p*1.05),120,5600)*.5
                x+=band(fit(metal,n,p*1.2),300,7200)*.32*np.exp(-t*14)
            elif character=='mechanical':x=band(impact,120,7000)+.16*mech
            elif character=='bio':
                wet=fit(natural['water' if key.endswith('_alt') else 'bubbles'],n,p*.68)
                x=band(wet,70,4400)*.95+band(blast,60,1300)*.17*np.exp(-t*15)+mech*.035
            else:
                # Energy effects retain an electrical identity through rough, inharmonic
                # recorded resonances. No sine/FM sweep, synthetic note or periodic vibrato.
                texture=fit(metal,n,p*{'disc':.5,'warp':.8,'laser':1.7,'shock':.8,'pulse':1.25,'plasma':.62,'electric':.4,'repair':.35,'target':1.5,'combo':.5}.get(character,1))
                body=band(blast,65,2200)
                if character in ['electric','repair','target']:
                    raw=fit(factory[int((17+variant)*RATE):],n,p*2.2)
                    raw=raw/max(np.sqrt(np.mean(raw*raw)),1e-9)*.12
                    x=band(raw,160,3500)*(1-np.exp(-t*450))*np.exp(-t*7)+texture*.16
                elif character in ['shock','laser']:
                    x=band(texture,350,7600)*.8+body*.42
                    delay=int(.024*RATE);x[delay:]+=.20*texture[:-delay]*np.exp(-t[:-delay]*9)
                elif character in ['disc','warp']:
                    x=band(texture,140,5200)*.85+body*.22+mech*.10*np.exp(-t*12)
                    delay=int(.047*RATE);x[delay:]+=.24*texture[:-delay]*np.exp(-t[:-delay]*7)
                    if character=='warp':x+=band(fit(natural['water'],n,p*.6),180,3200)*.12
                else:
                    x=band(texture,150,6500)*.6+body*.65
                    if character=='combo':x+=band(fit(natural['sniper'],n,p*.5),40,2400)*.8
                x*=np.exp(-t*(3 if character in ['combo','disc','warp','laser'] else 8))
            if rules=='tribes' and slot>=0:
                # Tribes 2 reference applies only to matching Starsiege roles.
                # Keep T1 cadence/energy budgets; these are independent authored layers.
                air=fit(wind[int((5+variant)*RATE):],n,.85)
                air=air/max(np.max(np.abs(air)),1e-9)
                if slot==0: # Blaster: compact electrical snap, not a pitched chirp.
                    x=band(fit(natural['carbine'],n,p*1.22),250,7000)*.7+band(impact,600,6500)*.28
                elif slot==1: # Plasma: broader low pressure and a rough electrical edge.
                    x=band(fit(natural['shotgun'],n,p*.56),55,2000)*.9+band(impact,700,5000)*.24
                elif slot==2: # Chaingun: brief, repeatable mechanical report.
                    x=band(fit(natural['smg'],n,p*1.08),100,7400)*np.exp(-t*7)+mech*.045
                elif slot==3: # Disc: release punch, metallic spin, then moving air.
                    x=band(blast,75,2800)*.55+band(fit(metal,n,p*.68),350,5800)*.45
                    x+=band(air,350,4000)*.18*(1-np.exp(-t*65))*np.exp(-t*5)
                elif slot in [4,7]: # Grenade tube versus the heavier mortar launch.
                    x=band(fit(natural['shotgun'],n,p*(.38 if slot==7 else .72)),40,2600)*.85
                    x+=fit(natural['shotguncock'],n,p*.85)*.10+band(air,110,2200)*.06*np.exp(-t*5)
                elif slot==5: # Laser: sharp discharge with a short metallic release.
                    x=band(fit(natural['sniper'],n,p*1.12),160,7900)*.6+band(fit(metal,n,p*1.9),1600,7400)*.30*np.exp(-t*8)
                elif slot in [6,8,11]: # ELF/repair/targeting remain restrained continuous tools.
                    raw=fit(factory[int((25+variant)*RATE):],n,p*(1.8 if slot==6 else .7))
                    raw=raw/max(np.sqrt(np.mean(raw*raw)),1e-9)*.15
                    x=band(raw,140,2800 if slot==6 else 1300)*(1-np.exp(-t*450))*np.exp(-t*5)
                    if slot==6:x+=band(impact,700,4600)*.06
            x=band(x,55,9800 if rules=='cs16' else 6500)
            name=key+f'_v{variant}';row=save(name,x,cycle,ceiling=-32 if character=='target' else -26 if character=='repair' else -20)
            row.update(kind=key,character=character,variant=variant);manifest.append(row)
            catalog[key].append('res://deathmatch/audio/modes/'+row['file'])
    # Alt tags without separate sound semantics share the primary variants.
    for rules,rows in banks:
        for slot in range(len(rows)):
            key=f'{rules}_weapon_{slot}';catalog.setdefault(key+'_alt',catalog[key])
    for profile in ['tech','gothic','arena','desert','industrial','coast','alpine','rain','void','inferno']:
        rng=np.random.default_rng(int.from_bytes(hashlib.sha256(profile.encode()).digest()[:8],'little'))
        duration=18;n=duration*RATE;t=np.arange(n)/RATE
        channels=[]
        for side in range(2):
            air=noise(rng,n,70,1300 if profile!='rain' else 6500)
            recorded_wind=fit(np.roll(wind,(side*7+3)*RATE),n)
            if profile in ['tech','industrial','arena','void']:
                x=fit(np.roll(factory,side*RATE*9),n)*.9+air*.008
                if profile=='arena':x=band(x,65,3000)
            else:
                x=recorded_wind*.95+air*.012
                if profile=='coast':x+=noise(rng,n,100,3200)*.07*(.5+.5*np.sin(2*np.pi*t/6))**2
                if profile=='rain':x+=noise(rng,n,700,6500)*.09
                if profile=='gothic':x=band(x,90,1100)
                if profile=='inferno':x+=noise(rng,n,35,200)*.08
                if profile=='alpine':x+=noise(rng,n,180,2300)*.04*np.sin(2*np.pi*t/9)**2
            # Overlap tail with head, then rotate. Both the splice and file seam are continuous.
            fade=RATE*2;weight=np.linspace(0,1,fade)
            joined=x[:fade]*weight+x[-fade:]*(1-weight)
            x=np.concatenate([joined,x[fade:-fade]])
            channels.append(np.roll(x,-fade))
        row=save('ambient_'+profile,np.column_stack(channels),ambience=True)
        row.update(kind='ambience',profile=profile);manifest.append(row)
    (OUT/'catalog.gd').write_text('extends RefCounted\n# Generated by tools/build_mode_audio.py.\nconst SOUNDS='+json.dumps(catalog,indent=1)+'\n')
    (OUT/'manifest.json').write_text(json.dumps(dict(sample_rate=RATE,inputs=SOURCES,outputs=manifest),indent=2)+'\n')
    print('Authored',len(manifest),'clips; total',round(sum((OUT/r['file']).stat().st_size for r in manifest)/1048576,2),'MiB')
    # Playback calibration is part of the build, so replacing a recording never
    # silently leaves the old gain attached to the new waveform.
    subprocess.run([sys.executable,str(ROOT/'tools/balance_weapon_audio.py')],check=True)


if __name__=='__main__':main()
