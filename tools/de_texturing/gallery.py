"""Make the local before/after review page from native DE viewport captures."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/de-texturing'
rows=json.loads((OUT/'views.json').read_text())
comparisons=[];sites=[]
for row in rows:
    id=row['map'];title=id.removeprefix('de_').removesuffix('_rebuilt').title()
    for file in row['images']:
        assert (OUT/file).is_file()
        view=file.removeprefix(id+'-').removesuffix('.png')
        if view in ['site-a','site-b']:
            sites.append(dict(title=title+' · '+view.replace('-',' ').upper(),file=file));continue
        before=id+'-before-'+view+'.png';assert (OUT/before).is_file()
        comparisons.append(dict(title=title+' · '+view.replace('-',' ').title(),before=before,after=file))
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>DE map materials · FPSloppa</title><style>
:root{color-scheme:dark;font:16px system-ui;background:#13191e;color:#e2e8e8}body{max-width:1440px;margin:32px auto;padding:0 24px}h1{font-size:36px;margin-bottom:10px}p{color:#b5c3c8;max-width:900px;line-height:1.6}a{color:#91dac8}select{padding:12px;border:1px solid #5b6c76;border-radius:6px;background:#21303b;min-width:300px;font:inherit}label{display:inline-flex;align-items:center;gap:12px;margin:10px 16px 10px 0}#compare{position:relative;aspect-ratio:1.6;overflow:hidden;background:#090c0f;margin:14px 0;border:1px solid #46525a;border-radius:8px}#compare img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}#after{clip-path:inset(0 0 0 50%)}#divider{position:absolute;left:50%;top:0;bottom:0;width:2px;background:#cce9e1}.tag{position:absolute;top:14px;background:#0e161de0;padding:6px 12px;border-radius:5px}.old{left:14px}.new{right:14px}input{width:240px;accent-color:#90d6c6}.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:20px}figure{margin:0;background:#1c252c;border-radius:6px;overflow:hidden}figure img{width:100%;display:block}figcaption{padding:12px}footer{padding:28px 0;color:#9aadb6}@media(max-width:700px){.grid{grid-template-columns:1fr}body{padding:0 12px}h1{font-size:28px}}
</style><h1>DE map material review</h1><p>Dust2, Nuke, Inferno, Aztec and Train: revised walls, floors, ceilings and prop surfaces. These are native game captures. Brush layouts, routes and navigation are preserved.</p>
<label>View <select id="view" aria-label="Map viewpoint"></select></label><label>Before / after <input id="slider" type="range" min="0" max="100" value="50" aria-label="Comparison split"></label>
<div id="compare"><img id="before" alt="Previous map materials"><img id="after" alt="Revised map materials"><div id="divider"></div><span class="tag old">Before</span><span class="tag new">After</span></div>
<p><a id="openBefore">Open before</a> · <a id="openAfter">Open after</a> · <a href="../../maps/DEMaterials/SOURCES.md">Materials, sources and generation prompts</a></p>
<h2>All ten plant areas</h2><p>No fixed floating letters or guide text. Site markings remain part of the map surfaces; the bomb retains its contextual controls.</p><div id="sites" class="grid"></div>
<footer>331 passing map/objective checks · full VIS and embedded RGB lighting · raw, BC7 and ASTC4 caches rebuilt.<br><a href="../../docs/validation/de-texturing-2026-09-26.json">Validation receipt</a></footer>
<script>const views=__VIEWS__,sites=__SITES__;
const pick=document.querySelector('#view'),before=document.querySelector('#before'),after=document.querySelector('#after');
views.forEach((v,i)=>pick.add(new Option(v.title,i)));
function update(){const v=views[Number(pick.value)];before.src=v.before;after.src=v.after;document.querySelector('#openBefore').href=v.before;document.querySelector('#openAfter').href=v.after}pick.onchange=update;update();
document.querySelector('#slider').oninput=e=>{after.style.clipPath=`inset(0 0 0 ${e.target.value}%)`;document.querySelector('#divider').style.left=e.target.value+'%'};
for(const s of sites){const f=document.createElement('figure'),a=document.createElement('a'),im=new Image(),c=document.createElement('figcaption');im.src=s.file;im.alt=s.title+' without floating site text';im.loading='lazy';a.href=s.file;a.append(im);c.textContent=s.title;f.append(a,c);document.querySelector('#sites').append(f)}
</script></html>'''
(OUT/'index.html').write_text(html.replace('__VIEWS__',json.dumps(comparisons)).replace('__SITES__',json.dumps(sites)))
print('DE_GALLERY',len(comparisons),'comparisons;',len(sites),'plant areas')
