"""Label native matched renders and produce a portable comparison gallery."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,html,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/de-study-comparison'
FONT='/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf'
if not Path(FONT).exists():FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(size):return ImageFont.truetype(FONT,size)
CAPTIONS={
 'nuke':('Nuke | Upper-site hut','Added side walls and two usable doorways to break the broad lobby angle.'),
 'inferno':('Inferno | Apartments','Two staggered partitions add clearing corners while preserving the central passage.'),
 'aztec':('Aztec | Canal escape','Lengthened the west ramp; added a landing and opened the bridge railing.'),
 'train':('Train | Upper B hall','Reversed the entry stairs and filled the missing floor under the upper corridor.'),
 'dust2':('Dust2 | A-site trim','Moved the floating sandstone course to the actual outer wall of the adjoining terrace.')}
def main():
 provenance=OUT/'provenance.json';rows=json.loads(provenance.read_text())
 for row in rows:row['after_bsp_sha256']=hashlib.sha256((ROOT/'maps'/(row['map']+'.bsp')).read_bytes()).hexdigest()
 provenance.write_text(json.dumps(rows,indent=2)+'\n')
 cards=[];sections=[]
 for name,(title,caption) in CAPTIONS.items():
  im=Image.new('RGB',(2880,1080),'#101820');d=ImageDraw.Draw(im)
  d.text((32,16),title,font=font(34),fill='white')
  d.text((32,68),'BEFORE  /  reconstructed pre-study geometry' if name!='dust2' else 'BEFORE  /  archived pre-correction BSP',font=font(24),fill='#e6b484')
  d.text((1472,68),'AFTER  /  current geometry',font=font(24),fill='#9cdbb4')
  for stage,x in [('before',0),('after',1440)]:im.paste(Image.open(OUT/f'{name}-{stage}.png').convert('RGB'),(x,110))
  d.line((1440,110,1440,1010),fill='#101820',width=4)
  d.text((32,1028),caption,font=font(25),fill='#e0e8ef')
  im.save(OUT/f'{name}-comparison.png')
  thumb=im.resize((1440,540));cards.append(thumb)
  sections.append(f'<section><h2>{html.escape(title)}</h2><p>{html.escape(caption)}</p><a href="{name}-comparison.png"><img src="{name}-comparison.png" alt="{html.escape(title)} before and after"></a><p><a href="{name}-before.png">Before full size</a> · <a href="{name}-after.png">After full size</a></p></section>')
 sheet=Image.new('RGB',(1440,540*len(cards)))
 for i,card in enumerate(cards):sheet.paste(card,(0,i*540))
 sheet.save(OUT/'comparison-sheet.jpg',quality=94)
 (OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>DE map study comparisons</title><style>body{background:#101820;color:#e0e8ef;font:18px system-ui;max-width:1500px;margin:32px auto;padding:0 24px}a{color:#9fcfff}img{width:100%}section{margin:48px 0}p{line-height:1.5}</style><h1>DE map study: before and after</h1><p>Native Godot renders with identical cameras, field of view, resolution and rendering settings. Before geometry was reconstructed by reversing only the four documented study edits; it is not an archived pre-study binary. Both sides were compiled with the same texture and lighting recipes. Dust2 uses an archived BSP from before its floating trim correction.</p><p><a href="provenance.json">BSP hashes and provenance</a> · <a href="comparison-sheet.jpg">All-map contact sheet</a></p>'''+''.join(sections))
 print(OUT/'index.html')
if __name__=='__main__':main()
