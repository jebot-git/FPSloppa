"""Package verified full-resolution arena renders into an offline gallery."""
from pathlib import Path
import html,json,hashlib,zipfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'test-results/arena-gallery'
rows=json.loads((HERE/'conversions.json').read_text());catalog={r['id']:r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())};proof={r['id']:r for r in json.loads((HERE/'validation.json').read_text())['results']}
parts=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Classic arena renders</title><style>body{background:#10151c;color:#e0e6ee;font:16px system-ui;max-width:1500px;margin:30px auto;padding:16px}a{color:#8ccfff}section{padding:25px 0;border-bottom:1px solid #394454}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}img{width:100%;height:auto}figure{margin:0}figcaption{font-size:14px;color:#9faec1}h2{margin-bottom:8px}</style><h1>Classic arena renders</h1><p>Local imports. Full 1920 × 1080 renders using runtime baked lighting and textures. Click an image for the full-size PNG. Bot-route coverage is shown explicitly.</p>'];images=0
for row in rows:
 name=row['id'];receipt=json.loads((OUT/name/'renders.json').read_text());assert receipt['bsp_sha256']==row['sha256'],name
 p=proof[name];parts.append('<section><h2>'+html.escape(catalog[name]['title'])+'</h2><p>'+html.escape(name)+f' · {p["baked_faces"]:,} baked faces · {p["safe_spawns"]}/{p["spawns"]} safe starts · {p["spawn_routes"][0]}/{p["spawn_routes"][1]} directed spawn routes · {p["pickup_routes"][0]}/{p["pickup_routes"][1]} reachable pickups</p><div class="grid">')
 for view in receipt['captures']:
  assert [view['width'],view['height']]==[1920,1080]
  file=name+'/'+view['name']+'.png';assert (OUT/file).exists();images+=1
  parts.append(f'<figure><a href="{file}"><img loading="lazy" src="{file}" alt="{html.escape(view["name"])}"></a><figcaption>{html.escape(view["name"])}</figcaption></figure>')
 parts.append('</div></section>')
(OUT/'index.html').write_text('\n'.join(parts)+'\n');report={'maps':len(rows),'images':images,'resolution':[1920,1080],'all_bsp_hashes_current':True};(HERE/'gallery.json').write_text(json.dumps(report,indent=2)+'\n');print(report)

archive=ROOT.parent/'Builds/FPSloppa-0.21v-Classic-Arena-Renders.zip';archive.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_STORED) as z:
 for f in [OUT/'index.html',OUT/'plan.json',*sorted(OUT.glob('*/*.png')),*sorted(OUT.glob('*/renders.json'))]:z.write(f,f.relative_to(OUT))
report['archive']=str(archive);report['archive_bytes']=archive.stat().st_size;report['archive_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
(HERE/'gallery.json').write_text(json.dumps(report,indent=2)+'\n');print('Archive',archive,flush=True)
