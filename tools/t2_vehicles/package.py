#!/usr/bin/env python3
"""Package vehicle review images and verify that their asset hashes are current."""
import hashlib,html,json
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/t2-vehicles/textured'
audit=json.loads((OUT/'audit.json').read_text());sections=[]
sheet=Image.new('RGB',(1500,700),'#182b36');draw=ImageDraw.Draw(sheet)
for i,row in enumerate(audit):
 kind=row['kind'];scene=ROOT/'deathmatch/vehicles/tribes'/f'{kind}.scn'
 assert hashlib.sha256(scene.read_bytes()).hexdigest()==row['scene_sha256']
 figures=[]
 for view in ('front','rear','side','top','cockpit','blue'):
  name=f'{kind}-{view}'
  with Image.open(OUT/f'{name}.png') as im:
   assert im.size==(1600,1000)
   im.thumbnail((480,300));im.save(OUT/f'{name}.jpg',quality=90)
   if view=='front':sheet.paste(im,(i%3*500,i//3*350))
  figures.append(f'<figure><a href="{name}.png"><img src="{name}.jpg" alt="{kind} {view}"></a><figcaption>{view}</figcaption></figure>')
 draw.text((i%3*500+15,i//3*350+310),kind.upper(),fill='white')
 sections.append(f'<h2>{html.escape(kind.title())}</h2><div>'+''.join(figures)+'</div>')
sheet.save(OUT/'vehicles.jpg',quality=95)
(OUT/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>ST vehicle textures</title><style>body{background:#121820;color:#eee;font:16px system-ui;margin:32px}div{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}figure{margin:0}img{max-width:100%}figcaption{padding:10px}</style><h1>ST vehicle textures</h1><p>All six Tribes 2 adaptations · shared ST panel atlas · click any view for its 1600 × 1000 PNG.</p>'+''.join(sections)+'</html>')
receipt={'atlas_sha256':hashlib.sha256((ROOT/'deathmatch/vehicles/tribes/hull-atlas.png').read_bytes()).hexdigest(),'preview_count':len(audit)*6,'preview_resolution':[1600,1000],'vehicles':audit}
(ROOT/'tools/t2_vehicles/validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(f'Vehicle gallery validated: {len(audit)} models, {len(audit)*6} previews')
