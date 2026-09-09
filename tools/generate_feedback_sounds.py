"""Author compact item/teleport feedback over CC0 recorded mechanical transients.
Only writes feedback cues; weapon reports and their calibrated trims are untouched.
Optional argument: directory containing HaelDB 3grunt3/4/5.wav from SOURCES.md.
"""
from pathlib import Path
import array,math,random,subprocess,sys,wave
ROOT=Path(__file__).resolve().parents[1]/'deathmatch/audio'
RATE=22050
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'recorded/impactMetal_light_000.ogg'),'-ac','1','-ar',str(RATE),'-f','s16le','-'])
metal=[v/32768 for v in array.array('h',raw)]
def save(path,values):
    peak=max(abs(v) for v in values) or 1
    pcm=array.array('h',(round(v/peak*23170) for v in values))
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(pcm.tobytes())
for name,duration,notes in [('pickup_ammo',.24,[180,260]),('pickup_armor',.32,[330,495]),
    ('pickup_health',.34,[660,880]),('pickup_weapon',.40,[160,240,320]),
    ('pickup_mega',.65,[440,660,880]),('spawn',.75,[110,220,440]),('power_spawn',1.05,[220,330,440,660])]:
    rng=random.Random(18);values=[]
    for i in range(int(duration*RATE)):
        t=i/RATE;value=0
        for n,freq in enumerate(notes):
            phase=t-n*(.075 if name.startswith('pickup') else .13)
            if phase>=0:
                envelope=min(1,phase*600)*math.exp(-phase*(20 if name=='pickup_ammo' else 10))
                value+=(math.sin(math.tau*freq*phase)+.22*math.sin(math.tau*freq*2*phase))*envelope*.32
        if i<len(metal):value+=metal[i]*(.8 if name in ('pickup_ammo','pickup_weapon','pickup_armor') else .2)
        if name in ('spawn','power_spawn'):
            value+=math.sin(math.tau*(55*t+40*.07*(1-math.exp(-t/.07))))*math.exp(-t*8)*min(1,t*300)*.6
            value+=rng.uniform(-1,1)*.13*math.sin(math.pi*t/duration)**2*math.exp(-t*4)
        values.append(value*min(1,(duration-t)/.04))
    save(ROOT/(name+'.wav'),values)
if len(sys.argv)>1:
    for index,source in enumerate(['3grunt3.wav','3grunt4.wav','3grunt5.wav']):
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(Path(sys.argv[1])/source),'-af','highpass=f=80,afade=t=in:d=0.005,afade=t=out:st=0.45:d=0.05','-ac','1','-ar',str(RATE),'-f','s16le','-'])
        save(ROOT/'recorded'/('pain_%d.wav'%index),array.array('h',raw))
