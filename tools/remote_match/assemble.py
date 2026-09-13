"""Validate completed review segments and assemble the chaptered test video."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/remote-all-modes'
PIECES=ROOT/'video-output/remote-all-modes-2026-09-12-reviewed-segments'
VIDEO=ROOT/'video-output/remote-all-modes-2026-09-12.mp4'

def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-show_chapters','-of','json',str(path)],text=True))

segments=[];offsets=[0.0];stream_shape=None
for index in range(12):
    path=PIECES/f'{index:03}.mp4'
    details=probe(path)
    videos=[s for s in details['streams'] if s['codec_type']=='video']
    audios=[s for s in details['streams'] if s['codec_type']=='audio']
    assert len(videos)==1 and len(audios)==1 and videos[0]['codec_name']=='h264' and audios[0]['codec_name']=='aac',path
    assert videos[0]['r_frame_rate']=='30/1',videos
    shape=(videos[0]['width'],videos[0]['height'],videos[0]['pix_fmt'],audios[0]['sample_rate'],audios[0]['channels'])
    if stream_shape is None:stream_shape=shape
    assert shape==stream_shape,(path,shape,stream_shape)
    assert float(details['format']['duration'])>= (56 if index==11 else 60),details
    log=(PIECES/f'{index:03}-render.log').read_text()
    assert 'SCRIPT ERROR:' not in log and 'Demo movie complete' in log,path
    segments.append(path);offsets.append(offsets[-1]+float(details['format']['duration']))
audit=json.loads((OUT/'demo-audit.json').read_text())
def video_time(seconds):
    index=min(11,int(seconds//60))
    return offsets[index]+seconds-index*60
metadata=[';FFMETADATA1','title=FPSloppa — remote eight-client all-mode test — 2026-09-12']
names={'dm':'DEATHMATCH','tdm':'TEAM DEATHMATCH','ctf':'CAPTURE THE FLAG','koth':'KING OF THE HILL','ig':'INSTAGIB','if':'INSTAFREEZE','ft':'FREEZE TAG','cc':'CHAINSAW CIRCUS','tf':'TEAM FORTRESS','as':'ASSAULT'}
for index,row in enumerate(audit['segments']):
    start=video_time(row['start'])
    end=video_time(audit['segments'][index+1]['start']) if index+1<len(audit['segments']) else offsets[-1]
    metadata += ['[CHAPTER]','TIMEBASE=1/1000',f'START={int(start*1000)}',f'END={int(end*1000)}',f'title={names[row["mode"]]} — {row["map"]} — {row["rules"]}']
chapters=OUT/'chapters.ffmeta';chapters.write_text('\n'.join(metadata)+'\n')
playlist=OUT/'reviewed-concat.txt';playlist.write_text(''.join("file '"+str(path)+"'\n" for path in segments))
subprocess.run(['ffmpeg','-nostdin','-n','-f','concat','-safe','0','-i',str(playlist),'-i',str(chapters),
                '-map','0:v','-map','0:a','-map_metadata','1','-map_chapters','1','-c','copy','-movflags','+faststart',str(VIDEO)],
               check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
details=probe(VIDEO)
assert len(details['chapters'])==10 and 716<=float(details['format']['duration'])<719,details
receipt=dict(path=str(VIDEO),bytes=VIDEO.stat().st_size,sha256=hashlib.file_digest(VIDEO.open('rb'),'sha256').hexdigest(),
             duration=float(details['format']['duration']),chapters=details['chapters'],streams=details['streams'])
(OUT/'video-validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('VIDEO_ASSEMBLED',VIDEO,'seconds',receipt['duration'],'bytes',receipt['bytes'])
