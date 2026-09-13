"""Summarize production static caches and Classic/Contrast visual validation."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/static-assets'
def read(p):return json.loads(p.read_text())
def main():
    spec=importlib.util.spec_from_file_location('comparison_helpers',ROOT/'tools/lighting_experiment/candidates789/compare.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper);helper.OUT=OUT
    build=read(OUT/'build.json');verify=read(OUT/'verify.json');classic=read(OUT/'render.json');contrast=read(OUT/'contrast/render.json')
    assert len(build)==25 and len(verify['records'])==50 and not verify['failures']
    metrics=[]
    for label,data,folder in [('Classic',classic,OUT),('Contrast',contrast,OUT/'contrast')]:
        assert not data['failures'] and len(data['records'])==120
        refs={(r['map'],r['view']):r for r in data['records'] if r['variant']=='raw'}
        for r in data['records']:
            key=(r['map'],r['view']);base=refs[key];prefix=f'{r["map"]}-{r["view"]}-'
            a=helper.pixels(folder/'render'/f'{prefix}raw.png');b=helper.pixels(folder/'render'/f'{prefix}{r["variant"]}.png')
            assert r['draws']['median']==base['draws']['median'] and not r['fog']
            metrics.append({'lighting':label,**r,'versus_raw':helper.error(a,b)})
    sky_sources=read(ROOT/'deathmatch/maps/skies/SOURCES.json')
    for r in read(OUT/'density.json'):assert sky_sources['map_sources'][r['candidate_sha256']]==r['map']
    report={'date':'2026-09-13','status':'incorporated; local baked/compressed assets built',
            'policy':{'colour':'BC7 desktop / ASTC 4x4 Android, opaque images >128px, full original dimensions',
                      'lightmaps_glow_cutouts':'uncompressed','runtime_compression':False,'fog':False,'skyboxes':'default; no graphics toggle','alpha_packed_glow':False},
            'density':read(OUT/'density.json'),'maps':build,'verify':verify,'render':classic,'contrast':contrast,'visual_metrics':metrics,
            'limitations':['Native Quest/ASTC, stereo motion and thermal tests deferred. ASTC desktop renders use explicit CPU-decoded references.',
                           'Static scenes without players; short sequential GPU measurements do not establish a gameplay speedup.',
                           'Full render harness retains 6 ObjectDB / 2-resource shutdown warning; no render/assertion failures.'],
            'skybox_inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'deathmatch/maps/skies').glob('*.png')}}
    (ROOT/'docs/validation/static-assets.json').write_text(json.dumps(report,indent=2)+'\n')
    rows=[]
    for map_id,view,label in [('tf_vesper','nave','Vesper nave'),('tf_pressureworks','floor','Pressureworks'),('qsrc_dm2','runes','DM2 runes'),('ctf_deepvault','corridor0','Deepvault')]:
        rows.append((label,[Image.open(folder/'render'/f'{map_id}-{view}-bc7.png') for folder in [OUT,OUT/'contrast']]))
    helper.sheet('classic-contrast.png','Classic / Contrast — new static assets','BC7, full texture dimensions, default skyboxes, fog disabled. Images receive identical resizing.',rows,['Classic','Contrast'],(640,400))
    rows=[]
    for map_id,view,box,label in [('tf_vesper','rose',(400,220,720,476),'Vesper rose'),('tf_pressureworks','floor',(610,490,930,746),'Pressureworks floor'),('qsrc_dm2','runes',(500,360,820,616),'DM2 runes'),('ctf_deepvault','corridor0',(440,290,760,546),'Deepvault stone')]:
        rows.append((label,[Image.open(OUT/'contrast/render'/f'{map_id}-{view}-{variant}.png').crop(box) for variant in ['raw','bc7','astc4-reference']]))
    helper.sheet('contrast-compression.png','Contrast lighting / full-resolution compression','1:1 crops. Lightmaps and glow stay uncompressed. ASTC 4x4 is a decoded visual reference on this desktop.',rows,['Uncompressed','BC7 desktop','ASTC 4x4 reference'])
    maps=[]
    for r in build:
        view=next(x['view'] for x in contrast['records'] if x['map']==r['map'])
        maps.append((r['map'],[Image.open(OUT/'contrast/render'/f'{r["map"]}-{view}-bc7.png')]))
    helper.sheet('contrast-all-maps.jpg','Contrast lighting / all 25 bundled maps','Default map skyboxes, no fog, native BC7 colour and uncompressed compact lightmaps.',maps,['Contrast'],(640,400))
    viewer(classic['records'])
    print('PASS: 25 maps, 50 format checks, 21600 measured frames, 240 captures; no added draws')

def viewer(records):
    choices=list(dict.fromkeys((r['map'],r['view']) for r in records))
    html='''<!doctype html><meta charset="utf-8"><title>FPSloppa — static assets / Contrast</title><style>body{font:16px system-ui;background:#111720;color:#e9edf2;max-width:1280px;margin:30px auto;padding:0 20px}p{color:#b8c8d8;line-height:1.5}select{background:#263243;color:white;padding:10px;margin:6px}#frame{position:relative;aspect-ratio:1.6}#frame img{position:absolute;width:100%;height:100%}#b{clip-path:inset(0 0 0 50%)}#line{position:absolute;left:50%;height:100%;border-left:2px solid white}input{width:100%}a{color:#80cfff}</style><h1>Static assets — Classic and Contrast</h1><p>All views use the new skyboxes with fog disabled. Texture dimensions are unchanged. Compare lighting modes or compression; left is A, right is B. ASTC 4×4 is an explicitly decoded desktop reference, not a native Quest performance test.</p><select id="view"></select><label>A <select id="av"></select></label><label>B <select id="bv"></select></label><div id="frame"><img id="a" alt="A"><img id="b" alt="B"><div id="line"></div></div><input id="slider" type="range" min="0" max="100" value="50" aria-label="Comparison divider"><p><a href="classic-contrast.png">Classic / Contrast sheet</a> · <a href="contrast-compression.png">Contrast compression at 1:1</a> · <a href="contrast-all-maps.jpg">All maps</a></p><script>const views=DATA;const el=id=>document.getElementById(id);for(let i=0;i<views.length;i++)el('view').add(new Option(views[i].join(' / '),i));const options=[['Classic / BC7','render/|bc7'],['Contrast / BC7','contrast/render/|bc7'],['Contrast / uncompressed','contrast/render/|raw'],['Contrast / ASTC 4x4 reference','contrast/render/|astc4-reference'],['Classic / uncompressed','render/|raw'],['Classic / ASTC 4x4 reference','render/|astc4-reference'],['Contrast / old cache, no fog','contrast/render/|before']];for(const id of ['av','bv'])for(const [label,value] of options)el(id).add(new Option(label,value));el('av').selectedIndex=0;el('bv').selectedIndex=1;function update(){let [map,view]=views[+el('view').value];for(const side of ['a','b']){const [folder,variant]=el(side+'v').value.split('|');el(side).src=folder+map+'-'+view+'-'+variant+'.png';}}el('av').onchange=el('bv').onchange=el('view').onchange=update;el('slider').oninput=()=>{el('b').style.clipPath=`inset(0 0 0 ${el('slider').value}%)`;el('line').style.left=el('slider').value+'%';};update();</script>'''.replace('DATA',json.dumps(choices))
    (OUT/'compare.html').write_text(html)
if __name__=='__main__':main()
