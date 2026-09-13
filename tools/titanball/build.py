"""Build Ashfall Boulevard: original, sealed BSP29 payload district."""
from pathlib import Path
import argparse, hashlib, json, math, random, re, shutil, struct, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from generate_tf_maps import Arena
from pressureworks.build import materials
ID='tb_ashfall';OUT=ROOT/'maps/Ashfall'
BRICK='ind_brk01_brwn';GREY='ind_brk02_gry1';RED='ind_brk02_red1';IRON='metal_iron1_01';GRATE='metal_iron1_07';FLOOR='med_flat5a';STONE='med_cobstn1_2';SKY='sky_star'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def q(v):return (-v[2]*32,-v[0]*32,v[1]*32)
class City(Arena):
 def __init__(self):super().__init__(ID,'Ashfall Boulevard | TITANBALL');self.models=[];self.detail=[];self.route=json.loads((OUT/'route.json').read_text());self.probes={'rooms':[],'bridges':[],'spawns':[]}
 def face(self,points,texture):
  scale=.5 if texture.startswith(('ind_','metal_')) else 1
  return super().face(points,texture).rsplit(' ',2)[0]+f' {scale} {scale}'
 def local(self,d,p):
  f=self.route['samples'][max(0,min(300,round(d)))];o=f['position'];x=f['right'];z=f['forward']
  return tuple(o[i]+x[i]*p[0]+(p[1] if i==1 else 0)+z[i]*p[2] for i in range(3))
 def box(self,lo,hi,t=BRICK,d=None,detail=False):
  x,y,z=lo;X,Y,Z=hi
  assert X>x and Y>y and Z>z,(lo,hi)
  # Explicit outward planes; local XYZ is Godot XYZ and q() is a rotation.
  faces=[[(x,y,z),(x,Y,z),(X,Y,z)],[(x,y,Z),(X,y,Z),(X,Y,Z)],[(x,y,z),(X,y,z),(X,y,Z)],[(X,y,z),(X,Y,z),(X,Y,Z)],[(X,Y,z),(x,Y,z),(x,Y,Z)],[(x,Y,z),(x,y,z),(x,y,Z)]]
  text='{\n'+'\n'.join(self.face([q(self.local(d,p) if d is not None else p) for p in f],t) for f in faces)+'\n}'
  (self.detail if detail else self.brushes).append(text)
 def point(self,kind,p,**fields):self.ent(kind,q((p[0],p[1]+.70,p[2])),**fields)
 def light(self,p,power=420,color='1 .8 .6'):self.ent('light',q(p),light=power,_color=color,delay=2)
 def prop_brush(self,d,centre,vertices,texture,yaw=0,roll=0):
  """Convex solid detail brush; local vertices use the ordinary box corner order."""
  cy,sy=math.cos(math.radians(yaw)),math.sin(math.radians(yaw));cr,sr=math.cos(math.radians(roll)),math.sin(math.radians(roll))
  points=[]
  for x,y,z in vertices:
   x,y=x*cr-y*sr,x*sr+y*cr
   x,z=x*cy+z*sy,-x*sy+z*cy
   points.append(q(self.local(d,(x+centre[0],y+centre[1],z+centre[2]))))
  faces=[[0,1,2],[4,7,6],[0,4,5],[1,5,6],[2,6,7],[3,7,4]]
  self.detail.append('{\n'+'\n'.join(self.face([points[i] for i in face],texture) for face in faces)+'\n}')
 def prop_box(self,d,centre,size,texture,yaw=0,roll=0):
  x,y,z=[v/2 for v in size]
  self.prop_brush(d,centre,[(-x,-y,-z),(x,-y,-z),(x,-y,z),(-x,-y,z),(-x,y,-z),(x,y,-z),(x,y,z),(-x,y,z)],texture,yaw,roll)
 def street_cover(self):
  rng=random.Random(7129);self.probes['cover']=[]
  # The robot's swept envelope stays central. Cover occupies alternating street
  # shoulders, with several metres left open toward the rooms and ramp towers.
  for i,d in enumerate([30,52,112,136,154,210,250,288]):
   side=-1 if i%2 else 1;x=side*(9.5 if i%3 else 10.3);yaw=side*([12,-9,18][i%3])
   def part(offset,size,texture,roll=0):
    angle=math.radians(yaw);dx,dz=offset[0]*math.cos(angle)+offset[2]*math.sin(angle),-offset[0]*math.sin(angle)+offset[2]*math.cos(angle)
    self.prop_box(d,(x+dx,offset[1],dz),size,texture,yaw,roll)
   part((0,.48,0),(2.1,.70,4.6),IRON)
   # Crushed cabin / dark window band / retained roof, no transparent shader.
   self.prop_brush(d,(x,0,-.15),[(-.95,.80,-1.25),(.95,.80,-1.25),(.95,.80,1.05),(-.95,.80,1.05),(-.73,1.60,-.95),(.73,1.60,-.95),(.73,1.60,.65),(-.73,1.60,.65)],'ind_w02_blk1',yaw)
   part((0,1.64,-.28),(1.58,.15,1.7),IRON,4*side)
   part((0,.84,1.68),(2.0,.14,1.25),'ind_cont1_ylw1' if i%2 else 'ind_dp01_red1',-5*side)
   for wheel_x in [-1.04,1.04]:
    for wheel_z in [-1.5,1.5]:part((wheel_x,.35,wheel_z),(.28,.65,.72),'ind_w02_blk1')
   self.probes['cover'].append({'kind':'wreck','distance':d,'centre':self.local(d,(x,.05,0)),'height':1.72})
  for i,d in enumerate([24,40,60,76,102,120,144,164,184,216,240,260,282,294]):
   for side in [-1,1]:
    x=side*(9.0+rng.uniform(0,1.0));height=1.0 if i%3 else 1.45
    self.prop_brush(d,(x,0,0),[(-1.8,.01,-1.6),(1.8,.01,-1.6),(1.8,.01,1.6),(-1.8,.01,1.6),(-.6,height-.35,-.55),(.6,height-.35,-.55),(.6,height-.35,.55),(-.6,height-.35,.55)],STONE,rng.uniform(-18,18))
    for j in range(4):
     size=(rng.uniform(1.0,2.4),rng.uniform(.4,.8),rng.uniform(1.0,2.3))
     centre=(x+(0 if j==3 else rng.uniform(-.85,.85)),height-.25 if j==3 else size[1]*.35,0 if j==3 else rng.uniform(-1.1,1.1))
     self.prop_box(d,centre,size,[GREY,BRICK,STONE][(i+j)%3],rng.uniform(-32,32),rng.uniform(-12,12))
    self.probes['cover'].append({'kind':'rubble','distance':d,'centre':self.local(d,(x,.05,0)),'height':height})
  for i,d in enumerate([44,64,128,158,222,264]):
   side=-1 if i%2 else 1;x=side*7.9
   self.prop_box(d,(x,1.05,0),(.7,2.1,3.6),GREY,side*8)
   self.prop_box(d,(x,.45,2.3),(1.15,.85,1.4),BRICK,side*21,side*9)
   self.probes['cover'].append({'kind':'broken_wall','distance':d,'centre':self.local(d,(x,.05,0)),'height':2.1})
 def ramp(self,d,x,z0,z1,y0,y1,width=3.4):
  # Closed wedge, keeping horizontal undersides above the flight below.
  lo=min(y0,y1)-.25
  pts=[(x-width/2,lo,z0),(x+width/2,lo,z0),(x+width/2,lo,z1),(x-width/2,lo,z1),(x-width/2,y0,z0),(x+width/2,y0,z0),(x+width/2,y1,z1),(x-width/2,y1,z1)]
  # Use a nonzero thickness at both ends and outward faces from the box pattern.
  faces=[[0,3,2],[4,5,6],[0,1,5],[1,2,6],[2,3,7],[3,0,4]]
  if z1>z0:faces=[list(reversed(face)) for face in faces]
  self.detail.append('{\n'+'\n'.join(self.face([q(self.local(d,pts[i])) for i in face],STONE) for face in faces)+'\n}')
 def build(self):
  # Rasterise structural masses onto a 64-unit grid, merging identical cells.
  # This gives continuous, editable orthogonal facades along the curved street.
  cell=2.;xmin,xmax=-64,64;zmin,zmax=-10,270
  samples=self.route['samples']
  def nearest(x,z):
   row=min(samples,key=lambda r:(r['position'][0]-x)**2+(r['position'][2]-z)**2)
   dx=x-row['position'][0];dz=z-row['position'][2]
   return math.hypot(dx,dz),row['distance'],dx*row['right'][0]+dz*row['right'][2]
  grids={}
  for iz,z in enumerate(range(zmin,zmax,2)):
   for ix,x in enumerate(range(xmin,xmax,2)):
    distance,along,side=nearest(x+1,z+1)
    # Hangar occupies the first 18 metres with its own sealed architecture.
    if -24<=x<24 and -8<=z<20:continue
    records=[]
    if distance>26:records=[(0,12,GREY),(12,48,SKY)]
    elif distance>=24:records=[(0,48,GREY)]
    elif distance>=18:
     height=[26,34,22,38][int(along//16)%4]
     texture=[BRICK,GREY,RED][int(along//16)%3]
     # Ground-floor arcade / rooms, with road doors every twelve metres.
     door=abs((along-6)%12-6)<2.2 or abs(along-72)<4 or abs(along-172)<4 or along>294
     if distance<20 and not door:records.append((0,4,texture))
     # Side-room partitions retain a door along the interior connecting street.
     if 20<=distance<24 and int(along)%16<2 and abs(distance-22)>1.1:records.append((0,4,texture))
     records += [(4,height,texture),(height,48,SKY)]
    if abs(x+1)<24 and 20<=z<26:records=[record for record in records if record[0]>=4]
    for record in records:grids.setdefault(record,set()).add((ix,iz))
  for (bottom,top,texture),cells in grids.items():
   while cells:
    ix,iz=min(cells,key=lambda c:(c[1],c[0]));w=1
    while (ix+w,iz) in cells:w+=1
    h=1
    while all((ix+dx,iz+h) in cells for dx in range(w)):h+=1
    for dz in range(h):
     for dx in range(w):cells.remove((ix+dx,iz+dz))
    self.box((xmin+ix*2,bottom,zmin+iz*2),(xmin+(ix+w)*2,top,zmin+(iz+h)*2),texture)
  self.box((xmin,-2,zmin),(xmax,0,zmax),FLOOR)
  self.box((xmin,48,zmin),(xmax,50,zmax),SKY)
  # Grid perimeter is a solid outer seal, not an accessible empty backdrop.
  for lo,hi in [((xmin-2,-2,zmin-2),(xmin,50,zmax+2)),((xmax,-2,zmin-2),(xmax+2,50,zmax+2)),((xmin,-2,zmin-2),(xmax,50,zmin)),((xmin,-2,zmax),(xmax,50,zmax+2))]:self.box(lo,hi,SKY)
  # Texture trim, window bands and broken cornices read from street level.
  for d in range(24,299,8):
   for side in [-1,1]:
    x=side*17.7
    for y in [6.,10.,14.,18.]:
     self.box((x-.15,y-1.0,-2.2),(x+.15,y+1.0,2.2),'ind_w02_blk1',d,True)
     self.box((x-.35,y+1.,-2.5),(x+.35,y+1.3,2.5),IRON,d,True)
    if d%24==0:self.box((x-.5,20,-1),(x+.5,23,1),GREY,d,True)
   self.light(self.local(d,(0,11,0)),480,'.8 .86 1')
  for d in [36.,60.,108.,144.,204.,228.,264.]:
   for side in [-1,1]:
    p=self.local(d,(side*16,0,0));self.box((side*16-1,.0,-1),(side*16+1,1.2,1),GREY,d)
    self.probes['rooms'].append({'centre':self.local(d,(side*22,.05,0))})
    self.light(self.local(d,(side*22,2.4,0)),180,'1 .66 .38')
  # Elevated crossings with switchback stairs enclosed by the city masses.
  for d in [88.,198.]:
   self.box((-13,12.5,-3),(13,13.2,3),IRON,d)
   for z in [-3.,2.7]:self.box((-13,13.2,z),(13,14.2,z+.3),GRATE,d)
   for side in [-1,1]:
    # Access tower takes sidewalk space; the centre 26 m remains unobstructed.
    x=side*15.5
    for flight in range(4):
     forward=flight%2==0;lane=x+side*(-.95 if forward else .95)
     self.ramp(d,lane,-6 if forward else 6,6 if forward else -6,flight*3.3,(flight+1)*3.3,1.7)
     zend=6 if forward else -8
     self.box((x-2,(flight+1)*3.3-.25,zend),(x+2,(flight+1)*3.3,zend+2),STONE,d,True)
    self.box((min(side*13,x),12.95,-6),(max(side*13,x),13.2,3),STONE,d,True)
    self.probes['bridges'].append({'bottom':self.local(d,(x-side*.95,.05,-6)),'top':self.local(d,(x-side*.8,13.25,0))})
  self.hangar();self.street_cover()
  for stage,d in enumerate([0,72,172]):self.spawn_group(d,0,stage)
  self.spawn_group(300,1,0)
  self.gameplay_markers()
  for i,p in enumerate(self.route['points']):self.point('info_tb_route',p,order=i)
  for i,d in enumerate([80,180]):
   self.point('info_tb_checkpoint',self.local(d,(0,0,0)),stage=i+1,distance=d)
   for side in [-1,1]:self.box((side*12.4-.2,0,-.2),(side*12.4+.2,12.8,.2),'ind_cont1_ylw1',d)
   self.box((-12.6,12.8,-.2),(12.6,13.2,.2),'ind_cont1_ylw1',d)
  # Last block: pillbox frontage, protected firing positions and a heavy base arch.
  for d in [236.,278.]:
   for side in [-1,1]:
    x=side*15.5
    self.box((x-1.9,3.8,-5),(x+1.9,4.2,5),GREY,d)
    for z in [-4.,2.]:self.box((x-2,4.2,z),(x+2,5.1,z+2),GREY,d)
    self.ramp(d,x,-14,-5,0,4.2,3)
  self.box((-24,14,5),(24,16,8),GREY,300)
  for side in [-1,1]:self.box((side*23-.8,0,5),(side*23+.8,14,8),GREY,300)
  self.point('info_tb_goal',self.local(300,(0,0,0)))
  self.point('info_player_deathmatch',(0,.05,6),angle=180)
  self.point('info_player_start',(0,.05,6),angle=180)
  self.light((0,11,0),700,'1 .72 .4')
 def spawn_group(self,d,team,stage):
  for side in [-1,1]:
   for z in [-1.,1.]:
    p=self.local(d,(side*17,.05,z));self.point('info_tb_spawn',p,team=team,stage=stage,angle=180 if team==0 else 0)
    self.probes['spawns'].append({'position':p,'team':team,'stage':stage})
  for side in [-1,1]:self.box((side*17-1.8,0,3),(side*17+1.8,2.6,3.4),'ind_dp01_red1' if team==0 else 'ind_dp01_blu1',d)
 def gameplay_markers(self):
  # One per base, two flanking each checkpoint along the route. All are shared.
  for d,x,z in [(0,14,-1),(70,16,0),(96,-11,0),(170,16,0),(196,-11,0),(298,-15,0)]:
   self.point('info_tb_resupply',self.local(d,(x,.05,z)),distance=d)
  for d in [88,198]:
   for side in [-1,1]:
    for z in [-2.,2.]:self.point('info_tb_vantage',self.local(d,(side*8.5,13.25,z)),distance=d,side=side)
  for d in [236,278]:
   for side in [-1,1]:self.point('info_tb_vantage',self.local(d,(side*15.5,4.25,-4.6)),distance=d,side=side)
 def hangar(self):
  for lo,hi in [((-24,0,-8),(-23,16,20)),((23,0,-8),(24,16,20)),((-24,0,-8),(24,16,-7)),((-24,16,-8),(24,17,20))]:self.box(lo,hi,IRON)
  self.box((-24,13,18),(24,16,20),GREY)
  for side in [-1,1]:
   for x in [14.5,21.5]:self.box((side*x-1.5,0,18),(side*x+1.5,13,20),GREY)
   self.box((side*18-2,0,18),(side*18+2,1.3,20),GREY)
   self.box((side*18-2,1.6,18),(side*18+2,13,20),GREY)
  # Recess both broad faces inside the 2 m wall/pocket to avoid coplanar
  # surfaces when the gate rises into it. The 26 m opening still seals fully.
  start=len(self.brushes);self.box((-13,0,18.4),(13,13,19.6),'ind_cont2_blk1')
  self.models.append(({'classname':'func_wall','tb_gate':'1','name':'TitanHangarGate'},self.brushes[start:]));del self.brushes[start:]
  # Sky seal over the entire hangar volume; no reachable area above or behind it.
  self.box((-24,17,-8),(24,48,20),SKY)

def main():
 p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,default=Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin'));p.add_argument('--geometry-only',action='store_true');args=p.parse_args()
 OUT.mkdir(exist_ok=True);logs=ROOT/'test-results/titanball';logs.mkdir(exist_ok=True)
 a=City();a.build()
 def ent(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
 world={'classname':'worldspawn','message':a.title,'wad':'ashfall.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_minlight':'16','_sunlight':'110','_sunlight2':'48','_sun_mangle':'35 -65 0','worldtype':'0'}
 source='{\n'+ent(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'
 source+='{\n"classname" "func_detail"\n'+'\n'.join(a.detail)+'\n}\n'
 source+='\n'.join('{\n'+ent(fields)+'\n'+'\n'.join(brushes)+'\n}' for fields,brushes in a.models)+'\n'
 source+='\n'.join('{\n'+ent(e)+'\n}' for e in a.entities)+'\n'
 names=set(re.findall(r'\) (\S+) [-\d.e+]+ [-\d.e+]+ 0 [\d.e+]+ [\d.e+]+',source))
 donors,provenance=materials(names,ROOT/'tools/pressureworks/local/librequake-dev.zip')
 wad=bytearray(b'WAD2'+bytes(8));directory=[]
 for name in sorted(names):
  raw=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
 at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
 (OUT/'ashfall.wad').write_bytes(wad);(OUT/'texture-sources.json').write_text(json.dumps({n:provenance[n] for n in sorted(names)},indent=2)+'\n')
 sourcepath=OUT/(ID+'.map');sourcepath.write_text('// Original CC0 geometry. Makkon / LibreQuake texture licences retained.\n'+source)
 (OUT/'probes.json').write_text(json.dumps(a.probes,indent=2)+'\n')
 for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','CC0-1.0.txt']:shutil.copyfile(ROOT/'maps/Pressureworks'/name,OUT/name)
 bsp=ROOT/'maps'/f'{ID}.bsp'
 commands=[('qbsp',[str(sourcepath),str(bsp)]) ]
 if not args.geometry_only:commands += [('vis',['-threads','8',str(bsp)]),('light',['-threads','8','-extra4','-bspxlit','-bounce','1','-bouncecolorscale','0.20','-dirt','1','-dirtdepth','32','-dirtscale','0.5','-minlight_dirt','1',str(bsp)])]
 for exe,flags in commands:
  print(exe,flush=True)
  with (logs/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
 assert not bsp.with_suffix('.pts').exists(),'BSP leaked'
 data=bsp.read_bytes();assert struct.unpack_from('<i',data)[0]==29 and len(data)<25_000_000
 texture_at,_=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,texture_at)[0];audit=[]
 for i in range(count):
  offset=struct.unpack_from('<i',data,texture_at+4+i*4)[0]
  if offset<0:continue
  at=texture_at+offset;name=data[at:at+16].split(b'\0')[0].decode()
  if name not in donors:continue
  assert data[at:at+len(donors[name])]==donors[name],name
  audit.append({'texture':name,'unchanged':True,'sha256':hashlib.sha256(donors[name]).hexdigest()})
 (OUT/'texture-audit.json').write_text(json.dumps({'bsp_sha256':sha(bsp),'textures':audit},indent=2)+'\n')
 report={'id':ID,'title':a.title,'sha256':sha(bsp),'source_sha256':sha(sourcepath),'bytes':len(data),'structural_brushes':len(a.brushes),'detail_brushes':len(a.detail),'route_m':300,'team_spawns':[12,4],'natural_pickups':0,'universal_resupply':6,'tactical_vantages':12,'street_cover_groups':len(a.probes['cover']),'gate_thickness_m':1.2,'gate_pocket_thickness_m':2.0,'geometry_license':'CC0-1.0','textures':'texture-sources.json','lighting_complete':not args.geometry_only}
 (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
