#!/usr/bin/env python3
"""Build review artifacts and measurements from the isolated 7/8/9 experiment."""
import hashlib
import json
from pathlib import Path
from statistics import median

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'test-results/candidates789'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

def font(size):
    try: return ImageFont.truetype(FONT, size)
    except OSError: return ImageFont.load_default()

def read(path): return json.loads(path.read_text())
def pixels(path): return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)
def error(a, b):
    d = np.abs(a-b)
    return {'mae_255': float(d.mean()), 'p99_channel_error_255': float(np.percentile(d, 99)),
            'max_channel_error_255': int(d.max()), 'pixels_over_2_percent': float((d.max(axis=2)>2).mean()*100)}

def sheet(name, title, subtitle, rows, columns, size=(320,256)):
    w,h=size; left=180; top=108; stride=h+28
    canvas=Image.new('RGB',(left+w*len(columns),top+stride*len(rows)+28),'#111720');draw=ImageDraw.Draw(canvas)
    draw.text((20,15),title,font=font(25),fill='white');draw.text((20,52),subtitle,font=font(14),fill='#b8c8d8')
    for i,label in enumerate(columns):draw.text((left+i*w+8,83),label,font=font(15),fill='white')
    for j,(label,images) in enumerate(rows):
        y=top+j*stride;draw.multiline_text((15,y+20),label,font=font(16),fill='#b8c8d8',spacing=8)
        for i,im in enumerate(images):
            im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS)
            canvas.paste(im,(left+i*w+(w-im.width)//2,y+(h-im.height)//2))
    canvas.save(OUT/name)

def main():
    render=read(OUT/'mobile/render.json');records=render['records'];metrics=[]
    for row in records:
        prefix=f"{row['map']}-{row['view']}-"
        ref='baseline-packed' if row['variant']=='density-packed' else 'baseline'
        a=pixels(OUT/'mobile'/f'{prefix}{ref}.png');b=pixels(OUT/'mobile'/f"{prefix}{row['variant']}.png")
        metrics.append({**row,'reference':ref,'pixel_error':error(a,b),
            'visual_exclusion': 'Automatic lava viewpoint does not show a useful lava comparison; use material swatches.' if row['map']=='qsrc_dm2' and row['view']=='lava' else None})
    swatches=[]
    for row in read(OUT/'materials/render.json'):
        source=OUT/'materials'/row['image'];base=source.with_name(source.name.replace('-'+row['variant']+'.png','-baseline.png'))
        swatches.append({**row,'tile_error':error(pixels(base)[40:760,280:1000],pixels(source)[40:760,280:1000])})
    summary=[]
    for map_id in dict.fromkeys(r['map'] for r in records):
        subset=[r for r in records if r['map']==map_id];base={r['view']:r for r in subset if r['variant']=='baseline'}
        for variant in dict.fromkeys(r['variant'] for r in subset):
            rows=[r for r in subset if r['variant']==variant];valid=[r for r in rows if not(map_id=='qsrc_dm2' and r['view']=='lava')]
            errs=[r['pixel_error']['mae_255'] for r in metrics if r['map']==map_id and r['variant']==variant and not r['visual_exclusion']]
            summary.append({'map':map_id,'variant':variant,'views':len(rows),
                'gpu_median_of_view_medians_ms':median(r['gpu_ms']['median'] for r in valid),
                'gpu_paired_delta_ms':median(r['gpu_ms']['median']-base[r['view']]['gpu_ms']['median'] for r in valid),
                'texture_mib':rows[0]['texture_bytes']['median']/2**20,
                'texture_saved_mib':(base[rows[0]['view']]['texture_bytes']['median']-rows[0]['texture_bytes']['median'])/2**20,
                'draw_call_delta_max':max(r['draws']['median']-base[r['view']]['draws']['median'] for r in rows),
                'visual_mae_range_255':[min(errs),max(errs)],'astc_decoded_reference':rows[0]['astc_decoded_reference']})
    glow_rows=[]
    for map_id,texture,label in [('tf_pressureworks','tlight12','Pressureworks\nWarm tube'),('tf_vesper','stn_gr01_blu1','Vesper\nProposed inlay'),('qsrc_dm2','lava1','DM2\nDimmer lava crust'),('qsrc_dm2','rune2_1','DM2 rune\nUnchanged control')]:
        ims=[Image.open(OUT/'materials'/f'{map_id}-{texture}-1-{v}.png').crop((280,40,1000,760)) for v in ['baseline','authored','packed_glow']]
        glow_rows.append((label,ims))
    sheet('glow-comparison.png','7 / Glow artwork and alpha packing','Controlled dark material swatches. Artwork is a proposal; alpha packing uses ORIGINAL emission.',glow_rows,['Original','Authored proposal','Alpha-packed original'],(360,360))
    mip_rows=[]
    for texture,label in [('lava1','DM2 lava'),('rune2_1','DM2 rune')]:
        mip_rows.append((label,[Image.open(OUT/'materials'/f'qsrc_dm2-{texture}-16-{v}.png').crop((420,180,860,620)) for v in ['baseline','authored','packed_glow']]))
    sheet('glow-mips.png','7 / Emission at distance','16 repetitions across the swatch; cropped and resized equally. Check colour bleeding and mip edges.',mip_rows,['Original','Authored proposal','Alpha-packed original'],(360,360))
    compression_rows=[]
    specs=[('tf_vesper','rose',(400,220,720,476),'Vesper rose'),('tf_pressureworks','floor',(610,490,930,746),'Pressureworks\nCobblestone'),('qsrc_dm2','runes',(500,360,820,616),'DM2 runes'),('ctf_deepvault','corridor0',(440,290,760,546),'Deepvault stone')]
    variants=['baseline-packed','bc7_large','astc4_large','astc8_all','half_colour']
    for map_id,view,box,label in specs:
        compression_rows.append((label,[Image.open(OUT/'mobile'/f'{map_id}-{view}-{v}.png').crop(box) for v in variants]))
    sheet('compression-comparison.png','8 / Compression and texture-size close-ups','1 image pixel = 1 sheet pixel. ASTC columns are decoded references; ASTC 8x8 also compresses lightmaps.',compression_rows,['Packed / uncompressed','BC7 large colour','ASTC 4x4 large colour','ASTC 8x8 all','Half large colour'])
    density_rows=[];rois=[]
    for map_id,view,label in [('tf_vesper','nave','Vesper nave'),('tf_vesper','arch_floor','Vesper floor'),('tf_pressureworks','floor','Pressureworks floor')]:
        a=pixels(OUT/'mobile'/f'{map_id}-{view}-baseline-packed.png');b=pixels(OUT/'mobile'/f'{map_id}-{view}-density-packed.png')
        # Select an explicit 320x256 crop with the greatest mean change, not an enhanced candidate.
        candidates=[(float(np.abs(a[y:y+256,x:x+320]-b[y:y+256,x:x+320]).mean()),x,y) for y in range(0,545,32) for x in range(0,961,32)]
        _,x,y=max(candidates);box=(x,y,x+320,y+256)
        diff=np.clip(np.abs(a-b)*16,0,255).astype('uint8')
        ims=[Image.fromarray(p.astype('uint8')).crop(box) for p in [a,b,diff]]
        density_rows.append((label,ims));rois.append({'map':map_id,'view':view,'box':box,'selection':'maximum mean difference on 32px grid','error':error(a[y:y+256,x:x+320],b[y:y+256,x:x+320])})
    sheet('density-comparison.png','9 / Selective finer static light samples','1:1 crops with greatest change. Only the DIFFERENCE column is amplified 16x; both renders are unaltered.',density_rows,['16-unit samples','Selected 8-unit samples','Absolute difference x16'])
    before=read(OUT/'production-before.json');changed=[];unchanged=[]
    for name,digest in before.items():
        path=ROOT/name;now=hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
        if now!=digest:changed.append({'path':name,'before':digest,'after':now})
        else:unchanged.append(name)
    report={'scope':'Isolated experiment only; no candidate integrated into production or distribution',
        'render':{k:v for k,v in render.items() if k!='records'},'summary':summary,'records':metrics,'material_swatches':swatches,
        'density_rois':rois,'packing':read(OUT/'packing.json'),'density':read(OUT/'density.json'),
        'variants':read(OUT/'variants.json'),'integrity':read(OUT/'integrity.json'),
        'snapshot':{'unchanged_count':len(unchanged),'changed_during_session':changed,'all_tracked_bsp_and_caches_unchanged':all(not c['path'].endswith(('.bsp','.scn')) for c in changed)},
        'limitations':['Desktop Vulkan only; Quest native ASTC/stereo/performance tests deferred.',
            'Sequential short timings have baseline drift; they do not establish a speedup.',
            'Final render exits with 6 ObjectDB instances and 2 resources still in use; no measured texture-memory drift after restoring baseline.',
            'Selected density samples are freshly rebaked using the existing recipe; no fresh 16-unit control bake.',
            'ASTC decoder needed per-mip workaround for narrow non-square image mip tails.']}
    (OUT/'comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'docs/validation/candidates789.json').write_text(json.dumps(report,indent=2)+'\n')
    viewer(records)
    print(json.dumps({'records':len(records),'measured_frames':render['measured_frames'],'render_failures':render['failures'],'integrity_failures':report['integrity']['failures'],'snapshot':report['snapshot']},indent=2))

def viewer(records):
    choices=[]
    for map_id,view in dict.fromkeys((r['map'],r['view']) for r in records):
        if map_id=='qsrc_dm2' and view=='lava':continue
        choices.append({'label':map_id+' / '+view,'prefix':map_id+'-'+view+'-', 'variants':list(dict.fromkeys(r['variant'] for r in records if r['map']==map_id and r['view']==view))})
    html='''<!doctype html><meta charset="utf-8"><title>FPSloppa / rendering candidates 7–9</title>
<style>body{background:#111720;color:#e9edf2;font:16px system-ui;max-width:1280px;margin:30px auto;padding:0 20px}h1{font-size:28px}p{color:#b8c8d8;line-height:1.5}select{background:#263243;color:white;padding:10px;border:1px solid #708098;border-radius:5px;margin:5px}#frame{position:relative;aspect-ratio:1.6;background:#05070a;overflow:hidden}#frame img{width:100%;height:100%;position:absolute;top:0;left:0}#b{clip-path:inset(0 0 0 50%)}#line{position:absolute;left:50%;height:100%;border-left:2px solid white}input{width:100%}a{color:#80cfff}.tag{position:absolute;bottom:10px;background:#101720db;padding:7px}#bt{right:10px}#at{left:10px}</style>
<h1>Rendering candidates 7–9</h1><p>Isolated tests — no production integration. Desktop Vulkan, 1280 × 800, 4× MSAA. Select a view and drag the divider. Left is A, right is B. Images are unmodified renders.</p>
<label>View <select id="view"></select></label><label>A <select id="av"></select></label><label>B <select id="bv"></select></label><p id="note"></p>
<div id="frame"><img id="a" alt="Reference A"><img id="b" alt="Candidate B"><div id="line"></div><span class="tag" id="at"></span><span class="tag" id="bt"></span></div><input id="slider" aria-label="Comparison divider" type="range" min="0" max="100" value="50">
<p><a href="glow-comparison.png">Glow swatches</a> · <a href="glow-mips.png">Emission mip test</a> · <a href="compression-comparison.png">Compression at 1:1</a> · <a href="density-comparison.png">Density at 1:1 + difference</a> · <a href="comparison.json">Measurements</a></p>
<p>ASTC images were encoded and decoded for visual inspection: the desktop GPU has no ASTC support. Their timings are not Quest performance estimates. The proposed rose inlay is new art direction, not an emissive property of the original stone. Finer lighting compares selected fresh 8-unit samples against the current 16-unit bake. No extra real-time lights or screen-space effects.</p>
<script>const views=DATA;const el=id=>document.getElementById(id);for(let i=0;i<views.length;i++)el('view').add(new Option(views[i].label,i));
function update(){const v=views[+el('view').value];for(const side of ['a','b']){let name=el(side+'v').value;el(side).src='mobile/'+v.prefix+name+'.png';el(side+'t').textContent=name;}el('note').textContent=(el('av').value.startsWith('astc')||el('bv').value.startsWith('astc'))?'ASTC: decoded visual reference only.':el('bv').value==='density-packed'?'For density alone, choose baseline-packed as A.':'baseline-packed changes only the lightmap atlas layout. Colour compression variants include atlas packing.';}
function choose(){const v=views[+el('view').value];for(const id of ['av','bv']){el(id).replaceChildren();for(const name of v.variants)el(id).add(new Option(name,name));}el('av').value='baseline';el('bv').value='baseline-packed';update();}el('view').onchange=choose;el('av').onchange=el('bv').onchange=update;el('slider').oninput=()=>{const v=el('slider').value;el('b').style.clipPath=`inset(0 0 0 ${v}%)`;el('line').style.left=v+'%';};choose();</script>'''.replace('DATA',json.dumps(choices))
    (OUT/'compare.html').write_text(html)

if __name__=='__main__':main()
