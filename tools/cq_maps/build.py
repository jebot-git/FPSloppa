"""Independent, sealed BSP29 Vesper districts, authored in local metre coordinates."""
import argparse, hashlib, json, math, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/km_benchmark'))
import city
from city import City,THEMES,IRON,STONE,colour
OUT=ROOT/'maps/CQDistricts'
class District(City):
 def __init__(self,zone):
  super().__init__();self.zone=zone;self.routes=[];self.rooms=[]
 def ramp(self,x,z,y,reverse=False):
  # Six metre wide switchback flight, 28 m run / 8 m rise.
  low,high=(14,-14) if reverse else (-14,14)
  self.hull([(x-3,y,z+low),(x+3,y,z+low),(x-3,y,z+high),(x+3,y,z+high),(x-3,y+8,z+high),(x+3,y+8,z+high)],[[0,2,3],[2,4,5],[0,1,5],[0,4,2],[1,3,5]],'metal_iron1_07')
  self.routes.append({'from':[x,y+.1,z+low-(-1 if reverse else 1)*2],'to':[x,y+8.1,z+high+(-1 if reverse else 1)*2],'kind':'ramp'})
 def wall(self,x,z,axis,side,wall):
  # Aligned ground and balcony doors on all four sides.
  for lo,hi in [(0,6),(8,14),(16,22)]:
   for a,b in [(-24,-5),(5,24)]:
    if axis==0:self.block((x+side*24-.5,lo,z+a),(x+side*24+.5,hi,z+b),wall)
    else:self.block((x+a,lo,z+side*24-.5),(x+b,hi,z+side*24+.5),wall)
  for lo,hi in [(6,8),(14,16),(22,27)]:
   if axis==0:self.block((x+side*24-.5,lo,z-24),(x+side*24+.5,hi,z+24),wall)
   else:self.block((x-24,lo,z+side*24-.5),(x+24,hi,z+side*24+.5),wall)
 def building(self,zone,x,z,theme,quadrant):
  name,style,tint,wall,trim=theme
  self.rooms.append({'center':[x,0,z],'levels':[0,8,16,24],'style':style,'quadrant':quadrant})
  self.structural=True
  for axis in [0,2]:
   for side in [-1,1]:self.wall(x,z,axis,side,wall)
  self.structural=False
  for level in [8,16,24]:
   for a,b in [(-23.5,-14),(14,23.5)]:self.block((x-23.5,level-.4,z+a),(x+23.5,level,z+b),trim)
   open_side=-1 if level in [8,24] else 1
   for side in [-1,1]:
    if side!=open_side:self.block((x+side*18.75-4.75,level-.4,z-14),(x+side*18.75+4.75,level,z+14),trim)
   # Balconies and a continuous exterior circuit, with door-aligned openings in rails.
   for side in [-1,1]:
    self.block((x-28,level-.4,z+side*26-2),(x+28,level,z+side*26+2),trim)
    self.block((x+side*26-2,level-.4,z-24),(x+side*26+2,level,z+24),trim)
    for a,b in [(-28,-4),(4,28)]:
     self.block((x+a,level,z+side*27.7-.2),(x+b,level+1.1,z+side*27.7+.2),IRON)
     self.block((x+side*27.7-.2,level,z+a),(x+side*27.7+.2,level+1.1,z+b),IRON)
   for a,b in [(-13,-4),(4,13)]:
    for side in [-1,1]:self.block((x+a,level,z+side*14-.2),(x+b,level+1.1,z+side*14+.2),IRON)
   self.glow(zone,(x,level-.15,z-28.06),(48,.15,.1),tint)
   self.glow(zone,(x,level-.15,z+28.06),(48,.15,.1),tint)
  self.ramp(x-18,z,0);self.ramp(x+18,z,8,True);self.ramp(x-18,z,16)
  # Lancets, buttresses and upper pointed arches frame usable interiors.
  for side in [-1,1]:
   for offset in [-20,-10,10,20]:
    self.block((x+offset-.45,0,z+side*24-.8),(x+offset+.45,31,z+side*24+.8),trim)
    self.spire(x+offset,z+side*24,31,1.2,6,trim)
    for level in [2,10,18]:
     self.glow(zone,(x+offset,level+1.5,z+side*24.56),(3,3,.08),tint,'window',gothic=style in ['cathedral','garden'])
   for y in [5,13,21]:
    self.light((x,y,z+side*19),800,colour(tint),'interior_strip')
    self.glow(zone,(x,y+.7,z+side*22),(11,.2,.3),tint)
  # Central landmark is below the gallery sight lines; the atrium remains open.
  if style in ['cathedral','garden']:
   for dx in [-10,10]:
    for dz in [-10,10]:
     self.block((x+dx-.7,0,z+dz-.7),(x+dx+.7,27,z+dz+.7),trim)
     self.spire(x+dx,z+dz,27,1.6,7,trim)
   self.block((x-4,0,z-4),(x+4,1,z+4),'med_cobstn2_1')
   self.block((x-2,1,z-1),(x+2,3,z+1),'altar1_3' if zone!=15 else 'grave01_1')
   self.glow(zone,(x,4,z),(6,.4,6),tint,'ring')
   if style=='garden':self.glow(zone,(x,3,z),(9,5,9),tint,'garden')
  elif style in ['foundry','reactor']:
   for dx in [-5,5]:self.cylinder(x+dx,z,0,3,6,trim);self.glow(zone,(x+dx,5.7,z),(6,.4,6),tint,'ring')
   for dz in [-7,7]:self.block((x-10,18,z+dz-.4),(x+10,19,z+dz+.4),IRON)
   self.glow(zone,(x,10,z),(9,9,9),tint,'orbital' if style=='reactor' else 'steam')
  elif style in ['observatory','data']:
   self.cylinder(x,z,0,4,2,trim,12);self.glow(zone,(x,5,z),(7,7,7),tint,'orbital' if style=='observatory' else 'data')
  elif style=='docks':
   for dx in [-7,3]:self.block((x+dx,0,z-5),(x+dx+4,3,z+5),'ind_cont1_ylw1')
   self.block((x-11,17,z-1),(x+11,18,z+1),IRON)
  else:
   for dz in [-7,7]:self.block((x-7,0,z+dz-1),(x+7,1,z+dz+1),trim)
  # Furnished floor edges: racks, beds, stalls, tombs, consoles, service columns.
  for level in [0,8,16]:
   for side in [-1,1]:
    for j in range(6):
     dx=-15+j*6;dz=side*20
     tex=['comp1_1','tech02_7','ind_cont2_prpl1','med_wood6','rune2_1','grave01_1'][(zone+j+quadrant)%6]
     h=2.6 if style in ['data','bastion','cathedral'] else 1.2
     self.block((x+dx-1.2,level,z+dz-1),(x+dx+1.2,level+h,z+dz+1),tex)
     self.block((x+dx-1.35,level+h,z+dz-1.1),(x+dx+1.35,level+h+.15,z+dz+1.1),trim)
     self.glow(zone,(x+dx,level+h+.2,z+dz),(1.8,.1,.9),tint)
    self.light((x,level+4,z+side*10),650,(.65,.72,.9),'gallery_fill')
  # A proper ceiling encloses the atrium; the outer 24 m gallery remains open-air.
  self.block((x-24,27,z-24),(x+24,27.6,z+24),wall)
  for dx in [-8,8]:
   for dz in [-8,8]:self.block((x+dx-.5,27,z+dz-.5),(x+dx+.5,31,z+dz+.5),trim)
  for axis in [0,2]:
   for side in [-1,1]:
    for level in [6,17]:
     p=[x,level,z];p[axis]+=side*27
     self.light(tuple(p),1500,colour(tint),'facade')
  # Distinct skyline crowns; roof routes remain around them.
  if style in ['cathedral','garden']:
   self.spire(x,z,31,11,22,trim);self.glow(zone,(x,51,z),(1,5,1),tint,'beacon')
  elif style in ['foundry','reactor']:
   for dx in [-8,8]:self.cylinder(x+dx,z,29,3,16,trim);self.glow(zone,(x+dx,45,z),(6,.5,6),tint,'ring')
  elif style=='observatory':self.glow(zone,(x,37,z),(18,18,18),tint,'orbital')
  else:
   self.block((x-5,29,z-5),(x+5,42,z+5),trim);self.spire(x,z,42,5,12,IRON)
  self.light((x,29,z),450,colour(tint),'atrium')
 def build(self):
  zone=self.zone;theme=THEMES[zone]
  self.district(zone,0,0,theme)
  # Sealed independent sky shell; the only playable boundary openings are gateways.
  self.structural=True
  self.block((-137,-3,-137),(137,-2,137),STONE)
  self.block((-137,110,-137),(137,112,137),'sky1')
  for axis in [0,2]:
   for side in [-1,1]:
    lo=[-137,-3,-137];hi=[137,110,137];lo[axis]=side*136-1;hi[axis]=side*136+1
    self.block(tuple(lo),tuple(hi),'sky1')
    neighbor=zone+side*(1 if axis==0 else 4)
    valid=0<=(zone%4 if axis==0 else zone//4)+side<4
    # Shared 24 x 16 m gate collar, plus a hidden 10 m continuation for handoff.
    for a,b in ([(-125,-12),(12,125)] if valid else [(-125,125)]):
     lo=[a,-2,side*125-1];hi=[b,36,side*125+1]
     if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
     self.block(tuple(lo),tuple(hi),theme[3],True)
    if valid:
     lo=[-12,16,side*125-1];hi=[12,36,side*125+1]
     if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
     self.block(tuple(lo),tuple(hi),STONE)
     lo=[-12,-2,min(side*124,side*136)];hi=[12,0,max(side*124,side*136)]
     if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
     self.block(tuple(lo),tuple(hi),IRON)
  self.structural=False
  # The four halls are connected by elevated loops over both transit axes.
  for z,y in [(-70,8),(70,16)]:self.bridge((-48,y,z-3),(48,y,z+3),0,theme)
  for x,y in [(-72,16),(72,8)]:self.bridge((x-3,y,-46),(x+3,y,46),2,theme)
  # Additional side streets: covered shops and utility alcoves with traversable gaps.
  for side in [-1,1]:
   for along in [-95,-62,-29,29,62,95]:
    x,z=along,side*109
    self.block((x-7,0,z-5),(x+7,.3,z+5),IRON)
    for dx in [-7,7]:self.block((x+dx-.3,.3,z-5),(x+dx+.3,6,z+5),theme[4])
    self.block((x-7,6,z-5),(x+7,6.5,z+5),theme[4]);self.block((x-5,.3,z+2),(x+5,1.3,z+4),['comp1_2','ind_cont2_blk1','med_wood6'][zone%3])
    self.glow(zone,(x,5.5,z-side*5.1),(10,.4,.12),theme[2]);self.light((x,4,z),380,colour(theme[2]),'alley_shop')
  for axis in [0,2]:
   for side in [-1,1]:
    for along in [35,90]:
     p=[side*along,5,0] if axis==0 else [0,5,side*along]
     self.light(p,1400,(.6,.72,1),'street_fill')
  self.night_emitters()
 def bridge(self,lo,hi,axis,theme):
  a=list(lo);b=list(hi);a[1]-=.5;self.block(tuple(a),tuple(b),theme[4])
  other=2-axis
  for side in [-1,1]:
   a=list(lo);b=list(hi);edge=lo[other] if side<0 else hi[other];a[other]=edge-.2;b[other]=edge+.2;b[1]+=1.2
   self.block(tuple(a),tuple(b),IRON)
  for side in [-1,1]:
   center=[(lo[i]+hi[i])*.5 for i in range(3)];center[other]=lo[other] if side<0 else hi[other];center[1]+=1.25
   size=[.12,.12,.12];size[axis]=hi[axis]-lo[axis];self.glow(self.zone,center,size,theme[2])
  for t in [.25,.75]:
   pos=[lo[i]+(hi[i]-lo[i])*t for i in range(3)];pos[1]+=2
   self.light(pos,700,(.6,.72,1),'bridge')
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
  layout={'id':zone,'name':THEMES[zone][0],'style':THEMES[zone][1],'origin':offset,'zones':[{'name':THEMES[i][0],'color':THEMES[i][2],'center':[0,0,0]} for i in range(16)],'art':w.art,'gates':w.gates,'spawns':w.spawns,'occluder_boxes':w.solids,'rooms':w.rooms,'routes':w.routes,'emitters':w.emitters,'brushes':len(w.brushes)+len(w.detail),'textures':len(w.names),'source_texture_names':sorted(w.names),'pickup_positions':[[-7,.1,0],[7,.1,0],[-54,8.1,-52],[54,16.1,-88],[-54,16.1,88],[54,8.1,52],[-10,.1,10],[10,.1,-10]]}
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
