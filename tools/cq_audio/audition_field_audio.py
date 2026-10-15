"""Create a compact, ordered audition reel from the runtime assets, with cue timings."""
from pathlib import Path
import json,subprocess,tempfile,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'deathmatch/audio/cq_field';OUT=ROOT/'docs/audio/cq-field-20261015';OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((BASE/'manifest.json').read_text());parts=[];timings=[];cursor=0.
for key,row in manifest.items():
 clip=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(BASE/row['file']),'-ac','2','-ar','24000','-f','f32le','-']),dtype='<f4').copy().reshape(-1,2)
 clip=clip[:24000*(5 if row['loop'] else 4)];clip*=.75
 if row['loop']:
  n=min(2400,len(clip)//4);clip[:n]*=np.linspace(0,1,n)[:,None];clip[-n:]*=np.linspace(1,0,n)[:,None]
 parts += [clip,np.zeros((7200,2))];timings.append({'cue':key,'start':round(cursor,3),'seconds':len(clip)/24000});cursor+=(len(clip)+7200)/24000
with tempfile.NamedTemporaryFile(suffix='.wav') as temp:
 with wave.open(temp.name,'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(24000);f.writeframes(np.round(np.concatenate(parts)*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-v','error','-y','-i',temp.name,'-c:a','libvorbis','-q:a','5',str(OUT/'audition.ogg')],check=True)
(OUT/'timings.json').write_text(json.dumps(timings,indent=2)+'\n')
text=['# CQ Frontier sound audition','', '[Play the audition reel](audition.ogg). Loops are excerpted to five seconds; long thunder and impact tails are shortened for this reel. Runtime clips remain intact. The reel uses a common playback gain; in-game buses, distance, occlusion and cue-specific levels apply separately.','', '[Sources, licenses and processing](../../../deathmatch/audio/cq_field/SOURCES.md).','', '| Start | Cue |','| --- | --- |']
for row in timings:
 seconds=int(row['start']);text.append(f"| {seconds//60}:{seconds%60:02d} | {row['cue']} |")
(OUT/'README.md').write_text('\n'.join(text)+'\n');print('CQ_FIELD_AUDITION',round(cursor,2),'seconds')
