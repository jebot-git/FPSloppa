#!/usr/bin/env python3
"""Report paired map-presentation tests and install only verified scene caches."""
from pathlib import Path
import argparse,hashlib,json,shutil,statistics
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/map-presentation'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text())
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true');args=parser.parse_args()
    prepared=read(OUT/'prepare.json');rendered=read(OUT/'mobile/render.json');integration=read(OUT/'integration.json');surface=read(OUT/'surfaces/render.json');ui=read(OUT/'ui.json')
    for r in [prepared,rendered,integration,surface,ui]:assert not r['failures']
    for log,marker in [('map_presentation','MAP_PRESENTATION_RESULT []'),('client_preferences','CLIENT_PREFERENCES_RESULT []'),('lighting_profile','LIGHTING_PROFILE_RESULT []'),('map_colour_mips','"failures":[]')]:
        text=(OUT/(log+'.log')).read_text();assert marker in text and 'SCRIPT ERROR' not in text
    for log in ['presentation-mobile','integration','surfaces-mobile','presentation-ui-mobile']:assert 'ERROR:' not in (OUT/(log+'.log')).read_text()
    groups={}
    for row in rendered['records']:groups.setdefault((row['map'],row['view']),[]).append(row)
    summary={}
    for variant in ['atmosphere','animation','variation','combined']:
        gpu=[];p95=[];draws=[];memory=[]
        for key,rows in groups.items():
            before=[r for r in rows if r['variant'] in ['baseline','restored']];after=[r for r in rows if r['variant']==variant]
            gpu.append(statistics.mean(r['gpu_ms']['median'] for r in after)-statistics.mean(r['gpu_ms']['median'] for r in before))
            p95.append(statistics.mean(r['gpu_ms']['p95'] for r in after)-statistics.mean(r['gpu_ms']['p95'] for r in before))
            draws.append(after[0]['draws']['median']-before[0]['draws']['median']);memory.append(after[0]['texture_bytes']['median']-before[0]['texture_bytes']['median'])
        summary[variant]={'median_paired_gpu_delta_ms':statistics.median(gpu),'gpu_delta_range_ms':[min(gpu),max(gpu)],'median_paired_p95_delta_ms':statistics.median(p95),'p95_delta_range_ms':[min(p95),max(p95)],'draw_delta_range':[min(draws),max(draws)],'toggle_texture_allocation_delta_range':[min(memory),max(memory)]}
    views=[('tf_pressureworks','turbine'),('tf_pressureworks','flag'),('tf_vesper','nave'),('tf_vesper','sanctuary'),('qsrc_dm7','spawn0'),('ctf_deepvault','spawn0')]
    canvas=Image.new('RGB',(1280,180*len(views)),(12,12,12));draw=ImageDraw.Draw(canvas)
    for y,(name,view) in enumerate(views):
        for x,variant in enumerate(['baseline','atmosphere','variation','combined']):
            img=Image.open(OUT/f'mobile/{name}-{view}-{variant}.png').convert('RGB');img.thumbnail((320,160));canvas.paste(img,(x*320,y*180));draw.text((x*320+4,y*180+162),f'{name} {view} {variant}',fill='white')
    canvas.save(OUT/'mobile/review.jpg')
    changes=[];copies=[];version=read(ROOT/'deathmatch/maps/texture_replacements/manifest.json')['version']
    for row in prepared['maps']:
        assert row['geometry_preserved'] and sha(ROOT/'maps'/(row['id']+'.bsp'))==row['bsp_sha256']
        assert sha(ROOT/'maps/navigation'/(row['id']+'.res'))==row['navigation_sha256']
        source=OUT/'cache'/(row['id']+'.scn');assert sha(source)==row['cache_sha256']
        paths=[ROOT/'maps/cache'/(row['id']+suffix) for suffix in ['.scn','-lightmap1.scn']]
        alias=ROOT/'maps/cache'/(row['id']+'-lightmap1-textures-'+version+'.scn')
        if alias.exists():paths.append(alias)
        for target in paths:
            backup=OUT/'before-install'/target.relative_to(ROOT)
            old=backup if backup.exists() else target
            changes.append({'path':str(target.relative_to(ROOT)),'previous_sha256':sha(old),'sha256':sha(source),'previous_bytes':old.stat().st_size,'bytes':source.stat().st_size})
            copies.append((source,target,backup))
    if args.install:
        for source,target,backup in copies:
            if not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,backup)
            shutil.copyfile(source,target)
    receipt={'status':'installed scene caches; desktop tests passed' if args.install else 'prepared and tested',
      'renderer':rendered['renderer'],'gpu':rendered['gpu'],'engine':rendered['engine'],'resolution':rendered['resolution'],'msaa':rendered['msaa'],
      'measured_frames':rendered['measured_frames'],'maps':prepared['maps'],'integration':integration,'focused_surfaces':surface,'ui':ui,'summary':summary,'cache_changes':changes,
      'shader_sha256':sha(ROOT/'deathmatch/maps/baked_light.gdshader'),'failures':[],
      'vesper_camera':{'old':[18,2.2,24],'old_contents':'solid','corrected':[15,2.2,24],'corrected_contents':'empty','geometry_changed':False},
      'retained_frame_pixel_bytes':sum(r['frame_pixel_bytes'] for r in prepared['maps']),
      'tinted_vertices':sum(r['tinted_vertices'] for r in prepared['maps']),
      'limits':['Desktop static-view A/B measurements on Arc A770, not Quest timing certification.','Quest tests deferred by user; no ADB attempt after deferral.','Toggle memory deltas exclude frame resources and vertex colour streams already loaded in both variants.','No extra realtime lights, screen textures, refraction, fog volumes or material passes.','Weathering applies to allowlisted neutral masonry on the two original TF maps; imported artwork stays unchanged.','Unbaked imported liquids use bounded UV drift; baked materials use per-fragment warp.','Existing BSPs, lightmaps, source artwork and navigation files unchanged.','No executable/APK rebuild or publication performed.']}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (ROOT/'docs/validation/map-presentation.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(summary,indent=2));print('Verified caches:',len(changes),'installed:',args.install)
if __name__=='__main__':main()
