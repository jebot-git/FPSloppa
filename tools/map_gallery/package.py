#!/usr/bin/env python3
"""Validate full-resolution captures and build a portable, offline gallery."""
import hashlib, html, json, zipfile
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/map-gallery'
STYLE='body{background:#121820;color:#e5ebf2;font:16px system-ui;margin:32px}a{color:#9fd8ff}img{max-width:100%;height:auto}section{margin:32px 0;padding:20px;background:#1d2733}summary{cursor:pointer;padding:12px}.views{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}input{padding:12px;width:300px}figure{margin:0}figcaption{padding:8px}'
def document(title,body):
 return f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>{title}</title><style>{STYLE}</style><h1>{title}</h1>{body}</html>'
def main():
 rows=json.loads((OUT/'plan.json').read_text());receipts=[];sections=[]
 for row in rows:
  folder=OUT/row['id'];report=json.loads((folder/'renders.json').read_text());captures=report['captures']
  assert len(captures)==len(row['views'])+3,row['id']
  log=(folder/'render.log').read_text();assert 'MAP_GALLERY_DONE' in log and 'ERROR:' not in log,row['id']
  links=[];checks=[]
  for c in captures:
   file=folder/(c['name']+'.png')
   with Image.open(file) as im:
    assert im.size==(1920,1080),(file,im.size)
    assert im.convert('L').getextrema()[0]!=im.convert('L').getextrema()[1],file
    im.thumbnail((480,270));im.convert('RGB').save(folder/(c['name']+'.jpg'),quality=85)
   checks.append({'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
   href=f"{row['id']}/{c['name']}";label=html.escape(c['name'])
   links.append(f'<figure><a href="{href}.png"><img loading="lazy" src="{href}.jpg" alt="{label}"></a><figcaption>{label}</figcaption></figure>')
  title=html.escape(row['title']);mode=row['mode'].upper()
  sections.append((row['mode'],f'<section data-search="{html.escape((title+mode).lower())}"><h2>{mode} · {title}</h2>{links[1]}<details><summary>All {len(links)} views · 1920 × 1080 PNG</summary><div class="views">'+''.join(links)+'</div></details></section>'))
  receipts.append({'id':row['id'],'mode':row['mode'],'bsp_sha256':report['bsp_sha256'],'captures':checks})
 intro='<p>22 Classic ST adaptations and 14 converted DE maps. Every image opens its full-resolution PNG. Overview fog is disabled to show the entire map; ground views retain game weather and lighting.</p><input placeholder="Filter by name, ST or DE" aria-label="Filter maps" oninput="document.querySelectorAll(\'section\').forEach(s=>s.hidden=!s.dataset.search.includes(this.value.toLowerCase()))">'
 (OUT/'index.html').write_text(document('Converted map renders',intro+''.join(s for _,s in sections)))
 for mode in ('st','de'):
  selected=[r for r in rows if r['mode']==mode];sheet=Image.new('RGB',(1200,195*((len(selected)+2)//3)), '#121820');draw=ImageDraw.Draw(sheet)
  for i,r in enumerate(selected):
   with Image.open(OUT/r['id']/'02-full-overview.png') as im:
    im.thumbnail((390,165));sheet.paste(im,(i%3*400,i//3*195))
   draw.text((i%3*400+5,i//3*195+170),r['title'],fill='white')
  sheet.save(OUT/f'{mode}-contact-sheet.jpg',quality=92)
  (OUT/f'{mode}.html').write_text(document(mode.upper()+' map renders',intro+''.join(s for m,s in sections if m==mode)))
  with zipfile.ZipFile(OUT/f'{mode}-full-renders.zip','w',compression=zipfile.ZIP_STORED) as z:
   z.write(OUT/f'{mode}.html','index.html');z.write(OUT/f'{mode}-contact-sheet.jpg',f'{mode}-contact-sheet.jpg')
   for r in selected:
    for f in sorted((OUT/r['id']).iterdir()):
     if f.suffix in ('.png','.jpg','.json'):z.write(f,f.relative_to(OUT))
 receipt={'maps':len(rows),'images':sum(len(r['captures']) for r in receipts),'resolution':[1920,1080],'renderer':'Godot Mobile Vulkan','all_logs_pass':True,'results':receipts}
 (ROOT/'tools/map_gallery/validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:v for k,v in receipt.items() if k!='results'}))
if __name__=='__main__':main()
