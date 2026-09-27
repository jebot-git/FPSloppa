"""Cindercoil: original circular, ascending BSP29 Titanball map."""
from pathlib import Path
import argparse,hashlib,json,math,re,shutil,struct,subprocess,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from titanball.build import City,q,BRICK,GREY,IRON,GRATE,FLOOR,STONE,SKY
from generate_tf_maps import Arena
from pressureworks.build import materials
ID='tb_cindercoil';OUT=ROOT/'maps/Cindercoil';LOG=ROOT/'test-results/cindercoil'
COPPER='metal_copp_01';YELLOW='ind_cont1_ylw1';DARK='ind_w02_blk1'
TUNNELS=[56.,142.,234.,315.];BRIDGES=[92.,179.,248.]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def audit_textures(data,donors):
 at,_=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,at)[0];audit=[]
 for i in range(count):
  offset=struct.unpack_from('<i',data,at+4+i*4)[0]
  if offset<0:continue
  start=at+offset;name=data[start:start+16].split(b'\0')[0].decode()
  if name not in donors:continue
  assert data[start:start+len(donors[name])]==donors[name],name
  audit.append(dict(texture=name,unchanged=True,sha256=hashlib.sha256(donors[name]).hexdigest()))
 (OUT/'texture-audit.json').write_text(json.dumps(dict(bsp_sha256=hashlib.sha256(data).hexdigest(),textures=audit),indent=2)+'\n')
class Coil(City):
 def __init__(self):
  Arena.__init__(self,ID,'Cindercoil | TITANBALL');self.detail=[];self.models=[];self.route=json.loads((OUT/'route.json').read_text());self.radius=self.route['radius']
  self.probes={k:[] for k in ['spawns','stations','bridges','tunnels','cover','vantages','views']}
 def frame(self,d):
  row=self.route['samples'][min(1400,max(0,round(d*4)))];p=np.array(row['position']);f=np.array(row['forward']);right=np.array(row['right'])
  if d<0:p+=f*d
  if d>350:p+=f*(d-350)
  return p,right,f
 def local(self,d,p):
  o,x,z=self.frame(d);return tuple(o+x*p[0]+np.array([0,p[1],0])+z*p[2])
 def convex(self,vertices,faces,texture,detail=False):
  points=[np.array(p) for p in vertices];center=np.mean(points,axis=0);rows=[]
  for indices in faces:
   poly=[points[i] for i in indices];normal=np.cross(poly[1]-poly[0],poly[2]-poly[0])
   if normal.dot(np.mean(poly,axis=0)-center)<0:poly.reverse()
   rows.append(self.face([q(p) for p in poly[:3]],texture))
  (self.detail if detail else self.brushes).append('{\n'+'\n'.join(rows)+'\n}')
 def triangle(self,top,texture,bottom=-10,detail=False):
  low=[(p[0],bottom,p[2]) for p in top]
  self.convex(low+list(top),[[0,1,2],[3,4,5],[0,1,4,3],[1,2,5,4],[2,0,3,5]],texture,detail)
 def strip(self,d0,d1,x0,x1,height,texture,bottom=-10,detail=False):
  pts=[self.local(d0,(x0,height,0)),self.local(d0,(x1,height,0)),self.local(d1,(x1,height,0)),self.local(d1,(x0,height,0))]
  self.triangle([pts[0],pts[1],pts[2]],texture,bottom,detail);self.triangle([pts[0],pts[2],pts[3]],texture,bottom,detail)
 def span(self,start,end,width,texture,roof=False):
  a=np.array(start);b=np.array(end);delta=b-a;side=np.array([delta[2],0,-delta[0]]);side=side/np.linalg.norm(side)*width/2
  top=[a-side,a+side,b+side,b-side]
  if roof:
   low=top;high=[p+np.array([0,.6,0]) for p in low]
   self.convex(low+high,[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],texture)
  else:
   self.triangle([top[0],top[1],top[2]],texture);self.triangle([top[0],top[2],top[3]],texture)
 def markers(self):
  for stage,d in enumerate([0.,72.,222.]):self.spawn_group_coil(d,0,stage)
  self.spawn_group_coil(350.,1,0)
  for d,x,z in [(0.,14,-1),(70.,16,0),(104.,-9.5,0),(215.,16,0),(246.,-9.5,0),(348.,-15,0)]:
   # Use the actual curved road surface under each offset point.
   p=self.grounded(d,x,z);self.point('info_tb_resupply',p,distance=d);self.probes['stations'].append(dict(distance=d,position=p))
  for i,p in enumerate(self.route['points']):self.point('info_tb_route',p,order=i)
  for i,d in enumerate([80.,230.]):
   self.point('info_tb_checkpoint',self.local(d,(0,0,0)),stage=i+1,distance=d)
   for side in [-1,1]:self.box((side*12.4-.22,-.6,-.22),(side*12.4+.22,13.0,.22),YELLOW,d)
   self.box((-12.62,13,-.22),(12.62,13.4,.22),YELLOW,d)
  self.point('info_tb_goal',self.local(350,(0,0,0)))
  for d in BRIDGES:
   for side in [-1,1]:
    for z in [-2,2]:
     p=self.local(d,(side*8.5,13.25,z));self.point('info_tb_vantage',p,distance=d,side=side);self.probes['vantages'].append(dict(position=p,distance=d))
  for d in [286.,326.]:
   for side in [-1,1]:
    p=self.local(d,(side*17,4.25,0));self.point('info_tb_vantage',p,distance=d,side=side);self.probes['vantages'].append(dict(position=p,distance=d))
  self.point('info_player_start',self.local(0,(0,.05,0)),angle=180)
  self.point('info_player_deathmatch',self.local(0,(0,.05,4)),angle=180)
 def grounded(self,d,x,z):
  p=np.array(self.local(d,(x,.05,z)));rows=self.route['samples'];near=min(rows,key=lambda r:(r['position'][0]-p[0])**2+(r['position'][2]-p[2])**2);p[1]=near['position'][1]+.05;return tuple(p)
 def spawn_group_coil(self,d,team,stage):
  _,_,f=self.frame(d);yaw=math.degrees(math.atan2(f[0],f[2]))+(180 if team==0 else 0)
  for side in [-1,1]:
   for z in [-1.,1.]:
    p=self.grounded(d,side*17,z);self.point('info_tb_spawn',p,team=team,stage=stage,angle=yaw);self.probes['spawns'].append(dict(position=p,team=team,stage=stage,distance=d))
   # Protected lateral exits remain outside the robot sweep.
   self.box((side*17-2,-.5,3),(side*17+2,2.8,3.6),'ind_dp01_red1' if team==0 else 'ind_dp01_blu1',d)
   self.box((side*17-2.4,3.1,-3),(side*17+2.4,3.5,3.6),IRON,d)
 def tower(self,d,side):
  x=side*17
  for flight in range(4):
   forward=flight%2==0;lane=x+side*(-1.6 if forward else 1.6)
   self.ramp(d,lane,-6 if forward else 6,6 if forward else -6,-.5 if flight==0 else flight*3.3,(flight+1)*3.3,2.6)
   zend=6 if forward else -8
   self.box((x-3.0,(flight+1)*3.3-.25,zend),(x+3.,(flight+1)*3.3,zend+2),STONE,d,True)
  # The outer flight must stay open overhead until its top landing.
  self.box((min(side*12.5,x),12.95,-6),(max(side*12.5,x),13.2,3),IRON,d,True)
  for z in [-8,7.5]:
   # Copper portal is open through the switchbacks, framed rather than solid.
   for dx in [-3.35,3.35]:self.box((x+dx-.18,-.7,z),(x+dx+.18,16.,z+.35),COPPER,d,True)
   self.box((x-3.5,15.4,z),(x+3.5,16.,z+.35),COPPER,d,True)
  self.box((x-3.6,16,-8),(x+3.6,16.6,8),IRON,d,True)
  self.light(self.local(d,(x,14.8,0)),250,'.56 .75 1')
  self.probes['bridges'].append(dict(distance=d,side=side,bottom=self.grounded(d,x-side*1.6,-6.6),top=self.local(d,(side*8.5,13.25,0)),steps=[self.local(d,(x-side*1.6,-.45,-6)),self.local(d,(x-side*1.6,3.35,6.8)),self.local(d,(x+side*1.6,3.35,6.8)),self.local(d,(x+side*1.6,6.65,-6.8)),self.local(d,(x-side*1.6,6.65,-6.8)),self.local(d,(x-side*1.6,9.95,6.8)),self.local(d,(x+side*1.6,9.95,6.8)),self.local(d,(x+side*1.6,13.25,-6.8)),self.local(d,(x-side*1.6,13.25,-6.8)),self.local(d,(x-side*1.6,13.25,-4)),self.local(d,(side*8.5,13.25,0))]))
 def core(self):
  center=np.array([self.radius,7,0]);links=[]
  for d in TUNNELS:
   start=np.array(self.local(d,(23,0,0)));direction=start-center;direction[1]=0;direction/=np.linalg.norm(direction);end=center+direction*8
   # Reach the hall's level before its square deck begins, without a lip.
   landing=center+direction*20
   links.extend([(d,start,landing),(d,landing,end)])
   # Extend under the raster-carved walls, leaving no gutters beside the path.
   self.span(start,landing,14,STONE);self.span(landing,end,14,STONE)
   self.probes['tunnels'].append(dict(distance=d,entry=list(start+np.array([0,.05,0])),hub=list(end+np.array([0,.05,0]))))
   self.light((start+end)/2+np.array([0,3,0]),290,'1 .70 .40')
   # Portal lintel, with warm inset lamps at either side.
   self.box((22,4.4,-4),(25,5.1,4),IRON,d)
   for z in [-4.6,4.6]:self.box((23.5,0,z-.25),(24.5,5.1,z+.25),GREY,d)
  # Structural core carved around four connected sloping tunnels and a rotunda.
  # Generous grid clearance surrounds the exact continuous brush floors.
  groups={};r=self.radius-25
  for x in range(math.floor(self.radius-r),math.ceil(self.radius+r),2):
   for z in range(math.floor(-r),math.ceil(r),2):
    p=np.array([x+1,0,z+1]);rad=math.hypot(p[0]-self.radius,p[2])
    if rad>r+2:continue
    openings=[]
    if rad<12.5:openings.append(14.0)
    for d,a,b in links:
     delta=b-a;flat=delta.copy();flat[1]=0;t=np.clip((p-a).dot(flat)/flat.dot(flat),0,1);closest=a+delta*t
     if math.hypot(p[0]-closest[0],p[2]-closest[2])<4.9:openings.append(closest[1]+4.8)
    bottom=math.ceil(max(openings)*4)/4 if openings else -10
    groups.setdefault((bottom,36),set()).add((x,z))
  for (bottom,top),cells in groups.items():
   while cells:
    x,z=min(cells);w=2
    while (x+w,z) in cells:w+=2
    h=2
    while all((xx,z+h) in cells for xx in range(x,x+w,2)):h+=2
    for xx in range(x,x+w,2):
     for zz in range(z,z+h,2):cells.remove((xx,zz))
    self.box((x,bottom,z),(x+w,top,z+h),GREY)
  # Rotunda walking deck and a central pressure vessel, with room to circle it.
  self.box((self.radius-14,-10,-14),(self.radius+14,7,14),FLOOR)
  for i in range(8):
   a=i*math.tau/8;b=(i+1)*math.tau/8
   top=[(self.radius,13,0),(self.radius+3*math.cos(a),13,3*math.sin(a)),(self.radius+3*math.cos(b),13,3*math.sin(b))]
   self.triangle(top,COPPER,7,True)
  self.light(center+np.array([0,6.5,0]),550,'.6 .85 1')
 def hangar_coil(self):
  d=0
  for lo,hi in [((-24,0,-10),(-23,16,20)),((23,0,-10),(24,16,20)),((-24,0,-10),(24,16,-9)),((-24,16,-10),(24,17,20))]:self.box(lo,hi,IRON,d)
  self.box((-24,13,18),(24,16,20),GREY,d)
  for side in [-1,1]:
   for x in [14.5,21.5]:self.box((side*x-1.5,0,18),(side*x+1.5,13,20),GREY,d)
   self.box((side*18-2,0,18),(side*18+2,1.3,20),GREY,d);self.box((side*18-2,1.6,18),(side*18+2,13,20),GREY,d)
  at=len(self.brushes);self.box((-13,0,18.4),(13,13,19.6),'ind_cont2_blk1',d)
  self.models.append(({'classname':'func_wall','tb_gate':'1','name':'TitanHangarGate'},self.brushes[at:]));del self.brushes[at:]
  self.light(self.local(0,(0,12,0)),650,'1 .64 .35')
 def build(self):
  # Exact sampled route is measured in 3D metres by the game's Curve3D code.
  edges=sorted(set([-12,0,24,338,350,362]+list(range(0,351,4))))
  for a,b in zip(edges,edges[1:]):
   for x,X,t in [(-24,-13,STONE),(-13,13,FLOOR),(13,24,STONE)]:self.strip(a,b,x,X,0,t,detail=True)
   if a<20:continue
   self.strip(a,b,-26,-24,22,BRICK)
   if not any(abs((a+b)/2-d)<8 for d in TUNNELS):self.strip(a,b,24,26,26,GREY)
   else:self.strip(a,b,24,26,6.2,IRON,bottom=max(self.frame(a)[0][1],self.frame(b)[0][1])+4.8)
  # Sky hull is outside every accessible lane; route-side architecture closes it.
  self.box((-40,-14,-112),(192,-10,112),GREY);self.box((-40,64,-112),(192,66,112),SKY)
  for lo,hi in [((-42,-14,-114),(-40,66,114)),((192,-14,-114),(194,66,114)),((-40,-14,-114),(192,66,-112)),((-40,-14,112),(192,66,114))]:self.box(lo,hi,SKY)
  self.core();self.hangar_coil()
  for d in BRIDGES:
   self.box((-14,12.5,-3),(14,13.2,3),IRON,d)
   for z in [-3,2.7]:self.box((-13.5,13.2,z),(13.5,14.2,z+.3),GRATE,d,True)
   for side in [-1,1]:self.tower(d,side)
  for d in [286.,326.]:
   for side in [-1,1]:
    x=side*17;self.box((x-2,3.8,-4),(x+2,4.2,4),IRON,d,True)
    self.ramp(d,x,-16,-4,-.8,4.2,3.6);self.ramp(d,x,4,16,4.2,.8,3.6)
    self.box((x+side*1.8-.15,4.2,-4),(x+side*1.8+.15,5.5,4),GREY,d,True)
  for d in range(32,337,16):
   for side in [-1,1]:
    x=side*24
    for y in [8,13,18]:
     self.box((x-.18,y,-3),(x+.18,y+2,3),DARK,d,True);self.box((x-.4,y+2,-3.2),(x+.4,y+2.3,3.2),COPPER,d,True)
   self.light(self.local(d,(0,12,0)),420,'.65 .78 1')
  for i,d in enumerate(range(36,335,18)):
   side=-1 if i%2 else 1;x=side*9.8
   self.prop_box(d,(x,.55,0),(2.2,1.3,4),GREY,(-1 if i%2 else 1)*12)
   self.prop_box(d,(x,1.32,0),(2.3,.25,4.1),YELLOW)
   self.probes['cover'].append(dict(distance=d,position=self.local(d,(x,.55,0))))
  # Defender reinforcement bunker caps the raised end of the road.
  for lo,hi in [((-24,0,8),(24,15,9)),((-24,0,-10),(-23,15,9)),((23,0,-10),(24,15,9)),((-24,15,-10),(24,16,9))]:self.box(lo,hi,GREY,350)
  for side in [-1,1]:self.box((side*17-3,0,-10),(side*17+3,9,-9),'ind_dp01_blu1',350)
  self.light(self.local(350,(0,12,0)),550,'.55 .72 1')
  self.markers()
  self.probes['views']=[dict(name='road-ascent',eye=self.local(62,(8,2,-5)),look=self.local(100,(0,8,0))),dict(name='checkpoint-two',eye=self.local(208,(-10,2,0)),look=self.local(242,(0,9,0))),dict(name='central-tunnels',eye=(self.radius+8,9,-7),look=(self.radius-5,9,5)),dict(name='defender-base',eye=self.local(316,(7,3,0)),look=self.local(350,(0,8,0))),dict(name='overpass',eye=self.local(179,(-8,15,1)),look=self.local(215,(0,4,0)))]

def main():
 p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--geometry-only',action='store_true');p.add_argument('--fast-vis',action='store_true');args=p.parse_args()
 OUT.mkdir(exist_ok=True);LOG.mkdir(exist_ok=True);a=Coil();a.build()
 def fields(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
 world={'classname':'worldspawn','message':a.title,'wad':'cindercoil.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_minlight':'24','_sunlight':'130','_sunlight2':'50','_sun_mangle':'35 -65 0','worldtype':'0'}
 source='{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(a.detail)+'\n}\n'
 source+='\n'.join('{\n'+fields(e)+'\n'+'\n'.join(b)+'\n}' for e,b in a.models)+'\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n'
 names=set(re.findall(r'\) (\S+) [-\d.e+]+ [-\d.e+]+ 0 [\d.e+]+ [\d.e+]+',source));donors,provenance=materials(names,ROOT/'tools/pressureworks/local/librequake-dev.zip')
 wad=bytearray(b'WAD2'+bytes(8));directory=[]
 for name in sorted(names):
  raw=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
 at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(OUT/'cindercoil.wad').write_bytes(wad)
 (OUT/'texture-sources.json').write_text(json.dumps({n:provenance[n] for n in sorted(names)},indent=2)+'\n')
 sourcepath=OUT/(ID+'.map');sourcepath.write_text(source);(OUT/'probes.json').write_text(json.dumps(a.probes,indent=2)+'\n')
 for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','CC0-1.0.txt']:shutil.copyfile(ROOT/'maps/Pressureworks'/name,OUT/name)
 bsp=ROOT/'maps'/f'{ID}.bsp';bsp.with_suffix('.pts').unlink(missing_ok=True)
 # Godot builds collision from BSP draw geometry, not GoldSrc/Quake clip hulls.
 # Omitting the unused expanded hulls avoids legacy sloped-brush precision leaks.
 commands=[('qbsp',['-noclip','-wadpath',str(OUT),str(sourcepath),str(bsp)])]
 if not args.geometry_only:commands += [('vis',['-threads','4',*(['-fast'] if args.fast_vis else []),str(bsp)]),('light',['-threads','4','-extra','-bspxlit','-bounce','1','-dirt','1',str(bsp)])]
 for exe,flags in commands:
  print(exe,flush=True)
  with (LOG/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
 assert not bsp.with_suffix('.pts').exists(),'BSP leak';raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
 assert "Couldn't create brush faces" not in (LOG/'qbsp.log').read_text()
 audit_textures(raw,donors)
 report=dict(id=ID,title=a.title,sha256=sha(bsp),source_sha256=sha(sourcepath),bytes=len(raw),route_m=a.route['length'],rise_m=14,structural_brushes=len(a.brushes),detail_brushes=len(a.detail),checkpoints=[80,230],attacker_stages=[0,72,222],defender_base=350,team_spawns=[12,4],shared_resupply=6,overpasses=3,towers=6,connecting_tunnels=4,natural_pickups=0,full_vis=not args.fast_vis and not args.geometry_only,geometry_license='CC0-1.0',textures='texture-sources.json')
 (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 catalog=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(catalog.read_text());rows=[r for r in rows if r['id']!=ID];rows.append(dict(id=ID,title=a.title,path=f'res://maps/{ID}.bsp',scene=f'res://maps/cache/{ID}.scn',sha256=report['sha256'],size=len(raw),modes=['tb'],distribution='base'));catalog.write_text(json.dumps(rows,indent=2)+'\n')
 print(json.dumps(report,indent=2))
if __name__=='__main__':main()
