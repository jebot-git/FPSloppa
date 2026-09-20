"""Independent, sealed BSP29 Vesper districts, authored in local metre coordinates."""
import argparse, hashlib, json, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/km_benchmark'))
import city
from city import THEMES
OUT=ROOT/'maps/CQDistricts'
from urban import District
def wad(names):
 city.wad(names)
 path=OUT/'city.wad';data=bytearray(path.read_bytes());count,at=struct.unpack_from('<ii',data,4)
 directory=bytes(data[at:at+count*32]);data=data[:at]
 record=struct.pack('<16s6I',b'skip',16,16,40,296,360,376)+bytes(340)
 entry=struct.pack('<iiiBBH16s',len(data),len(record),len(record),68,0,0,b'skip');data.extend(record)
 at=len(data);data.extend(directory+entry);struct.pack_into('<ii',data,4,count+1,at);path.write_bytes(data)
def audit(data):
 assert struct.unpack_from('<i',data)[0]==29,'Compiler must not promote to BSP2'
 sizes={1:20,3:12,5:24,6:40,7:20,9:8,10:28,11:2,12:4,13:4,14:64}
 names={1:'planes',3:'vertices',5:'nodes',6:'texinfo',7:'faces',9:'clipnodes',10:'leaves',11:'marksurfaces',12:'edges',13:'surfedges',14:'models'}
 counts={names[k]:struct.unpack_from('<ii',data,4+8*k)[1]//size for k,size in sizes.items()}
 for key in ['vertices','faces','marksurfaces']:assert counts[key]<65535,(key,counts[key])
 for key in ['nodes','leaves','clipnodes']:assert counts[key]<32767,(key,counts[key])
 assert len(data)<=25000000,'FPSloppa per-map import limit'
 counts['bytes']=len(data);counts['sha256']=hashlib.sha256(data).hexdigest();return counts
def main():
 p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--zones',type=int,nargs='+',default=list(range(16)));p.add_argument('--geometry-only',action='store_true');args=p.parse_args();OUT.mkdir(exist_ok=True)
 city.OUT=OUT
 for zone in args.zones:
  assert zone in range(16)
  w=District(zone);w.build();wad(w.names)
  folder=OUT/('district_%02d'%zone);folder.mkdir(exist_ok=True)
  # One shared WAD on disk; each BSP embeds only the textures it actually uses.
  source=folder/'district.map';bsp=folder/'district.bsp'
  world={'classname':'worldspawn','message':THEMES[zone][0]+' | CQ DISTRICT %02d'%(zone+1),'wad':'../city.wad','_sunlight':'9','_sunlight2':'4','_sun_mangle':'35 -55 0','_sunlight_color':'.38 .52 1','_minlight':'1','_fpsloppa_light_response':'night','_lightmap_scale':'16','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096'}
  ent=lambda d:'\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
  source.write_text('// Original district geometry; embedded textures retain project licences.\n{\n'+ent(world)+'\n'+'\n'.join(w.brushes)+'\n}\n{\n"classname" "func_detail_wall"\n'+'\n'.join(w.detail)+'\n}\n'+'\n'.join('{\n'+ent(e)+'\n}' for e in w.entities)+'\n')
  offset=[-375+(zone%4)*250,0,-375+(zone//4)*250]
  layout={'id':zone,'name':THEMES[zone][0],'style':THEMES[zone][1],'origin':offset,'zones':[{'name':THEMES[i][0],'color':THEMES[i][2],'center':[0,0,0]} for i in range(16)],'art':w.art,'gates':w.gates,'spawns':w.spawns,'occluder_boxes':w.solids,'rooms':w.rooms,'routes':w.routes,'emitters':w.emitters,'brushes':len(w.brushes)+len(w.detail),'textures':len(w.names),'source_texture_names':sorted(w.names),'pickup_positions':w.pickup_positions,'street_plan':w.plan_name,'streets':w.streets,'street_points':w.street_points,'lots':w.lots,'props':w.props,'signs':w.signs,'revision':'organic-city-2'}
  (folder/'layout.json').write_text(json.dumps(layout,indent=2)+'\n')
  commands=[('qbsp',['-leaktest','-noclip','-subdivide','1024',str(source),str(bsp)])]
  if not args.geometry_only:commands += [('vis',['-threads','6',str(bsp)]),('light',['-threads','6','-extra','-bspxlit','-bounce','1','-bouncecolorscale','0.35','-dirt','1','-dirtdepth','64','-dirtscale','0.6','-minlight_dirt','1',str(bsp)])]
  runs=[]
  for binary,flags in commands:
   began=time.monotonic();print('DISTRICT_BUILD',zone,binary,flush=True)
   with (folder/(binary+'.log')).open('w') as log:subprocess.run([str(args.compiler/binary),*flags],cwd=folder,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
   runs.append({'tool':binary,'seconds':time.monotonic()-began})
  result=audit(bsp.read_bytes());result.update(zone=zone,name=THEMES[zone][0],brushes=layout['brushes'],textures=len(w.names),lights=len(w.emitters),format='BSP29',lightmap_spacing=16,baked=not args.geometry_only,commands=runs)
  (folder/'build.json').write_text(json.dumps(result,indent=2)+'\n');print('DISTRICT_BUILT',json.dumps(result),flush=True)
 # Regenerate a WAD covering all generated sources, so any map can be rebuilt independently.
 names=set()
 for path in OUT.glob('district_*/layout.json'):names.update(json.loads(path.read_text())['source_texture_names'])
 wad(names)
if __name__=='__main__':main()
