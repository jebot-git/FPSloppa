"""Publish full-size KOTH render gallery with hash-bound validation receipts."""
from pathlib import Path
import json,html,zipfile,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'test-results/koth-gallery';rows=json.loads((HERE/'installed.json').read_text());parts=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>UT KOTH conversions</title><style>body{background:#10151c;color:#e0e6ee;font:16px system-ui;max-width:1500px;margin:30px auto;padding:16px}a{color:#8ccfff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}img{width:100%;height:auto}figure{margin:0}section{margin:30px 0}figcaption{color:#aab8c8}</style><h1>ChaosUT KOTH conversions</h1><p>Seven playable adaptations. Original world geometry, rebuilt lightmaps, supplied textures or documented project replacements. Fixed hills stay fixed; multiple markers use the existing timed rotation.</p>'];count=0
for row in rows:
 name=row['id'];receipt=json.loads((OUT/name/'renders.json').read_text());assert receipt['bsp_sha256']==row['sha256'],name
 r=row['runtime'];parts.append('<section><h2>'+html.escape(row['title'])+'</h2><p>'+str(r['spawns'])+' safe starts · '+str(r['hills'])+' hills · '+str(r['routes'])+'/'+str(r['total_routes'])+' spawn-to-hill routes · '+('Fixed hill' if r['fixed'] else '30-second rotation')+'</p><div class="grid">')
 for view in receipt['captures']:
  assert [view['width'],view['height']]==[1920,1080];file=name+'/'+view['name']+'.png';assert (OUT/file).exists();count+=1
  parts.append('<figure><a href="'+file+'"><img loading="lazy" src="'+file+'" alt="'+html.escape(view['name'])+'"></a><figcaption>'+html.escape(view['name'])+'</figcaption></figure>')
 parts.append('</div></section>')
(OUT/'index.html').write_text('\n'.join(parts));archive=ROOT.parent/'Builds/FPSloppa-0.21v-UT-KOTH-Renders.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_STORED) as z:
 z.write(OUT/'index.html','index.html')
 for row in rows:
  for p in sorted((OUT/row['id']).glob('*')):
   if p.suffix in ['.png','.json']:z.write(p,p.relative_to(OUT))
report={'maps':len(rows),'images':count,'all_hashes_current':True,'resolution':[1920,1080],'archive':str(archive),'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest()};(HERE/'gallery.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
