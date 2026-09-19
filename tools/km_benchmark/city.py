"""Vesper Megalopolis: original city geometry, reviewed embedded texture library."""
import argparse, hashlib, json, math, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'maps/Benchmark1km';ID='prototype_km1'
sys.path.insert(0,str(ROOT/'tools'))
from generate_tf_maps import Arena
TEX=ROOT/'deathmatch/maps/texture_replacements'
THEMES=[
 ('Cathedral Exchange','cathedral','60d9e8','med_dbrick6','metal_copp_01'),
 ('Helix Arcology','arcology','6ee6b1','ind_w02_grn1','ind_dp01_grn1'),
 ('Crucible Works','foundry','ffad58','med_csl_brk17b','ind_dp01_rst1'),
 ('Astral Observatory','observatory','af9fff','ind_w02_blu1','metal_iron1_01'),
 ('Reliquary Archives','cathedral','e9c36b','med_ebrick18','metal_copp_04'),
 ('Synapse Data Vault','data','64afff','ind_w04_grey1','ind_dp01_blu1'),
 ('Pilgrim Transit','transit','ffc369','metal_iron1_01','ind_dp01_ylw1'),
 ('Sanctum Medica','arcology','b4ecdf','ind_w02_grey1','metal_iron1_01'),
 ('Blackwater Condensers','foundry','5dc5ce','ind_w04_blk1','ind_dct2_blu1'),
 ('Ember Market','market','fa8b80','med_dbrick1_t3','ind_dp01_red1'),
 ('Cipher Court','observatory','a899e7','med_csl_brk2_2','ind_cont2_prpl1'),
 ('Aegis Bastion','bastion','f17e79','ind_w02_blk1','ind_w01_red1'),
 ('Verdant Cloister','garden','92cf92','med_csl_brk7_2','ind_w08_grn1'),
 ('Meridian Reactor','reactor','d4ef78','ind_w06_rst2','ind_w01_ylw1'),
 ('Iron Docks','docks','77aadd','ind_w04_blu1','ind_cont1_ylw1'),
 ('Crown Necropolis','cathedral','d692df','med_csl_brk7_1b','metal_iron1_01')]
IRON='metal_iron1_01';STONE='med_dbrick6';FLOOR='med_flat8'
def q(p):return(-p[2]*32,-p[0]*32,p[1]*32)
def colour(s):return tuple(int(s[i:i+2],16)/255 for i in (0,2,4))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
class City(Arena):
 def __init__(self):
  super().__init__(ID,'Vesper Megalopolis');self.detail=[];self.names=set();self.solids=[];self.zones=[];self.spawns=[];self.art=[];self.gates=[];self.scale=1.;self.structural=False;self.emitters=[]
 def face(self,points,texture):
  self.names.add(texture)
  return super().face(points,texture).rsplit(' ',2)[0]+f' {self.scale:g} {self.scale:g}'
 def block(self,lo,hi,tex=IRON,solid=False,scale=None):
  self.scale=scale if scale is not None else (.75 if tex.startswith(('ind_','metal_')) else 2)
  a=q(lo);b=q(hi);before=len(self.brushes);self.box(tuple(min(x,y) for x,y in zip(a,b)),tuple(max(x,y) for x,y in zip(a,b)),tex)
  if not self.structural:self.detail.append(self.brushes.pop())
  if solid:self.solids.append({'minimum':lo,'maximum':hi})
 def hull(self,points,faces,tex):
  center=tuple(sum(p[i] for p in points)/len(points) for i in range(3));lines=[];self.scale=1.5
  for face in faces:
   p=[points[i] for i in face[:3]];n=cross(sub(p[1],p[0]),sub(p[2],p[0]))
   if sum(a*b for a,b in zip(n,sub(p[0],center)))<0:p.reverse()
   lines.append(self.face([q(v) for v in p],tex))
  self.detail.append('{\n'+'\n'.join(lines)+'\n}')
 def spire(self,x,z,y,r,h,tex=IRON):
  self.hull([(x-r,y,z-r),(x+r,y,z-r),(x+r,y,z+r),(x-r,y,z+r),(x,y+h,z)],[[0,1,2],[0,4,1],[1,4,2],[2,4,3],[3,4,0]],tex)
 def cylinder(self,x,z,y,r,h,tex=IRON,n=8):
  pts=[(x+math.cos(i*math.tau/n)*r,y+dy,z+math.sin(i*math.tau/n)*r) for dy in (0,h) for i in range(n)]
  self.hull(pts,[list(range(n)),list(range(n,2*n))]+[[i,(i+1)%n,(i+1)%n+n] for i in range(n)],tex)
 def point(self,kind,p,**kw):self.ent(kind,q((p[0],p[1]+.7,p[2])),**kw)
 def light(self,p,power=600,col=(.65,.8,1),fixture="architectural"):
  self.ent('light',q(p),light=power,_color=' '.join(f'{v:.3f}' for v in col),delay=5)
  self.emitters.append(dict(position=p,power=power,color=col,fixture=fixture))
 def glow(self,zone,p,size,color,kind='box',**kwargs):self.art.append(dict(zone=zone,position=p,size=size,color=color,kind=kind,**kwargs))
 def building(self,zone,x,z,theme,quadrant):
  name,style,tint,wall,trim=theme;h=[34,42,52,38][quadrant]+(zone%3)*4;w=24;d=23
  self.structural=True;self.block((x-w,0,z-d),(x+w,h,z+d),wall,True,scale=2);self.structural=False
  self.block((x-w-2,0,z-d-2),(x+w+2,1.2,z+d+2),'med_cobstn2_1',scale=3)
  for y in [8,h-2,h]:self.block((x-w-1,y,z-d-1),(x+w+1,y+.7,z+d+1),trim)
  # Closer-facing facades combine tall lancets with a mechanical crown.
  sx=1 if (quadrant%2)==0 else -1;sz=1 if quadrant<2 else -1
  for axis,side in [(0,sx),(2,sz)]:
   for offset in [-16,0,16]:
    p=[x,0,z];p[axis]+=side*(w+1 if axis==0 else d+1);p[2-axis]+=offset
    lo=[p[0]-1.1,1.2,p[2]-1.1];hi=[p[0]+1.1,h+3,p[2]+1.1];self.block(lo,hi,IRON)
    if offset:self.spire(p[0],p[2],h+3,1.5,7,trim)
   for offset in [-8,8]:
    p=[x,0,z];p[axis]+=side*(w+.15 if axis==0 else d+.15);p[2-axis]+=offset
    lo=[p[0]-2.5,11,p[2]-2.5];hi=[p[0]+2.5,h-6,p[2]+2.5]
    lo[axis]=p[axis]-.18;hi[axis]=p[axis]+.18;self.block(lo,hi,'window01_1' if style in ['cathedral','garden'] else 'comp1_1',scale=2)
    size=[4.0,h-19,4.0];size[axis]=.06;p[1]=(11+h-8)/2;p[axis]+=side*.22
    self.glow(zone,p,size,tint,'window',gothic=style in ['cathedral','garden'])
    for ly in [13,h-10]:self.light((p[0]+(side*2 if axis==0 else 0),ly,p[2]+(side*2 if axis==2 else 0)),700,colour(tint),"window")
  # Monumental corner roof silhouettes differentiate sectors at skyline distance.
  if style in ['cathedral','garden']:
   self.spire(x,z,h+1,20,23,trim)
   for dx,dz in [(-21,-20),(21,20)]:
    self.block((x+dx-3,h,z+dz-3),(x+dx+3,h+15,z+dz+3),wall);self.spire(x+dx,z+dz,h+15,4,18,trim)
   self.glow(zone,(x,h+25,z),(2,6,2),tint,'beacon')
  elif style in ['foundry','reactor']:
   for dx in [-12,12]:
    self.cylinder(x+dx,z,h,6,20,trim);self.cylinder(x+dx,z,h+19,7,2,IRON)
    self.glow(zone,(x+dx,h+22,z),(7,2,7),tint,'ring');self.glow(zone,(x+dx,h+22,z),(3,10,3),tint,'steam')
  elif style=='observatory':
   self.cylinder(x,z,h,16,7,trim,12);self.spire(x,z,h+7,15,24,wall)
   self.glow(zone,(x,h+27,z),(12,12,12),tint,'orbital')
  elif style in ['data','arcology']:
   for tier in range(3):
    r=18-tier*4;self.block((x-r,h+tier*10,z-r),(x+r,h+tier*10+9,z+r),trim)
    self.glow(zone,(x,h+tier*10+8,z),(r*2+.3,.4,r*2+.3),tint,'box')
   self.spire(x,z,h+30,2,14,IRON)
  elif style=='transit':
   self.block((x-18,h,z-8),(x+18,h+5,z+8),'ind_cont2_prpl1');self.glow(zone,(x,h+5.4,z),(32,.5,12),tint,'box')
  elif style=='docks':
   self.block((x-3,h,z-3),(x+3,h+24,z+3),trim);self.block((x-29,h+22,z-2),(x+29,h+25,z+2),IRON)
   self.block((x+24,h+8,z-1),(x+25,h+23,z+1),trim)
  elif style=='bastion':
   for dx in [-18,18]:
    self.cylinder(x+dx,z,h,5,8,trim);self.block((x+dx-1.2,h+4,z-15),(x+dx+1.2,h+7,z),IRON)
  else:
   self.spire(x,z,h+1,22,12,'med_wood6');self.glow(zone,(x,h+13,z),(12,.8,12),tint,'ring')
  # Ground arcade portals: recessed technological shrines and projecting canopy.
  px=x; pz=z+sz*(d+1)
  self.block((px-9,6,pz-3),(px+9,7,pz+3),trim)
  for dx in [-8,8]:self.block((px+dx-.6,0,pz-1),(px+dx+.6,6,pz+1),IRON)
  self.glow(zone,(px,5.2,pz+sz*3.1),(10,.5,.08),tint)
  self.light((px,4,pz+sz*5),500,colour(tint),"canopy")
 def district(self,zone,x,z,theme):
  name,style,tint,wall,trim=theme
  self.zones.append(dict(id=zone,name=name,style=style,color=tint,center=[x,0,z],bounds=[x-125,z-125,x+125,z+125]))
  self.structural=True;self.block((x-125,-2,z-125),(x+125,0,z+125),'med_flat9' if zone%2 else FLOOR,False,scale=4);self.structural=False
  # Pavements and two clean transit axes; no collision changes at the 64 spawns.
  for axis in [0,2]:
   lo=[x-122,0,z-10];hi=[x+122,.05,z+10]
   if axis==0:lo[0],lo[2]=x-10,z-122;hi[0],hi[2]=x+10,z+122
   self.block(lo,hi,'ind_dp01_blk1',scale=3)
   for side in [-1,1]:
    lo=[x-122,0,z+side*13-2];hi=[x+122,.18,z+side*13+2]
    if axis==0:lo[0],lo[2]=x+side*13-2,z-122;hi[0],hi[2]=x+side*13+2,z+122
    self.block(lo,hi,'med_cobstn2_1a',scale=3)
  for quadrant,(dx,dz) in enumerate([(-72,-70),(72,-70),(-72,70),(72,70)]):self.building(zone,x+dx,z+dz,theme,quadrant)
  # Eight street lanterns and four sculpted reliquary pylons.
  for dx,dz in [(-16,-52),(16,-52),(-16,52),(16,52),(-52,-16),(-52,16),(52,-16),(52,16)]:
   self.block((x+dx-.35,0,z+dz-.35),(x+dx+.35,8,z+dz+.35),IRON)
   self.block((x+dx-1.4,7.7,z+dz-.5),(x+dx+1.4,8.3,z+dz+.5),trim)
   self.glow(zone,(x+dx,7.7,z+dz),(2.4,.2,.7),tint);self.light((x+dx+1,7.1,z+dz),1100,colour(tint),"streetlamp")
  for dx,dz in [(-29,-29),(29,-29),(-29,29),(29,29)]:
   self.block((x+dx-2.4,0,z+dz-2.4),(x+dx+2.4,1,z+dz+2.4),'med_cobstn2_1')
   self.block((x+dx-1,1,z+dz-1),(x+dx+1,5,z+dz+1),'altar1_3' if zone%2 else 'grave01_1',scale=1)
   self.spire(x+dx,z+dz,5,1.5,4,trim);self.glow(zone,(x+dx,5.5,z+dz),(3.5,.4,3.5),tint,'ring')
  # Street furniture in the building forecourts, never across a transit axis.
  for j,(dx,dz) in enumerate([(-34,-19),(34,19),(-19,34),(19,-34)]):
   for k in range(2):self.block((x+dx+k*3,0,z+dz-1),(x+dx+2.5+k*3,1.4+k*.3,z+dz+1),['ind_cont1_ylw1','ind_cont2_blk1','ind_cont2_prpl1','crate0_side'][(zone+j)%4])
   if style=='market':
    self.block((x+dx-1,3,z+dz-2),(x+dx+6,3.4,z+dz+2),trim);self.glow(zone,(x+dx+2,2.9,z+dz+2.1),(5,.35,.08),tint)
  # One accessible gallery per district, clear of the main buildings.
  self.block((x+24,0,z+30),(x+39,3,z+38),trim)
  self.scale=1.5;before=len(self.brushes);self.ramp_x(-32*(z+54),-32*(z+38),-32*(x+39),-32*(x+30),0,96,'metal_iron1_07');self.detail.append(self.brushes.pop())
  if style in ['garden','arcology']:
   for dx in [-38,38]:self.glow(zone,(x+dx,2,z),(7,4,7),tint,'garden')
  if style=='data':
   for dx in [-38,38]:self.glow(zone,(x+dx,7,z),(4,12,4),tint,'data')
  if style=='reactor':self.glow(zone,(x+31,8,z+34),(9,9,9),tint,'orbital')
  # Existing spawn/item coordinates are retained for the transfer/performance harness.
  for dx,dz in [(-20,-20),(20,-20),(-20,20),(20,20)]:
   pos=(x+dx,.1,z+dz);self.point('info_player_deathmatch',pos,angle=(zone*90)%360);self.spawns.append(list(pos))
  for kind,dx,dz in [('weapon_rocketlauncher',-7,0),('weapon_lightning',7,0),('weapon_supernailgun',0,7),('weapon_supershotgun',0,-7),('item_health',10,10),('item_armor2',-10,-10),('item_rockets',-10,10),('item_cells',10,-10)]:self.point(kind,(x+dx,.1,z+dz))
  self.glow(zone,(x,0.07,z),(18,.02,18),tint,'plaza')
  # Opaque walk-through transit faces, two independently streamed sides per gate.
  ix=zone%4;iz=zone//4
  for dx,dz,neighbor in [(-1,0,zone-1),(1,0,zone+1),(0,-1,zone-4),(0,1,zone+4)]:
   if not(0<=ix+dx<4 and 0<=iz+dz<4):continue
   self.gates.append(dict(zone=zone,neighbor=neighbor,position=[x+dx*124.94,8,z+dz*124.94],normal=[-dx,0,-dz],color=tint,name=THEMES[neighbor][0]))
  # Inner perimeter pilasters break up the large walls with gothic silhouettes.
  for dx,dz in [(-120,-90),(-120,-45),(120,45),(120,90),(-90,120),(-45,120),(45,-120),(90,-120)]:
   self.block((x+dx-1,0,z+dz-1),(x+dx+1,32,z+dz+1),trim);self.spire(x+dx,z+dz,32,2.2,9,IRON)
  # Additional material-family details: consoles, stamped trim, signs and medieval panels.
  for j,tex in enumerate(['comp1_2','tech02_7','tech05_1','met_brn_signs','med_dr3a','rune2_1']):
   dx=-42 if j%2 else 42;dz=-28+j*11
   self.block((x+dx-1,0,z+dz-.8),(x+dx+1,2.8,z+dz+.8),tex,scale=1)
 def build(self):
  self.structural=True
  for lo,hi in [((-502,-2,-502),(-500,160,502)),((500,-2,-502),(502,160,502)),((-500,-2,-502),(500,160,-500)),((-500,-2,500),(500,160,502))]:
   self.block(lo,(hi[0],30,hi[2]),STONE,True,scale=4)
   self.block((lo[0],30,lo[2]),hi,'sky1',False,scale=4)
  self.block((-502,160,-502),(502,162,502),'sky1',False,scale=4)
  for edge in [-250,0,250]:
   for axis in [0,2]:
    cursor=-500
    for opening in [-375,-125,125,375]:
     def b(a,b,y0=0,y1=30):
      lo=[a,y0,edge-2];hi=[b,y1,edge+2]
      if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
      self.block(lo,hi,STONE,True,scale=4)
     b(cursor,opening-12);b(opening-12,opening+12,16,30);cursor=opening+12
    b(cursor,500)
  self.structural=False
  for zone,theme in enumerate(THEMES):self.district(zone,-375+(zone%4)*250,-375+(zone//4)*250,theme)
 def night_emitters(self):
  # Bake the illumination represented by the cached emissive art; never add runtime lights.
  for row in self.art:
   x,y,z=row['position'];sx,sy,sz=row['size'];kind=row['kind'];col=colour(row['color'])
   if kind=='ring':
    for side in [-1,1]:self.light((x+side*(sx*.5+.6),y,z),160,col,'emissive_ring')
   elif kind=='beacon':self.light((x,y+sy*.5+.5,z),130,col,'beacon')
   elif kind=='orbital':
    for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:self.light((x+dx*(sx*.5+.5),y,z+dz*(sz*.5+.5)),170,col,'orbital')
   elif kind=='box' and y>25:
    for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:self.light((x+dx*(sx*.5+.5),y,z+dz*(sz*.5+.5)),180,col,'roof_band')
   elif kind=='data':
    for dx in [-1,1]:self.light((x+dx*(sx*.5+1),y,z),350,col,'data_pylon')
   elif kind=='plaza':
    for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:self.light((x+dx*sx*.5,.65,z+dz*sz*.5),75,col,'plaza_ring')
  for row in self.gates:
   x,y,z=row['position'];nx,_,nz=row['normal'];col=colour(row['color'])
   for across in [-8,8]:
    for height in [3,11]:self.light((x+nx*3+nz*across,height,z+nz*3-nx*across),420,col,'gate')
  for row in self.zones:
   x,_,z=row['center']
   for dx,dz in [(-29,-26),(29,-26),(-29,26),(29,26)]:self.light((x+dx,2.6,z+dz),340,(1,.40,.12),'brazier')
def wad(names):
 m=json.loads((TEX/'manifest.json').read_text())['textures'];data=bytearray(b'WAD2'+bytes(8));directory=[];provenance={}
 for name in sorted(names):
  row=m[name];pack=(TEX/row.get('pack','replacement-miptex.lmp')).read_bytes();record=bytearray(pack[row['offset']:row['offset']+row['size']]);record[:16]=name.encode().ljust(16,b'\0')
  directory.append(struct.pack('<iiiBBH16s',len(data),len(record),len(record),68,0,0,name.encode()));data.extend(record);provenance[name]=row
 at=len(data);data.extend(b''.join(directory));struct.pack_into('<ii',data,4,len(directory),at);(OUT/'city.wad').write_bytes(data);(OUT/'texture-sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--compiler',type=Path,required=True);ap.add_argument('--geometry-only',action='store_true');args=ap.parse_args();OUT.mkdir(exist_ok=True)
 w=City();w.build();w.night_emitters();wad(w.names)
 world={'classname':'worldspawn','message':'VESPER MEGALOPOLIS | Gothic Future City','wad':'city.wad','_sunlight':'9','_sunlight2':'4','_sun_mangle':'35 -55 0','_sunlight_color':'.38 .52 1','_minlight':'1','_fpsloppa_light_response':'night','_lightmap_scale':'32','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_fpsloppa_city':'1'}
 def ent(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
 source=OUT/(ID+'.map');source.write_text('// Original city geometry; embedded textures retain their separate licences.\n{\n'+ent(world)+'\n'+'\n'.join(w.brushes)+'\n}\n{\n"classname" "func_detail_wall"\n'+'\n'.join(w.detail)+'\n}\n'+'\n'.join('{\n'+ent(e)+'\n}' for e in w.entities)+'\n')
 layout={'id':ID,'title':'Vesper Megalopolis','revision':'gothic-city-night-2','playable_metres':[1000,1000],'area_km2':1,'zones':w.zones,'spawns':w.spawns,'occluder_boxes':w.solids,'art':w.art,'gates':w.gates,'emitters':w.emitters,'lighting_profile':{'moon':9,'sky':4,'minlight':1,'response':'night'},'brushes':len(w.brushes)+len(w.detail),'textures':len(w.names),'lights':sum(e['classname']=='light' for e in w.entities)}
 (OUT/'layout.json').write_text(json.dumps(layout,indent=2)+'\n');bsp=OUT/(ID+'.bsp');receipts=[]
 commands=[('qbsp',['-leaktest','-noclip','-subdivide','1024',str(source),str(bsp)])]
 if not args.geometry_only:commands += [('vis',['-threads','8',str(bsp)]),('light',['-threads','8','-extra','-bspxlit','-bounce','1','-bouncecolorscale','0.35','-dirt','1','-dirtdepth','64','-dirtscale','0.6','-minlight_dirt','1',str(bsp)])]
 for binary,flags in commands:
  start=time.monotonic();print('CITY_BUILD',binary,flush=True)
  with (OUT/(binary+'.log')).open('w') as log:subprocess.run([str(args.compiler/binary),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
  receipts.append({'tool':binary,'seconds':time.monotonic()-start,'args':flags})
 data=bsp.read_bytes();assert struct.unpack_from('<I',data)[0]==29,'Must remain BSP29';assert len(data)<25000000,len(data)
 (OUT/'build.json').write_text(json.dumps({'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'format':'BSP29','revision':layout['revision'],'vertices':struct.unpack_from('<ii',data,28)[1]//12,'faces':struct.unpack_from('<ii',data,60)[1]//20,'nodes':struct.unpack_from('<ii',data,44)[1]//24,'lightmap_spacing':32,'commands':receipts},indent=2)+'\n');print('CITY_BUILT',len(data),layout['brushes'],'brushes',len(w.names),'textures',flush=True)
if __name__=='__main__':main()
