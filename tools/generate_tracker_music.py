"""Render four original ProTracker scores using compact CC0 recorded instruments.
See deathmatch/audio/music/SOURCES.md. Python stdlib + FFmpeg only.
"""
from pathlib import Path
import math, struct, subprocess, wave, array
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deathmatch/audio/music'
RATE=8363
PERIODS=[856,808,762,720,678,640,604,570,538,508,480,453,428,404,381,360,339,320,302,285,269,254,240,226,214,202,190,180,170,160,151,143,135,127,120,113]

def recorded(name, duration, pitch=1, drive=1, fifth=False):
    with wave.open(str(OUT/'samples'/(name+'.wav'))) as stream:
        source=array.array('h',stream.readframes(stream.getnframes()))
        source_rate=stream.getframerate()
    peak=max(abs(v) for v in source) or 1
    def at(index):
        i=int(index);f=index-i
        return (source[i]*(1-f)+source[i+1]*f)/peak if i+1<len(source) else 0
    values=[];previous=0
    for i in range(int(duration*RATE)//2*2):
        t=i/RATE;index=t*source_rate*pitch
        value=at(index)
        if fifth:value=.7*value+.3*at(index*1.498307)
        value=math.tanh(value*drive)/math.tanh(drive)
        # Short fades suppress tracker clicks; gentle cabinet rolloff on guitar.
        value*=min(1,t/.002,max(0,(duration-t)/.045))
        if drive>1:value=previous*.35+value*.65
        previous=value;values.append(value)
    peak=max(abs(v) for v in values) or 1
    return bytes((max(-127,min(127,round(v/peak*112)))&255) for v in values)

# Recorded note fundamentals are A=110 Hz (guitar) and A=55 Hz (bass),
# despite the libraries' octave labels. MOD reference note is C=130.8128 Hz.
SAMPLES=[recorded('mute',.42,130.8128/110,3.4,True),
         recorded('guitar',1.05,130.8128/110,2.8,True),
         recorded('bass',.82,130.8128/55,1.4),
         recorded('kick',.55),recorded('snare',.45),recorded('hat',.12),
         recorded('crash',1.05),recorded('guitar',1.0,130.8128/110)]
NAMES=['Muted Hofner fifth','Open Hofner fifth','Growly electric bass','Rusty acoustic kick',
       'Rusty acoustic snare','Rusty closed hat','Rusty crash','Picked Hofner lead']
VOLUMES=[48,40,48,60,48,22,27,36]

def cell(note=None,sample=0,effect=0,param=0):
    period=0 if note is None else PERIODS[max(0,min(35,note))]
    return bytes([(sample&0xf0)|((period>>8)&15),period&255,((sample&15)<<4)|(effect&15),param&255])

def pattern(root,variant,bpm,first=False,flavour=0):
    # Sixteenth-note riff with original chromatic/minor intervals; drum fills
    # and an eight-bar melodic break keep a full loop from being one repeated bar.
    riffs=[[0,0,None,0,3,0,5,None,0,0,6,5,None,3,1,None],
           [0,None,0,7,0,3,None,0,5,0,None,6,5,3,None,1],
           [0,None,7,None,10,None,7,5,3,None,5,None,6,5,3,None],
           [0,0,0,None,1,None,0,0,6,5,None,3,0,None,1,None]]
    if flavour==1:
        riffs=[[0,0,7,None,0,3,0,None,5,5,6,5,3,None,1,0],
               [0,None,3,0,7,None,6,5,0,0,None,3,1,0,None,7],
               [0,None,3,None,7,5,None,3,10,None,7,None,6,5,3,1],
               [0,0,None,0,12,None,10,7,6,5,3,None,1,1,0,None]]
    elif flavour==2:
        riffs=[[0,None,0,1,None,0,6,None,0,None,3,5,None,3,1,0],
               [0,0,None,6,5,None,3,0,1,None,0,None,7,6,3,None],
               [0,None,7,None,3,None,6,5,10,None,6,None,7,5,1,None],
               [0,None,12,10,7,None,6,5,0,0,1,None,3,None,1,0]]
    riff=riffs[variant%4];data=bytearray()
    for row in range(64):
        step=row%16;bar=row//16;interval=riff[step]
        if variant==4:
            interval=[0,None,None,None,7,None,None,None,10,None,None,None,5,None,None,None][step]
        transpose=root+(0 if bar<3 else (-2 if variant%2 else 3))
        guitar=cell(None) if interval is None else cell(transpose+interval+12,2 if variant==4 else 1)
        if first and row==0:guitar=cell(transpose+12,1,15,bpm)
        bass_note=transpose+([0,0,5,3][step//4] if variant==4 else 0)
        bass=cell(bass_note,3) if step%2==0 else cell()
        snare=step in [4,12] or bar==3 and step in [13,14,15]
        kick=step in [0,8,10] or variant%2==1 and step==3
        drum=cell(12,5 if snare else 4) if snare or kick else cell()
        if variant==4:
            lead_notes=[12,None,10,None,7,None,5,None,3,None,5,None,7,None,10,None]
            note=lead_notes[step]
            top=cell(root+12+note,8,4,0x23) if note is not None else cell()
        else:
            top=cell(12,7) if row==0 else cell(12,6,12,18 if step%4 else 26) if step%2==0 else cell()
        data.extend(guitar+bass+drum+top)
    return data

def write_mod(filename,title,root,bpm,order,flavour=0):
    out=bytearray(title.encode('ascii')[:20].ljust(20,b'\0'))
    for i in range(31):
        sample=SAMPLES[i] if i<len(SAMPLES) else b''
        name=NAMES[i] if i<len(NAMES) else ''
        out.extend(name.encode()[:22].ljust(22,b'\0'))
        out.extend(struct.pack('>HBBHH',len(sample)//2,0,VOLUMES[i] if sample else 0,0,1))
    out.extend(bytes([len(order),0]));out.extend(bytes(order).ljust(128,b'\0'));out.extend(b'M.K.')
    for variant in range(6):out.extend(pattern(root,variant,bpm,first=variant==0,flavour=flavour))
    for sample in SAMPLES:out.extend(sample)
    path=OUT/filename;path.write_bytes(out)
    return path

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    scores=[('iron_circuit','Iron Circuit',4,146,[0,1,0,3,2,1,4,4,0,1,5,3,2,1,0,3],0),
            ('pressure_lock','Pressure Lock',2,132,[0,3,1,3,2,2,4,4,1,3,5,1,2,3,0,3],0),
            ('foundry_run','Foundry Run',5,154,[0,1,3,0,2,3,4,4,0,5,1,3,2,1,0,3],1),
            ('dark_relay','Dark Relay',0,126,[0,3,1,2,0,1,4,4,2,3,5,1,0,3,2,1],2)]
    for stem,title,root,bpm,order,flavour in scores:
        mod=write_mod(stem+'.mod',title,root,bpm,order,flavour)
        subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(mod),'-map_metadata','-1',
                        '-af','loudnorm=I=-18:TP=-2:LRA=7','-ar','32000','-ac','2','-c:a','libvorbis','-q:a','0',
                        '-metadata','title='+title,'-metadata','artist=Entryway original score','-metadata','comment=Original ProTracker composition; CC0 1.0',str(OUT/(stem+'.ogg'))],check=True)
        print(title,'MOD',mod.stat().st_size,'Ogg',(OUT/(stem+'.ogg')).stat().st_size,flush=True)
if __name__=='__main__':main()
