"""Build an offline gallery from hash-verified game-render receipts; no image edits."""
from pathlib import Path
import hashlib
import html
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/quake-source-previews'
cards=[];records=[]
for path in sorted(OUT.glob('*.json')):
    if path.name=='REVIEW.json':continue
    row=json.loads(path.read_text())
    if not isinstance(row,dict) or not all(k in row for k in ['map','images','sha256']):continue
    bsp=Path(row['map'])
    if not bsp.is_file() or hashlib.sha256(bsp.read_bytes()).hexdigest()!=row['sha256']:
        raise RuntimeError('Map changed or missing; render again: '+str(bsp))
    for image in row['images']:
        if Path(image).name!=image or not (OUT/image).is_file():raise RuntimeError('Missing or invalid render: '+image)
    records.append(row)
    cards.append('<article><h2>'+html.escape(bsp.stem)+'</h2><p>'+html.escape(row['views'])+'</p><div>'+''.join('<a href="'+html.escape(image)+'"><img loading="lazy" src="'+html.escape(image)+'" alt="'+html.escape(image)+'"></a>' for image in row['images'])+'</div></article>')
views=sum(len(r['images']) for r in records)
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FPSloppa map texture review</title>
<style>body{background:#181818;color:#eee;font:16px system-ui;margin:24px}article{background:#242424;padding:12px;margin-bottom:20px}div{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}img{width:100%}a{color:#e8bf79}@media(max-width:850px){div{grid-template-columns:repeat(2,1fr)}}</style>
<h1>FPSloppa map texture review</h1><p>'''+str(views)+' actual game views across '+str(len(records))+''' maps. Original Makkon/LibreQuake records and retained material-family fallbacks; no generated texture variants. Original TF/ThreeWave sources remain local test material. <a href="../../docs/MAKKON_MAP_REVIEW.md">Results and gameplay acceptance limits</a>.</p>'''+''.join(cards)+'</html>'
(OUT/'index.html').write_text(page)
(OUT/'REVIEW.json').write_text(json.dumps({'views':views,'maps':records},indent=2)+'\n')
print(OUT/'index.html',len(records),'maps',views,'views')
