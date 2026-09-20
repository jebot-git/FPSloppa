"""Sixteen authored street plans with deterministic, asymmetric urban infill."""
import math, random
from city import City, THEMES, IRON, STONE
# Routes are deliberately authored individually, not rotated copies of one layout.
# The four outer approaches and central capture plaza are the shared constraints.
PLANS=[
 ('Pilgrim crescent', [(-125,0),(-95,0),(-69,-23),(-35,-18),(0,0),(44,24),(88,0),(125,0)], [(0,-125),(0,-98),(24,-62),(14,-28),(0,0),(-31,37),(-20,76),(0,102),(0,125)], [[(-69,-23),(-77,39),(-54,73),(-20,76)]]),
 ('Arcology switchback', [(-125,0),(-99,0),(-77,34),(-35,37),(0,0),(41,-33),(80,-34),(101,0),(125,0)], [(0,-125),(0,-102),(-30,-73),(-35,-30),(0,0),(20,43),(38,84),(0,105),(0,125)], [[(-77,34),(-77,82),(-22,95),(20,43)],[(41,-33),(49,-77),(-30,-73)]]),
 ('Crucible service loop', [(-125,0),(-88,0),(-59,-34),(-17,-34),(0,0),(61,0),(97,0),(125,0)], [(0,-125),(0,-91),(35,-61),(38,-25),(0,0),(-39,35),(-39,88),(0,104),(0,125)], [[(-59,-34),(-62,-79),(0,-91)],[(61,0),(79,60),(40,84),(-39,88)]]),
 ('Astral terraces', [(-125,0),(-99,0),(-78,-38),(-37,-49),(0,0),(34,42),(79,35),(105,0),(125,0)], [(0,-125),(0,-99),(31,-76),(38,-35),(0,0),(-38,42),(-25,85),(0,106),(0,125)], [[(-78,-38),(-94,31),(-38,42)],[(31,-76),(80,-64),(79,35)]]),
 ('Archive lanes', [(-125,0),(-97,0),(-75,22),(-39,22),(0,0),(43,-20),(91,-20),(109,0),(125,0)], [(0,-125),(0,-99),(-29,-79),(-29,-39),(0,0),(34,31),(34,87),(0,103),(0,125)], [[(-75,22),(-76,77),(34,87)],[(43,-20),(53,-77),(-29,-79)]]),
 ('Data spine', [(-125,0),(-101,0),(-75,-45),(-28,-45),(0,0),(47,31),(83,31),(106,0),(125,0)], [(0,-125),(0,-103),(27,-79),(27,-43),(0,0),(-27,43),(-48,84),(0,109),(0,125)], [[(-75,-45),(-78,33),(-27,43)],[(47,31),(61,83),(-48,84)]]),
 ('Transit interchange', [(-125,0),(-94,0),(-61,0),(-29,0),(0,0),(39,-31),(85,-31),(105,0),(125,0)], [(0,-125),(0,-101),(-46,-65),(-61,0),(-34,43),(-34,86),(0,106),(0,125)], [[(0,0),(38,46),(85,72),(85,-31)],[(-46,-65),(37,-78),(39,-31)]]),
 ('Hospital precinct', [(-125,0),(-99,0),(-78,-28),(-34,-28),(0,0),(45,20),(91,20),(109,0),(125,0)], [(0,-125),(0,-96),(39,-62),(30,-28),(0,0),(-24,37),(-61,74),(0,105),(0,125)], [[(-78,-28),(-87,-76),(0,-96)],[(45,20),(63,71),(-24,37)]]),
 ('Condenser doglegs', [(-125,0),(-101,0),(-82,36),(-39,36),(0,0),(35,-44),(83,-44),(107,0),(125,0)], [(0,-125),(0,-101),(-36,-70),(-39,-29),(0,0),(36,35),(24,88),(0,106),(0,125)], [[(-82,36),(-71,86),(24,88)],[(-36,-70),(39,-89),(35,-44)]]),
 ('Market web', [(-125,0),(-100,0),(-75,-30),(-30,-34),(0,0),(37,32),(77,47),(104,0),(125,0)], [(0,-125),(0,-102),(36,-75),(37,-32),(0,0),(-34,39),(-37,84),(0,106),(0,125)], [[(-75,-30),(-85,34),(-37,84)],[(36,-75),(85,-63),(77,47)],[(-34,39),(37,32)]]),
 ('Cipher diagonal courts', [(-125,0),(-99,0),(-70,37),(-29,32),(0,0),(40,-31),(85,-65),(105,0),(125,0)], [(0,-125),(0,-101),(-39,-68),(-30,-32),(0,0),(35,40),(46,83),(0,106),(0,125)], [[(-70,37),(-60,87),(46,83)],[(-39,-68),(-86,-58),(-99,0)]]),
 ('Bastion chicanes', [(-125,0),(-100,0),(-80,-35),(-42,-35),(0,0),(42,35),(82,35),(105,0),(125,0)], [(0,-125),(0,-101),(43,-71),(42,-35),(0,0),(-37,40),(-37,80),(0,106),(0,125)], [[(-80,-35),(-73,-87),(43,-71)],[(82,35),(80,86),(-37,80)]]),
 ('Cloister garden walk', [(-125,0),(-97,0),(-73,39),(-34,36),(0,0),(33,-31),(73,-48),(101,0),(125,0)], [(0,-125),(0,-101),(-31,-74),(-41,-34),(0,0),(26,43),(51,84),(0,106),(0,125)], [[(-73,39),(-75,88),(-22,94),(26,43)],[(73,-48),(87,32),(26,43)]]),
 ('Reactor freight circuit', [(-125,0),(-102,0),(-83,-40),(-36,-40),(0,0),(47,0),(89,0),(125,0)], [(0,-125),(0,-102),(40,-76),(47,-36),(0,0),(-27,42),(-27,88),(0,105),(0,125)], [[(-83,-40),(-89,45),(-27,88)],[(47,0),(81,51),(58,87),(-27,88)]]),
 ('Dockside quays', [(-125,0),(-99,0),(-75,27),(-32,27),(0,0),(39,-28),(85,-28),(106,0),(125,0)], [(0,-125),(0,-102),(-42,-75),(-42,-30),(0,0),(32,39),(76,73),(0,108),(0,125)], [[(-75,27),(-82,86),(76,73)],[(-42,-75),(49,-83),(85,-28)]]),
 ('Necropolis processional', [(-125,0),(-101,0),(-74,-28),(-38,-41),(0,0),(33,39),(75,35),(105,0),(125,0)], [(0,-125),(0,-101),(38,-77),(34,-34),(0,0),(-38,33),(-52,78),(0,106),(0,125)], [[(-74,-28),(-86,39),(-52,78)],[(38,-77),(88,-62),(75,35)]]),
]
def distance(p,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
class District(City):
 def __init__(self,zone):
  super().__init__();self.zone=zone;self.rng=random.Random(29000+zone*173);self.rooms=[];self.routes=[];self.street_points=[];self.lots=[];self.props=[];self.signs=[];self.pickup_positions=[[-7,.3,0],[7,.3,0],[],[],[],[],[-10,.3,10],[10,.3,-10]]
  self.plan_name,ew,ns,extra=PLANS[zone];self.streets=[ew,ns]+extra
 def prism(self,points,y0,y1,tex):
  n=len(points);pts=[(x,y,z) for y in [y0,y1] for x,z in points]
  self.hull(pts,[list(range(n)),list(range(n,2*n))]+[[i,(i+1)%n,(i+1)%n+n] for i in range(n)],tex)
  if self.structural:self.brushes.append(self.detail.pop())
 def segment(self,a,b,width,y0,y1,tex):
  dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);nx,nz=-dz/length*width/2,dx/length*width/2
  self.prism([(a[0]+nx,a[1]+nz),(b[0]+nx,b[1]+nz),(b[0]-nx,b[1]-nz),(a[0]-nx,a[1]-nz)],y0,y1,tex)
 def road_distance(self,p):return min(distance(p,a,b) for road in self.streets for a,b in zip(road,road[1:]))
 def free(self,x,z,w,d,pad=0):
  if abs(x)+w+pad>120 or abs(z)+d+pad>120:return False
  if math.hypot(max(0,abs(x)-w-pad),max(0,abs(z)-d-pad))<33:return False
  for xx,zz,ww,dd,*_ in self.lots:
   if abs(x-xx)<w+ww+pad+3 and abs(z-zz)<d+dd+pad+3:return False
  return True
 def choose_lots(self):
  # Setbacks follow the actual streets; buildings leave irregular connected alleys.
  for attempt in range(1700):
   if len(self.lots)>=16+(self.zone%5):break
   large=sum(row[4] for row in self.lots)<4
   w=self.rng.randint(12,17) if large else self.rng.randint(5,12)
   d=self.rng.randint(15,19) if large else self.rng.randint(7,15)
   x=self.rng.randint(-104,104);z=self.rng.randint(-104,104)
   if not self.free(x,z,w,d,2):continue
   samples=[(x+sx*w,z+sz*d) for sx in [-1,0,1] for sz in [-1,0,1]]
   if min(self.road_distance(p) for p in samples)<14:continue
   if any(abs(a[0]-x)<w+14 and abs(a[1]-z)<d+14 for road in self.streets for a in road):continue
   self.lots.append((x,z,w,d,large))
  assert sum(row[4] for row in self.lots)>=3,(self.zone,self.lots)
 def street(self,points):
  for a,b in zip(points,points[1:]):
   # Raised footways flank the lower asphalt carriageway.
   self.segment(a,b,17,-.02,.04,'ind_dp01_blk1')
   road_length=math.dist(a,b);nx=-(b[1]-a[1])/road_length;nz=(b[0]-a[0])/road_length
   for side in [-1,1]:
    aa=(a[0]+nx*side*10.25,a[1]+nz*side*10.25);bb=(b[0]+nx*side*10.25,b[1]+nz*side*10.25)
    self.segment(aa,bb,3.5,-.02,.18,'med_cobstn2_1a')
   length=math.dist(a,b);dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
   for j in range(max(1,int(length/24))):
    t=(j+.5)/max(1,int(length/24));x=a[0]+dx*length*t;z=a[1]+dz*length*t
    if math.hypot(x,z)<33 or max(abs(x),abs(z))>110:continue
    side=1 if (j+self.zone)%2 else -1
    px=x-dz*side*10.5;pz=z+dx*side*10.5
    self.lamp(px,pz,dx,dz)
    if self.rng.random()<.6:self.vehicle(x+dz*side*5.7,z-dx*side*5.7,math.atan2(dz,dx),self.rng.random()<.3)
   self.street_points.append([max(-121,min(121,a[0])),.3,max(-121,min(121,a[1]))])
  for x,z in points[1:-1]:
   # Flush crossing aprons keep intersecting sidewalks accessible.
   self.cylinder(x,z,-.02,12,.06,'med_cobstn2_1a',12);self.cylinder(x,z,.04,8.5,.01,'ind_dp01_blk1',12)
   if math.hypot(x,z)>33:self.light((x,4,z),2500,(.7,.8,1),'junction_fill')
 def lamp(self,x,z,dx,dz):
  tint=THEMES[self.zone][2];self.block((x-.28,.14,z-.28),(x+.28,7.6,z+.28),IRON)
  self.block((x-.65,.14,z-.65),(x+.65,.7,z+.65),STONE)
  self.block((x-1.4,7.5,z-.5),(x+1.4,8,z+.5),IRON)
  self.glow(self.zone,(x,7.48,z),(2.5,.12,.8),tint);self.light((x,7.2,z),8000,(.75,.82,1),'streetlamp');self.props.append({'kind':'streetlamp','position':[x,0,z]})
 def vehicle(self,x,z,angle,truck):
  w=4.6 if truck else 3.2;d=1.25;c,s=math.cos(angle),math.sin(angle)
  def box(a,b,tex):
   p=[(x+xx*c-zz*s,z+xx*s+zz*c) for xx,zz in [(a[0],a[2]),(b[0],a[2]),(b[0],b[2]),(a[0],b[2])]];self.prism(p,a[1]+.04,b[1]+.04,tex)
  tex=['ind_cont2_prpl1','ind_cont1_ylw1','ind_cont2_blk1','ind_w01_red1'][self.rng.randrange(4)]
  box((-w,.45,-d),(w,1.25,d),tex);box((-w*.45,1.25,-d*.85),(w*.55,2.35,d*.85),'tech02_7')
  if truck:box((-w,.9,-d),(0,3.1,d),'ind_cont1_ylw1')
  for xx in [-w*.65,w*.65]:
   for zz in [-d,d]:box((xx-.55,0,zz-.18),(xx+.55,.95,zz+.18),IRON)
  for zz in [-.8,.8]:
   px=x+w*c-zz*s;pz=z+w*s+zz*c;self.glow(self.zone,(px,.95,pz),(.24,.3,.24),'d4efff')
  self.props.append({'kind':'freight_vehicle' if truck else 'parked_vehicle','position':[x,0,z]})
 def room(self,lot,index):
  x,z,w,d,_=lot;zone=self.zone;name,style,tint,wall,trim=THEMES[zone]
  levels=[0,6,12]+([18] if (index+zone)%3==0 else []);height=levels[-1]+4.8
  self.rooms.append({'center':[x,0,z],'levels':levels,'half_size':[w,d],'style':style,'points':[[x,y+.1,z-d+2.5] for y in levels]})
  self.structural=True
  # Doors connect each hall to the surrounding alley network, not mirrored forecourts.
  for side in [-1,1]:
   for a,b in [(-w,-3),(3,w)]:self.block((x+a,0,z+side*d-.4),(x+b,height,z+side*d+.4),wall)
   for y in levels:self.block((x-3,y+4.3,z+side*d-.4),(x+3,min(y+6,height),z+side*d+.4),wall)
   self.block((x+side*w-.4,0,z-d),(x+side*w+.4,height,z+d),wall)
  self.structural=False
  for k,y in enumerate(levels[1:]):
   # Street-facing balconies connect through upper doorways.
   self.block((x-w,y-.35,z-d-3),(x+w,y,z-d),trim)
   for a,b in [(-w,-3),(3,w)]:self.block((x+a,y,z-d-3),(x+b,y+1,z-d-2.8),IRON)
   # Perimeter floor, with alternating open ramp flights along the side walls.
   for side in [-1,1]:self.block((x-w,y-.35,z+side*(d-2)-2),(x+w,y,z+side*(d-2)+2),trim)
   open_side=-1 if k%2==0 else 1
   self.block((x-open_side*(w-3.5)-3.5,y-.35,z-d+4),(x-open_side*(w-3.5)+3.5,y,z+d-4),trim)
   self.block((x+open_side*(w-5.75)-1.25,y-.35,z-d+4),(x+open_side*(w-5.75)+1.25,y,z+d-4),trim)
   low,high=(-d+4,d-4) if k%2==0 else (d-4,-d+4)
   rx=x+open_side*(w-2.5);self.hull([(rx-2,y-6,z+low),(rx+2,y-6,z+low),(rx-2,y-6,z+high),(rx+2,y-6,z+high),(rx-2,y,z+high),(rx+2,y,z+high)],[[0,2,3],[2,4,5],[0,1,5],[0,4,2],[1,3,5]],'metal_iron1_07')
   self.routes.append({'from':[rx,y-5.9,z+low+(-1.5 if low<high else 1.5)],'to':[rx,y+.1,z+high+(1.5 if low<high else -1.5)],'kind':'interior_ramp'})
   self.block((x-w+7,y,z-d+3.8),(x-3,y+1,z-d+4.1),IRON);self.block((x+3,y,z-d+3.8),(x+w-7,y+1,z-d+4.1),IRON)
  self.block((x-w-.8,height,z-d-.8),(x+w+.8,height+.5,z+d+.8),trim)
  for y in levels:
   self.light((x,y+3,z),1150,(.65,.75,1),'hall');self.glow(zone,(x,y+3.8,z),(6,.15,.4),tint)
   for side in [-1,1]:
    self.block((x+side*(w-6)-1,y,z+d-2),(x+side*(w-6)+1,y+1.3,z+d-.8),'comp1_1')
  self.facade(x,z,w,d,height,index)
  if style in ['cathedral','garden']:
   self.spire(x+w*.35,z,height+.5,min(w,d)*.7,12,trim)
  elif style in ['foundry','reactor']:
   self.cylinder(x-w*.3,z,height+.5,3,11,trim);self.glow(zone,(x-w*.3,height+12,z),(5,.3,5),tint,'ring')
  elif style in ['data','observatory']:
   self.glow(zone,(x,height+6,z),(9,9,9),tint,'orbital' if style=='observatory' else 'data')
  self.signs.append({'position':[x,3.7,z-d-.6],'yaw':math.pi,'text':name.upper()+' / '+str(index+1)})
  self.pickup_positions[2+index%4]=[x,levels[1]+.1,z-d+2.5]
 def facade(self,x,z,w,d,h,index):
  _,style,tint,wall,trim=THEMES[self.zone]
  for y in range(5,int(h),6):
   if index%3==2:
    for side in [-1,1]:self.block((x-w-.25,y,z+side*d-.25),(x+w+.25,y+.25,z+side*d+.25),trim)
   for side in [-1,1]:
    for xx in range(-int(w)+3,int(w)-1,5):
     self.glow(self.zone,(x+xx,y-1.8,z+side*(d+.46)),(2,2.6,.08),tint,'window',gothic=style in ['cathedral','garden'])
    self.light((x,y-1,z+side*(d+2)),1800,(.55,.66,.9),'facade')
  for xx in [-w,w]:
   self.block((x+xx-.3,0,z-d-.7),(x+xx+.3,h+1,z-d+.2),trim)
   if style in ['cathedral','garden']:self.spire(x+xx,z-d,h+1,.8,4,trim)
 def infill(self,lot,index):
  x,z,w,d,_=lot;name,style,tint,wall,trim=THEMES[self.zone];h=self.rng.choice([6,9,14,20,27,35])
  # Narrow shops, setback towers and arcaded corner blocks have distinct silhouettes.
  self.structural=True
  if index%4==1:
   for a,b in [(-w,-3),(3,w)]:self.block((x+a,0,z-d),(x+b,h,z+d),wall,True)
   self.block((x-3,4.5,z-d),(x+3,h,z+d),wall,True)
   self.street_points.append([x,.1,z]);self.props.append({'kind':'covered_passage','position':[x,0,z]})
   self.light((x,3.6,z),900,(.75,.8,1),'passage')
  else:self.block((x-w,0,z-d),(x+w,h,z+d),wall,True)
  self.structural=False
  if index%3==0:self.block((x-w*.7,h,z-d*.5),(x+w*.25,h+9,z+d*.6),trim)
  if index%3==1:self.spire(x,z,h,min(w,d)*.8,8,trim)
  self.facade(x,z,w,d,h,index)
  self.block((x-w-1,3.7,z-d-3.5),(x+w+1,4.1,z-d),trim)
  for xx in [-w+.5,w-.5]:self.block((x+xx-.15,0,z-d-3),(x+xx+.15,3.7,z-d-2.7),IRON)
  self.glow(self.zone,(x,3.4,z-d-3.55),(min(6,w*1.5),.4,.1),tint)
 def stall(self,x,z,index):
  _,style,tint,wall,trim=THEMES[self.zone]
  self.block((x-2.8,0,z-1.3),(x+2.8,1.2,z+1.3),'med_wood6')
  for sx in [-1,1]:
   for sz in [-1,1]:self.block((x+sx*3-.12,0,z+sz*2-.12),(x+sx*3+.12,3.4,z+sz*2+.12),IRON)
  self.prism([(x-3.5,z-2.5),(x+3.5,z-2.5),(x+3.5,z+2.5),(x-3.5,z+2.5)],3.4,3.65,trim)
  for j in range(4):self.block((x-2+j,1.2,z-.6),(x-1.4+j,1.7,z+.6),['crate0_side','comp1_2','med_wood6'][index%3])
  self.glow(self.zone,(x,3.1,z-2.51),(4,.18,.1),tint);self.light((x,2.8,z-3),450,(1,.7,.4),'stall');self.props.append({'kind':'market_stall','position':[x,0,z]})
 def skyways(self):
  candidates=[]
  for i,a in enumerate(self.rooms):
   for b in self.rooms[i+1:]:
    x,z=a['center'][0],a['center'][2]-a['half_size'][1]-1.5
    xx,zz=b['center'][0],b['center'][2]-b['half_size'][1]-1.5
    low=min(z,zz)-6;points=[(x,z),(x,low),(xx,low),(xx,zz)]
    if abs(low)>119 or abs(x-xx)<7:continue
    clear=True
    for start,end in zip(points,points[1:]):
     for k in range(int(math.dist(start,end))+1):
      t=k/max(1,int(math.dist(start,end)));px=start[0]+(end[0]-start[0])*t;pz=start[1]+(end[1]-start[1])*t
      if any(abs(px-lx)<w+1.6 and abs(pz-lz)<d+.8 for lx,lz,w,d,_ in self.lots):clear=False;break
     if not clear:break
    if clear:candidates.append((sum(math.dist(a,b) for a,b in zip(points,points[1:])),points))
  if not candidates:return
  _,points=min(candidates)
  for a,b in zip(points,points[1:]):
   self.segment(a,b,3.5,5.65,6,THEMES[self.zone][4]);self.light(((a[0]+b[0])/2,8,(a[1]+b[1])/2),700,(.6,.75,1),'skyway')
   for step in range(1,max(2,int(math.dist(a,b)/18))):
    t=step/max(2,int(math.dist(a,b)/18));x=a[0]+(b[0]-a[0])*t;z=a[1]+(b[1]-a[1])*t
    if self.road_distance((x,z))>13 and math.hypot(x,z)>25:self.block((x-.35,0,z-.35),(x+.35,5.65,z+.35),IRON)
  for x,z in points:self.street_points.append([x,6.1,z])
  self.props.append({'kind':'skyway','points':points,'position':[points[0][0],6,points[0][1]]})
 def landmarks(self):
  style=THEMES[self.zone][1];tint=THEMES[self.zone][2]
  count=0
  for _ in range(250):
   x=self.rng.randint(-111,111);z=self.rng.randint(-111,111)
   if not self.free(x,z,5,5,1) or self.road_distance((x,z))<17:continue
   if any(math.dist((x,z),(p['position'][0],p['position'][2]))<12 for p in self.props):continue
   if style in ['garden','arcology']:
    self.block((x-3,0,z-3),(x+3,.8,z+3),STONE);self.glow(self.zone,(x,2,z),(6,4,6),tint,'garden')
   elif style in ['cathedral','bastion']:
    self.block((x-2,0,z-2),(x+2,1,z+2),STONE);self.block((x-.8,1,z-.8),(x+.8,4,z+.8),'grave01_1');self.spire(x,z,4,1.3,3,IRON)
   else:
    self.block((x-3,0,z-2),(x+3,2,z+2),'ind_cont1_ylw1');self.cylinder(x+1,z,2,1.2,3,IRON)
   self.light((x,4,z-4),600,(.6,.75,.85),'courtyard')
   self.block((x-3,0,z+4),(x+3,.7,z+5),'med_wood6');self.block((x-3,.7,z+4.8),(x+3,1.5,z+5),IRON)
   self.props.append({'kind':'courtyard_furniture','position':[x,0,z]});count+=1
   if count>=6:break
 def build(self):
  zone=self.zone;name,style,tint,wall,trim=THEMES[zone]
  self.zones.append({'id':zone,'name':name,'style':style,'color':tint,'center':[0,0,0]})
  self.structural=True;self.block((-137,-3,-137),(137,0,137),'med_flat8',False,scale=4)
  self.block((-137,110,-137),(137,112,137),'sky1')
  for axis in [0,2]:
   for side in [-1,1]:
    lo=[-137,-3,-137];hi=[137,110,137];lo[axis]=side*136-1;hi[axis]=side*136+1;self.block(lo,hi,'sky1')
    custom=getattr(self,'campaign_gates',None)
    gate=next((g for g in custom if g['normal'][axis]==-side),None) if custom is not None else None
    valid=gate is not None if custom is not None else 0<=(zone%4 if axis==0 else zone//4)+side<4
    for a,b in ([(-125,-12),(12,125)] if valid else [(-125,125)]):
     lo=[a,0,side*125-1];hi=[b,36,side*125+1]
     if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
     self.block(lo,hi,wall,True)
    if valid:
     lo=[-12,16,side*125-1];hi=[12,36,side*125+1]
     if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
     self.block(lo,hi,STONE)
     dx,dz=(side,0) if axis==0 else (0,side);neighbor=zone+side*(1 if axis==0 else 4)
     self.gates.append(gate if custom is not None else dict(zone=zone,neighbor=neighbor,position=[dx*124.94,8,dz*124.94],normal=[-dx,0,-dz],color=tint,name=THEMES[neighbor][0]))
  self.structural=False
  self.choose_lots()
  for road in self.streets:self.street(road)
  self.cylinder(0,0,.18,18,.02,'med_cobstn2_1',20);self.glow(zone,(0,.23,0),(18,.02,18),tint,'plaza')
  room_index=0
  for i,lot in enumerate(self.lots):
   if lot[4]:self.room(lot,room_index);room_index+=1
   else:self.infill(lot,i)
  self.skyways()
  for i in range(4):
   if not self.pickup_positions[2+i]:self.pickup_positions[2+i]=[(-1 if i%2 else 1)*14,.3,(-1 if i<2 else 1)*14]
  for i in range(130):
   x=self.rng.randint(-112,112);z=self.rng.randint(-112,112)
   if not self.free(x,z,4,3,1) or self.road_distance((x,z))<14:continue
   if any(math.dist((x,z),(p['position'][0],p['position'][2]))<9 for p in self.props):continue
   self.stall(x,z,i)
   if sum(p['kind']=='market_stall' for p in self.props)>= (12 if style=='market' else 5):break
  for x,z in [(-20,-20),(20,-20),(-20,20),(20,20)]:self.spawns.append([x,.3,z]);self.point('info_player_deathmatch',(x,.3,z))
  self.landmarks()
  self.night_emitters()
