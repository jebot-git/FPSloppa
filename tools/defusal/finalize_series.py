#!/usr/bin/env python3
"""Align live-capture audio, verify finished videos and make a local watch page."""
from pathlib import Path
import argparse,hashlib,html,json,subprocess
ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads(p.read_text())
def save(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
def main():
 p=argparse.ArgumentParser();p.add_argument('output',type=Path);p.add_argument('--require-all',action='store_true');a=p.parse_args();out=a.output.resolve()
 expected=(ROOT/'maps/de_maplist.txt').read_text().split();rows=[]
 for map_id in expected:
  f=out/map_id
  if not (f/'validation.json').exists():continue
  validation=read(f/'validation.json');match=read(f/'match.json');view=read(f/'view.json')
  assert validation['passed'] and validation['rounds']==6 and validation['players']==12
  assert match['completed'] and match['teams']==[6,6] and match['spectators']==1 and view['completed'] and view['spectator']
  assert match['map_sha256']==hashlib.sha256((ROOT/'maps'/f'{map_id}.bsp').read_bytes()).hexdigest()
  if not (f/'audio-sync.json').exists():
   tempo=view['audio_seconds']/view['seconds'];temporary=f/'match-aligned.mp4'
   subprocess.run(['ffmpeg','-nostdin','-y','-loglevel','error','-i',str(f/'video-silent.mp4'),'-i',str(f/'audio.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-af',f'atempo={tempo:.10f},apad','-shortest','-movflags','+faststart',str(temporary)],check=True,timeout=120)
   temporary.replace(f/'match.mp4');save(f/'audio-sync.json',dict(tempo=tempo,pitch_preserved=True,source_seconds=view['audio_seconds'],video_seconds=view['seconds']))
  video=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(f/'match.mp4')]))
  save(f/'video.json',video)
  streams={s['codec_type']:s for s in video['streams']};v=streams['video'];audio=streams['audio']
  assert v['codec_name']=='h264' and audio['codec_name']=='aac' and (v['width'],v['height'])==(1280,720)
  assert v['avg_frame_rate']=='30/1' and int(v['nb_frames'])==view['frames']
  assert abs(float(video['format']['duration'])-view['seconds'])<.15 and abs(float(audio['duration'])-view['seconds'])<.15
  assert abs(match['seconds']-match['wall_seconds'])<2 and match['time_scale']==1
  for name in ['server.log','client.log','validation.log']:assert 'SCRIPT ERROR:' not in (f/name).read_text(),str(f/name)
  digest=hashlib.sha256((f/'match.mp4').read_bytes()).hexdigest()
  if not (f/'decode.json').exists() or read(f/'decode.json')['sha256']!=digest:
   decoded=subprocess.run(['ffmpeg','-nostdin','-v','error','-threads','2','-i',str(f/'match.mp4'),'-f','null','-'],capture_output=True,check=True,timeout=120)
   assert not decoded.stderr,decoded.stderr.decode()
   save(f/'decode.json',dict(sha256=digest,full_video_audio_decode_passed=True))
  rows.append(dict(map=map_id,seconds=view['seconds'],scores=match['scores'],rounds=6,teams=[6,6],halftime_after=3,validation_frames=validation['frames'],utility=validation['utility'],planted_sites=validation['planted_sites'],round_results=[x['reason'] for x in match['phases'] if x['phase']=='post'],duplicate_frame_fraction=view['duplicate_frames']/view['frames'],video=str((f/'match.mp4').relative_to(ROOT)),video_sha256=digest,bsp_sha256=match['map_sha256']))
 if a.require_all:assert len(rows)==len(expected)
 save(out/'validation.json',dict(completed=len(rows)==len(expected),real_time=True,players_per_team=6,rounds_per_map=6,maps=rows,failures=[]))
 cards=[]
 for row in rows:
  name=row['map'].removeprefix('de_').removesuffix('_rebuilt').title();duration=f"{int(row['seconds'])//60}:{int(row['seconds'])%60:02d}"
  cards.append(f'<article><h2>{html.escape(name)} <small>{row["scores"][0]}–{row["scores"][1]} · {duration}</small></h2><video controls preload="metadata" src="{row["map"]}/match.mp4" poster="{row["map"]}/live.png"></video><p><a href="{row["map"]}/match.mp4">MP4</a> · <a href="{row["map"]}/match.fpsdemo">Game replay</a> · <a href="{row["map"]}/validation.json">Validation</a></p></article>')
 page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DE 6v6 map series</title><style>body{max-width:1040px;margin:40px auto;padding:0 20px;background:#111821;color:#e7eff6;font:17px system-ui}h1{font-size:36px}h2{font-size:25px}small{font-size:17px;color:#adc1d1;margin-left:18px}article{margin:35px 0 50px}video{width:100%;background:#000}a{color:#8ed9ee}p{line-height:1.5}</style><h1>DE · live 6v6 map tests</h1><p>Six rounds per map, switching roles after round three. Scores are Red:Blue. Recorded through a live spectator at 720p / 30 fps, with game audio and the current DE music.</p>'+''.join(cards)+'</html>'
 (out/'index.html').write_text(page)
 print('VERIFIED',len(rows),'maps',out)
if __name__=='__main__':main()
