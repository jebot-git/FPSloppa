"""Build the 81-map campaign atlas; each process has its own WAD and compiler files."""
import argparse, concurrent.futures, copy, hashlib, json, random, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT),str(ROOT/'tools/km_benchmark')]
import city, urban
from enclosed import District as Enclosed
from tools.cq_maps import build as legacy_build
from tools.cq_maps.build import audit
from tools.district_cluster.world import atlas
OUT=ROOT/'maps/CampaignDistricts'

class OpenDistrict(Enclosed):
    def build(self):urban.District.build(self)
    def infill(self,lot,index):urban.District.infill(self,lot,index)
    def skyways(self):urban.District.skyways(self)
    def landmarks(self):urban.District.landmarks(self)

def build_one(task):
    i,compiler=task[:2];seed_round=task[2] if len(task)>2 else None
    if seed_round is None:seed_round=json.loads(Path(__file__).with_name('campaign_seeds.json').read_text()).get(str(i),0)
    rows=atlas();row=rows[f'd{i:02}'];slot=i%16
    folder=OUT/f'district_{i:02}';folder.mkdir(parents=True,exist_ok=True)
    city.OUT=folder
    rng=random.Random(81000+i)
    plan=copy.deepcopy(urban.PLANS[(i*7+i//16)%16])
    points={p for line in [plan[1],plan[2],*plan[3]] for p in line}
    moved={p:((p[0]+rng.randint(-5,5),p[1]+rng.randint(-5,5)) if 30<max(abs(p[0]),abs(p[1]))<95 else p) for p in points}
    urban.PLANS[slot]=(row['name'],*[ [moved[p] for p in line] for line in plan[1:3]],[[moved[p] for p in line] for line in plan[3]])
    # Palette follows role and macroblock, while every layout has its own street
    # bends and seeded lots. Preserve the shared night-city texture vocabulary.
    theme=copy.deepcopy(city.THEMES[(i//3+i//9*3)%16])
    if row['campaign_role']=='hub':theme=city.THEMES[0]
    if row['campaign_role']=='relay':theme=city.THEMES[5]
    if row['campaign_role']=='homebase':theme=city.THEMES[11 if row['initial_owner']==0 else 3]
    city.THEMES[slot]=(row['name'],*theme[1:])
    for attempt in range(8):
        w=(OpenDistrict if row['profile']=='open' else Enclosed)(slot)
        w.rng=random.Random(181000+i*127+attempt+seed_round*100003);w.campaign_profile=row['profile']
        w.campaign_gates=[]
        for key,edge in row['links'].items():
            p=edge['exit'];normal=[-p[0]/124,0,-p[2]/124]
            w.campaign_gates.append(dict(zone=slot,neighbor=int(key[1:]),position=[p[0]/124*124.94,8,p[2]/124*124.94],normal=normal,color=theme[2],name=rows[key]['name']))
        try:w.build();break
        except AssertionError:
            if attempt==7:raise
    # Terminals are walk-through holograms; frames stay outside their aperture.
    for target,edge in row['terminals'].items():
        x,_,z=edge['exit']
        w.light((x,3.4,z),1600,(.6,.7,.85),'relay_terminal')
    legacy_build.OUT=folder;legacy_build.wad(w.names)
    source=folder/'district.map';bsp=folder/'district.bsp'
    world=dict(classname='worldspawn',message=row['name'],wad='city.wad',_sunlight='9',_sunlight2='4',_sun_mangle='35 -55 0',_sunlight_color='.38 .52 1',_minlight='1',_fpsloppa_light_response='night',_lightmap_scale='16',_fpsloppa_bake='1',_fpsloppa_atlas='4096')
    ent=lambda d:'\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
    source.write_text('// Original Vesper campaign geometry. Existing project texture licences apply.\n{\n'+ent(world)+'\n'+'\n'.join(w.brushes)+'\n}\n{\n"classname" "func_detail_wall"\n'+'\n'.join(w.detail)+'\n}\n'+'\n'.join('{\n'+ent(e)+'\n}' for e in w.entities)+'\n')
    (folder/'geometry.map').write_text(source.read_text())
    layout=dict(id=i,render_zone=slot,name=row['name'],style=theme[1],profile=row['profile'],campaign=row,origin=[0,0,0],zones=[dict(name=t[0],color=t[2],center=[0,0,0]) for t in city.THEMES],revision='campaign-city-1',street_plan=row['name'])
    for key,attr in dict(art='art',gates='gates',spawns='spawns',occluder_boxes='solids',rooms='rooms',routes='routes',emitters='emitters',pickup_positions='pickup_positions',streets='streets',street_points='street_points',lots='lots',props='props',signs='signs').items():layout[key]=getattr(w,attr)
    if hasattr(w,'enclosure'):layout['enclosure']=w.enclosure
    layout.update(brushes=len(w.brushes)+len(w.detail),source_texture_names=sorted(w.names),textures=len(w.names),seed_attempt=attempt,seed_round=seed_round)
    (folder/'layout.json').write_text(json.dumps(layout,indent=2)+'\n')
    commands=[('qbsp',['-leaktest','-noclip','-subdivide','1024',str(source),str(bsp)]),('vis',['-threads','2',str(bsp)]),('light',['-threads','2','-extra','-bspxlit','-bounce','1','-bouncecolorscale','0.35','-dirt','1','-dirtdepth','64','-dirtscale','0.6','-minlight_dirt','1',str(bsp)])]
    runs=[]
    for binary,flags in commands:
        began=time.monotonic()
        with (folder/(binary+'.log')).open('w') as log:subprocess.run([str(Path(compiler)/binary),*flags],cwd=folder,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
        runs.append(dict(tool=binary,seconds=time.monotonic()-began))
    result=audit(bsp.read_bytes());result.update(zone=i,name=row['name'],format='BSP29',baked=True,commands=runs,brushes=layout['brushes'],lights=len(w.emitters))
    (folder/'build.json').write_text(json.dumps(result,indent=2)+'\n')
    return dict(district=i,bytes=result['bytes'],seconds=sum(r['seconds'] for r in runs))

def main():
    p=argparse.ArgumentParser();p.add_argument('--compiler',required=True);p.add_argument('--districts',type=int,nargs='+',default=list(range(81)));p.add_argument('--jobs',type=int,default=4);p.add_argument('--seed-round',type=int);a=p.parse_args()
    # Fresh processes prevent mutated palettes/plans leaking into another map.
    with concurrent.futures.ProcessPoolExecutor(max_workers=a.jobs,max_tasks_per_child=1) as pool:
        futures={pool.submit(build_one,(i,a.compiler,a.seed_round)):i for i in a.districts}
        failed=[]
        for f in concurrent.futures.as_completed(futures):
            try:print('CAMPAIGN_BUILT',json.dumps(f.result()),flush=True)
            except Exception as e:failed.append(futures[f]);print('CAMPAIGN_FAILED',futures[f],repr(e),flush=True)
    if failed:raise SystemExit('Failed maps: '+str(failed))
if __name__=='__main__':main()
