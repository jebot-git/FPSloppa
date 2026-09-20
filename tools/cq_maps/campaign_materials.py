"""Expanded native Makkon palette; original miptex records, no image synthesis.

Retexture authored .map faces, then rerun QBSP/VIS/RGB bounce lighting. Geometry
is unchanged; final caches and navigation still require fresh validation.
"""
import argparse,concurrent.futures,json,re,struct,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT),str(ROOT/'tools/km_benchmark'),str(ROOT/'tools/cq_maps')]
from tools.makkon.theme import wad_textures,sha
from tools.cq_maps.build import audit
BASE=ROOT/'maps/CampaignDistricts'
COLORS=('red1','teal1','blu1','rst1','grey1','grn1','blu1','prpl1','red1')
METALS=('metal_brnz','metal_iron2','metal_slvr','metal_rust','metal_copp','metal_iron3','metal_iron2','metal_brass','metal_gold2')

def palette(i):
    block=i//9//3*3+i%9//3;color=COLORS[block];metal=METALS[block];brick='wht1' if block==4 else 'gry1' if block in (1,2,5,6) else 'red1'
    return dict(wall=f'ind_w03_{color}',upper=f'ind_w05_{color}',detail=f'ind_w07_{color}',brick=f'ind_brk0{1+i%4}_{brick}',trim=('metal_bras_04' if metal=='metal_brass' else metal+'_04'),ornament=metal+'_09',floor=f'ind_dp01_{color}',ceiling=f'ind_c0{1+i%4}_{color}',door=f'ind_door1_{color}',structure='metal_iron3_05',container=f'ind_cont1_{color}')

def collect(archive_dir):
    selected={v for i in range(81) for v in palette(i).values()};textures={};sources={}
    inventory=json.loads((ROOT/'tools/makkon/inventory.json').read_text())
    for pack in inventory['packs']:
        if pack['archive']=='makkon_CTF.zip':continue
        path=archive_dir/pack['archive'];raw=path.read_bytes();assert sha(raw)==pack['sha256']
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                if not name.lower().endswith('.wad'):continue
                data=z.read(name);wad_hash=sha(data)
                for key,record in wad_textures(data).items():
                    if key not in selected:continue
                    textures[key]=record;sources[key]=dict(author='Ben "Makkon" Hale',source=inventory['source'],archive=pack['archive'],archive_sha256=pack['sha256'],wad=name,wad_sha256=wad_hash,sha256=sha(record),format='original WAD2 miptex; all four mip levels unchanged',license='Makkon_License.txt; project-specific FPSloppa permission recorded in tools/makkon/README.md')
    assert selected==textures.keys(),selected-textures.keys()
    write_wad(BASE/'materials.wad',textures);(BASE/'materials.json').write_text(json.dumps(sources,indent=2)+'\n')
    return textures,sources

def write_wad(path,textures):
    data=bytearray(b'WAD2'+bytes(8));directory=[]
    for key,record in sorted(textures.items()):
        directory.append(struct.pack('<iiiBBH16s',len(data),len(record),len(record),68,0,0,key.encode()));data.extend(record)
    at=len(data);data.extend(b''.join(directory));struct.pack_into('<ii',data,4,len(directory),at);path.write_bytes(data)

def retexture(task):
    i,compiler=task;folder=BASE/f'district_{i:02}';layout=json.loads((folder/'layout.json').read_text());p=palette(i)
    source=folder/'district.map';text=source.read_text()
    # A retained original makes reapplication deterministic, never cascading.
    original=folder/'geometry.map'
    if not original.exists():original.write_text(text)
    text=original.read_text();palette_sources=json.loads((BASE/'materials.json').read_text());native=wad_textures((BASE/'materials.wad').read_bytes())
    textures=wad_textures((folder/'city.wad').read_bytes());provenance=json.loads((folder/'texture-sources.json').read_text())
    used=set();counts={}
    def face(m):
        prefix,old,tail=m.groups();new=old
        points=[tuple(map(float,v.split())) for v in re.findall(r'\(\s*([^()]+)\s*\)',prefix)]
        y=sum(v[2] for v in points)/len(points)/32
        a,b,c=points;u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)];horizontal=abs(u[0]*v[1]-u[1]*v[0])>abs(u[1]*v[2]-u[2]*v[1])+abs(u[2]*v[0]-u[0]*v[2])
        if old.startswith('ind_w'):new=p['wall'] if y<7 else p['upper']
        elif old.startswith('metal_'):new=p['trim'] if y<6 else p['ornament']
        elif old in ('med_dbrick6','med_ebrick18','med_csl_brk17b','med_dbrick1_t3','med_csl_brk2_2','med_csl_brk7_1b','med_csl_brk7_2','med_csl_brk7_2b'):new=p['brick']
        elif old=='comp1_2':new=p['detail']
        elif old=='crate0_side':new=p['container']
        elif old.startswith('ind_cont'):new=p['container']
        if new!=old and horizontal:
            if y>10:new=p['ceiling']
            elif y>1:new=p['floor']
        if new!=old:
            # Preserve authored world-unit texture coordinates and density.
            # Scaling UVs here also multiplies BSP lightmap samples and would
            # exhaust the per-map atlas budget on large roofs and street slabs.
            counts[new]=counts.get(new,0)+1
        used.add(new);return prefix+new+tail
    text=re.sub(r'^(\s*\([^\n]+\)\s+)([^\s]+)([^\n]*)$',face,text,flags=re.M)
    source.write_text(text)
    for key in used:
        if key in native:textures[key]=native[key];provenance[key]=palette_sources[key]
    used.add('skip');write_wad(folder/'city.wad',{k:textures[k] for k in used})
    (folder/'texture-sources.json').write_text(json.dumps({k:provenance[k] for k in used if k!='skip'},indent=2)+'\n')
    layout.update(material_revision='makkon-expanded-1',material_palette=p,makkon_faces=counts,source_texture_names=sorted(used-{'skip'}),textures=len(used)-1)
    (folder/'layout.json').write_text(json.dumps(layout,indent=2)+'\n');bsp=folder/'district.bsp';runs=[]
    for binary,flags in [('qbsp',['-leaktest','-noclip','-subdivide','1024',str(source),str(bsp)]),('vis',['-threads','2',str(bsp)]),('light',['-threads','2','-extra','-bspxlit','-bounce','1','-bouncecolorscale','0.35','-dirt','1','-dirtdepth','64','-dirtscale','0.6','-minlight_dirt','1',str(bsp)])]:
        began=time.monotonic()
        with (folder/(binary+'.log')).open('w') as log:subprocess.run([str(Path(compiler)/binary),*flags],cwd=folder,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
        runs.append(dict(tool=binary,seconds=time.monotonic()-began))
    result=audit(bsp.read_bytes());result.update(zone=i,name=layout['name'],format='BSP29',baked=True,commands=runs,material_revision='makkon-expanded-1')
    (folder/'build.json').write_text(json.dumps(result,indent=2)+'\n');return dict(district=i,bytes=result['bytes'],makkon_materials=len(counts))

def main():
    p=argparse.ArgumentParser();p.add_argument('--archives',type=Path);p.add_argument('--compiler',required=True);p.add_argument('--districts',type=int,nargs='+',default=list(range(81)));p.add_argument('--jobs',type=int,default=4);a=p.parse_args()
    if a.archives:collect(a.archives)
    with concurrent.futures.ProcessPoolExecutor(max_workers=a.jobs,max_tasks_per_child=1) as pool:
        for result in pool.map(retexture,[(i,a.compiler) for i in a.districts]):print('CAMPAIGN_BUILT',json.dumps(result),flush=True)
if __name__=='__main__':main()
