"""Assemble local render contact sheets and a browsable offline gallery (Pillow)."""
from pathlib import Path
import hashlib,html,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/quake-source-previews'
groups=[('Quake','qsrc_dm',ROOT.parent/'Builds/Quake-Multiplayer-Addon/maps'),('ThreeWave','threewave',ROOT.parent/'Builds/Texture-Consistency-Local/ThreeWave-Local/maps'),('TF','tf_original',ROOT.parent/'Builds/Texture-Consistency-Local/TF-Local-Validated/maps')]
sections=[];reports=[]
for label,prefix,maps in groups:
    paths=sorted(maps.glob(prefix+'*.bsp'));sheet=Image.new('RGB',(1280,len(paths)*224),'#222');draw=ImageDraw.Draw(sheet);cards=[]
    for row,path in enumerate(paths):
        name=path.stem;images=[];draw.text((5,row*224+3),name,fill='white')
        for i in range(4):
            p=OUT/(name+'-spawn%d.png'%i);assert p.exists() and p.stat().st_mtime>path.stat().st_mtime
            image=Image.open(p).convert('RGB');image.thumbnail((320,200));sheet.paste(image,(i*320,row*224+24))
            caption='DM spawn '+str(i+1) if label=='Quake' else ('red' if i<2 else 'blue')+' '+('spawn' if i%2==0 else 'flag')
            images.append('<a href="'+p.name+'"><img loading="lazy" src="'+p.name+'" alt="'+html.escape(name+' '+caption)+'"><span>'+caption+'</span></a>')
        cards.append('<article><h3>'+name+'</h3><div class="views">'+''.join(images)+'</div></article>')
        reports.append({'map':name,'family':label,'bsp_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'views':4,'screenshots_newer_than_bsp':True})
    sheet.save(OUT/(label+'-contact.jpg'),quality=91)
    sections.append('<section data-family="'+label+'"><h2>'+label+'</h2>'+''.join(cards)+'</section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FPSloppa map texture review</title>
<style>body{background:#181818;color:#eee;font:16px system-ui;margin:24px;max-width:1700px}button{background:#333;color:white;border:1px solid #888;padding:10px 20px;margin-right:8px;cursor:pointer}h2{color:#e8bf79}a{color:#eee;text-decoration:none}article{padding:12px;background:#242424;margin:14px 0}.views{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}img{width:100%}span{display:block;padding:6px}p{max-width:1000px;line-height:1.5}@media(max-width:900px){.views{grid-template-columns:repeat(2,1fr)}}</style>
<h1>FPSloppa — multiplayer texture review</h1><p>60 in-engine views of 15 maps using the shared LibreQuake/generated counterpart rules. TF and ThreeWave use their existing embedded lightmaps; Quake DM1–DM7 have fresh RGB bakes. Click any image for full resolution. These are real game renders, not generated concept previews.</p>
<p>Known limitation: ThreeWave CTF2M4 has two lifts whose passengers meet overhead geometry. Visual rendering passed; that map has not passed traversal acceptance. The TF and ThreeWave BSPs remain local only. Material-family replacements are approximate and preserve team markings; this is not a pixel-identical restoration.</p>
<nav><button data-filter="all">All</button><button data-filter="Quake">Quake</button><button data-filter="ThreeWave">ThreeWave</button><button data-filter="TF">TF</button></nav>'''+''.join(sections)+'''<script>document.querySelectorAll('button').forEach(b=>b.onclick=()=>document.querySelectorAll('section').forEach(s=>s.hidden=b.dataset.filter!=='all'&&b.dataset.filter!==s.dataset.family));</script></html>'''
(OUT/'index.html').write_text(page)
(OUT/'REVIEW.json').write_text(json.dumps({'dictionary':json.loads((ROOT/'deathmatch/maps/texture_replacements/manifest.json').read_text())['version'],'maps':reports},indent=2)+'\n')
print(OUT/'index.html')
