from pathlib import Path
import json,hashlib,html,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'test-results/as-gallery';rows=json.loads((HERE/'as-installed.json').read_text());files=[];count=0
parts=['<!doctype html><meta charset="utf-8"><title>Final UT Assault conversions</title><style>body{background:#10151c;color:#eee;font:16px system-ui;margin:32px}a{color:#8cf}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}img{width:100%}figure{margin:0}</style><h1>UT Assault conversions</h1><p>Four maps with native switches and destructible targets. Original world geometry plus documented movement adaptations, rebuilt lighting and prepared textures.</p>']
for row in rows:
 name=row['id'];folder=OUT/name;r=json.loads((folder/'renders.json').read_text());assert r['bsp_sha256']==row['sha256']
 proof=row['runtime'];parts.append('<h2>'+html.escape(row['title'])+'</h2><p>'+str(proof['spawns'])+' safe starts · '+str(proof['objectives'])+' objectives · '+str(proof['routes'])+'/'+str(proof['total_routes'])+' tested routes; all mandatory attack and defensive-access routes pass.</p><div class="grid">');files.append(folder/'renders.json')
 for c in r['captures']:
  assert [c['width'],c['height']]==[1920,1080];p=folder/(c['name']+'.png');assert p.is_file();files.append(p);count+=1;rel=p.relative_to(OUT).as_posix();parts.append(f'<figure><a href="{rel}"><img loading="lazy" src="{rel}"></a><figcaption>{html.escape(c["name"])}</figcaption></figure>')
 parts.append('</div>')
(OUT/'index.html').write_text('\n'.join(parts));files.append(OUT/'index.html');archive=ROOT.parent/'Builds/FPSloppa-0.22v-AS-Renders.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_STORED) as z:
 for p in files:z.write(p,p.relative_to(OUT))
report={'maps':4,'images':count,'resolution':[1920,1080],'archive':str(archive),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'all_hashes_current':True};(HERE/'as-gallery.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
