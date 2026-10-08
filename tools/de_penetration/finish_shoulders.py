"""Maintain the recording gallery, assemble a chaptered reel, then refresh arena renders.
Wait for the active recording batch so gallery rendering cannot disrupt capture.
"""
from pathlib import Path
import json,subprocess,time,html,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/de-shoulder-recordings'
catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())
rows=[next(r for r in catalog if r['id']==name) for name in ['de_varq_santorini','de_varq_inferno','de_varq_dust2']]
def status():
 result=[]
 for r in rows:
  p=OUT/r['id']/'verified.json'
  if p.exists():
   data=json.loads(p.read_text())
   if data.get('camera_version')==3:result.append(data)
 return result
def gallery(reports):
 done={r['map']:r for r in reports};parts=['<!doctype html><meta charset="utf-8"><title>DE over-the-shoulder matches</title><style>body{background:#111;color:#eee;font:17px system-ui;max-width:1100px;margin:40px auto}video{width:100%;max-height:650px}article{margin:32px 0}a{color:#8cd5ff}</style><h1>DE · 5v5 over-the-shoulder matches</h1><p>Six-round cap · smoothed shoulder camera · collision clearance · isolated game audio.</p>']
 if (OUT/'santorini-inferno-dust2-5v5.mp4').exists():parts.append('<p><a href="santorini-inferno-dust2-5v5.mp4">Three maps — chaptered video</a></p>')
 for row in rows:
  name=row['id'];parts.append('<article><h2>'+html.escape(row['title'])+'</h2>')
  if name in done:
   r=done[name];src=name+'/'+name+'-5v5.mp4';parts.append('<p>'+str(r['scores'][0])+' – '+str(r['scores'][1])+' · '+str(round(r['duration']))+' seconds · full decode verified</p><video controls preload="none" src="'+src+'"></video><p><a href="'+src+'">Download match</a></p>')
  else:parts.append('<p>Queued or recording.</p>')
  parts.append('</article>')
 (OUT/'index.html').write_text('\n'.join(parts))
deadline=time.monotonic()+8*3600
while time.monotonic()<deadline:
 reports=status();gallery(reports)
 if len(reports)==len(rows):break
 time.sleep(20)
else:raise SystemExit('Timed out waiting for complete batch; individual recordings preserved')
listing=[];meta=[';FFMETADATA1','title=Santorini, Inferno and Dust2 — 5v5 shoulder matches'];at=0
for r in reports:
 path=ROOT/r['video'];listing.append("file '"+str(path).replace("'","'\\''")+"'");end=at+round(r['duration']*1000)
 meta+=['[CHAPTER]','TIMEBASE=1/1000','START='+str(at),'END='+str(end),'title='+r['map']];at=end
(OUT/'concat.txt').write_text('\n'.join(listing)+'\n');(OUT/'chapters.ffmeta').write_text('\n'.join(meta)+'\n')
subprocess.run(['ffmpeg','-y','-v','warning','-f','concat','-safe','0','-i',str(OUT/'concat.txt'),'-i',str(OUT/'chapters.ffmeta'),'-map_metadata','1','-map_chapters','1','-c','copy','-movflags','+faststart',str(OUT/'santorini-inferno-dust2-5v5.mp4')],check=True)
gallery(reports)
(OUT/'combined.json').write_text(json.dumps(dict(maps=len(reports),duration_ms=at,path='santorini-inferno-dust2-5v5.mp4',chapters=[r['map'] for r in reports]),indent=2)+'\n')
print('All matches assembled; refreshing arena renders',flush=True)
for script in ['render.py','package.py']:
 with (OUT/('arena-'+script+'.log')).open('w') as f:subprocess.run(['python3',str(ROOT/'tools/arena_imports'/script)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
print('Video reel and updated arena gallery complete',flush=True)
