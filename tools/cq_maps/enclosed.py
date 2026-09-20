"""Enclosed revision: carved interblocks, two-car lanes and a second pedestrian tier.

Shapely is build-time only. All carved volumes become ordinary convex BSP29 brushes.
No runtime procedural geometry, jetpack mechanic, or extra light is introduced.
"""
import math, heapq
from shapely import constrained_delaunay_triangles, set_precision, STRtree
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union, nearest_points
from urban import District as Urban
from city import THEMES, IRON

def pieces(shape):
 if shape.is_empty:return []
 return list(shape.geoms) if hasattr(shape,'geoms') else [shape]

def convexes(shape):
 # Snap to 1/32 metre (one Quake unit) before triangulating. Merge triangles when
 # their union is convex: fewer compiler planes, no overlapping/invalid brushes.
 shape=set_precision(shape,.03125)
 polygons=list(constrained_delaunay_triangles(shape).geoms)
 changed=True
 while changed:
  changed=False;tree=STRtree(polygons);used=set();merged=[]
  for i,a in enumerate(polygons):
   if i in used:continue
   used.add(i)
   for j in sorted(tree.query(a)):
    if j in used:continue
    b=polygons[j]
    if not a.intersects(b):continue
    u=a.union(b)
    if u.geom_type=='Polygon' and abs(u.convex_hull.area-u.area)<.00001:
     a=u.convex_hull;used.add(j);changed=True;break
   merged.append(a)
  polygons=merged
 return polygons

class District(Urban):
 def __init__(self,zone):
  super().__init__(zone);self.passages=[];self.bridge_paths=[];self.courtyards=[];self.hops=[];self.parking=[];self.vehicle_footprints=[]
 def free(self,x,z,w,d,pad=0):
  # Upper access galleries need clearance between adjacent inhabited halls.
  if len(self.lots)<4:
   for xx,zz,ww,dd,*_ in self.lots:
    if abs(x-xx)<w+ww+pad+7 and abs(z-zz)<d+dd+pad+7:return False
  return super().free(x,z,w,d,pad)
 def street(self,points):
  for a,b in zip(points,points[1:]):
   self.segment(a,b,7,-.02,.04,'ind_dp01_blk1')
   length=math.dist(a,b);dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
   for side in [-1,1]:
    aa=(a[0]-dz*side*4.5,a[1]+dx*side*4.5);bb=(b[0]-dz*side*4.5,b[1]+dx*side*4.5)
    self.segment(aa,bb,2,-.02,.18,'med_cobstn2_1a')
   for j in range(max(1,int(length/24))):
    t=(j+.5)/max(1,int(length/24));x=a[0]+dx*length*t;z=a[1]+dz*length*t
    if math.hypot(x,z)<34 or max(abs(x),abs(z))>108:continue
    side=1 if (j+self.zone)%2 else -1
    lamp=(x-dz*side*5.05,z+dx*side*5.05)
    if self.road_distance(lamp)>4.3 and not any(body.buffer(1).contains(Point(lamp)) for body in self.vehicle_footprints):self.lamp(*lamp,dx,dz)
    if self.rng.random()<.6:
     px=x+dz*side*7.4;pz=z-dx*side*7.4
     truck=self.rng.random()<.3
     half=4.6 if truck else 3.2
     footprint=Polygon([(px+dx*u-dz*v,pz+dz*u+dx*v) for u,v in [(-half,-1.6),(half,-1.6),(half,1.6),(-half,1.6)]])
     lanes=unary_union([LineString(road).buffer(3.6,join_style=2) for road in self.streets])
     if footprint.intersects(lanes):continue
     if any(footprint.buffer(1).contains(Point(prop["position"][0],prop["position"][2])) for prop in self.props if prop["kind"]=="streetlamp"):continue
     self.vehicle(px,pz,math.atan2(dz,dx),truck);self.vehicle_footprints.append(footprint)
     self.parking.append(LineString([(x-dx*6,z-dz*6),(x+dx*6,z+dz*6)]).buffer(9.5,cap_style=2))
   self.street_points.append([max(-121,min(121,a[0])),.3,max(-121,min(121,a[1]))])
  for x,z in points[1:-1]:
   self.cylinder(x,z,-.02,5.5,.06,'med_cobstn2_1a',8);self.cylinder(x,z,.04,3.5,.01,'ind_dp01_blk1',8)
   if math.hypot(x,z)>33:self.light((x,4,z),4000,(.7,.8,1),'junction_fill')
 def infill(self,lot,index):
  # The old disconnected towers become the inhabited interblock mass. Keep their
  # skyline variations, but put shop fronts along the actual carved streets.
  x,z,w,d,_=lot;_,style,tint,wall,trim=THEMES[self.zone]
  h=30+(index%3)*3
  self.block((x-w*.65,30,z-d*.65),(x+w*.65,h+3,z+d*.65),trim)
  if style in ['cathedral','garden']:self.spire(x,z,h+3,min(w,d)*.6,8,trim)
 def landmarks(self):pass
 def skyways(self):pass # Generated together with the carved interblocks below.
 def volume(self,shape,low,high,texture):
  for polygon in convexes(shape):
   if polygon.area<.01:continue
   points=list(polygon.exterior.coords)[:-1]
   self.prism(points,low,high,texture)
 def routed(self,p,q):
  obstacle=self.room_obstacles
  nodes=[p,q]+[tuple(c) for poly in pieces(obstacle) for c in list(poly.exterior.coords)[:-1]]
  inner=obstacle.buffer(-.04);links=[[] for _ in nodes]
  for i,a in enumerate(nodes):
   for j in range(i+1,len(nodes)):
    b=nodes[j]
    if not LineString([a,b]).intersects(inner):
     weight=math.dist(a,b);links[i].append((j,weight));links[j].append((i,weight))
  pending=[(0,0,[0])];best={0:0}
  while pending:
   cost,i,path=heapq.heappop(pending)
   if i==1:return [nodes[n] for n in path]
   if cost>best[i]:continue
   for j,weight in links[i]:
    if cost+weight<best.get(j,math.inf):best[j]=cost+weight;heapq.heappush(pending,(cost+weight,j,path+[j]))
  raise AssertionError(('No hall-avoiding access',self.zone,p,q))
 def link(self,p,network,width=5):
  q=nearest_points(Point(p),network)[1];path=self.routed(p,(q.x,q.y))
  if math.dist(path[0],path[-1])>.1:
   self.passages.append(path);self.street_points.append([p[0],.3,p[1]])
   access=LineString(path).buffer(width/2,cap_style=3,join_style=2)
   # A connecting alley must have room to walk around a car in its parking bay.
   return unary_union([access]+[body.buffer(2.5,join_style=2) for body in self.vehicle_footprints if access.intersects(body)])
  return Point(p).buffer(width/2,quad_segs=2)
 def bridge(self,path):
  self.bridge_paths.append(path)
  for a,b in zip(path,path[1:]):
   if math.dist(a,b)<.1:continue
   # The complete deck union is built after every connection is known.
   self.light(((a[0]+b[0])/2,9.7,(a[1]+b[1])/2),2500,(.62,.73,1),'bridge_ceiling')
  for x,z in path:self.street_points.append([x,6.1,z])
  self.props.append({'kind':'skyway','points':path,'position':[path[0][0],6,path[0][1]]})
 def arch(self,a,b,t):
  length=math.dist(a,b);dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length;x=a[0]+dx*length*t;z=a[1]+dz*length*t
  _,style,tint,wall,trim=THEMES[self.zone]
  # Chamfered / pointed ribs frame the upper gallery as well as the underpass.
  # The full two-car carriageway remains clear at player height.
  if any(body.buffer(1).contains(Point(x-dz*side*5.65,z+dx*side*5.65)) for side in [-1,1] for body in self.vehicle_footprints):return
  if any(self.road_distance((x-dz*side*5.65,z+dx*side*5.65))<4.3 for side in [-1,1]):return
  if any(self.upper_lines.distance(Point(x-dz*side*5.65,z+dx*side*5.65))<3.2 for side in [-1,1]):return
  for side in [-1,1]:
   self.segment((x-dz*side*5.65-dx*.35,z+dx*side*5.65-dz*.35),(x-dz*side*5.65+dx*.35,z+dx*side*5.65+dz*.35),.65,.2,10.6,trim)
   pts=[]
   for along in [-.35,.35]:
    for lateral,y in [(side*5.8,9.0),(side*2.2,11.65),(side*5.8,11.65)]:pts.append((x+dx*along-dz*lateral,y,z+dz*along+dx*lateral))
   self.hull(pts,[[0,1,2],[3,4,5],[0,3,4],[1,4,5],[2,5,3]],trim)
  self.props.append({'kind':'archway','position':[x,0,z]})
 def build(self):
  super().build()
  zone=self.zone;_,style,tint,wall,trim=THEMES[zone]
  roads=unary_union([LineString(p) for p in self.streets])
  room_areas=[box(x-w-3.8,z-d-4,x+w+3.8,z+d+4) for x,z,w,d,inside in self.lots if inside]
  self.room_obstacles=unary_union([box(x-w-4,z-d-4,x+w+4,z+d+4) for x,z,w,d,inside in self.lots if inside])
  public=box(-24,-24,24,24)
  ground=[roads.buffer(6,join_style=2,cap_style=2),public,*room_areas,*self.parking]
  # Doors at both ends of each hall lead through short enclosed access alleys.
  for room in self.rooms:
   x,_,z=room['center'];w,d=room['half_size']
   for side in [-1,1]:ground.append(self.link((x,z+side*(d+4.1)),roads))
  # Keep stalls in accessible pockets instead of burying them in the city mass.
  for prop in self.props:
   if prop['kind']=='market_stall':
    x,_,z=prop['position'];ground.append(box(x-5,z-5,x+5,z+5));ground.append(self.link((x,z-4),roads,4))
  gate_areas=[]
  for gate in self.gates:
   x,_,z=gate['position'];n=gate['normal'];a=(x-n[0]*12,z-n[2]*12);b=(x+n[0]*18,z+n[2]*18)
   gate_areas.append(LineString([a,b]).buffer(12,cap_style=2));ground.append(gate_areas[-1])
  # Small open-sky pockets punctuate the circulation; the capture court is one.
  self.courtyards=[{'center':[0,0],'radius':9}]
  candidates=[p for road in self.streets[2:] for p in road[1:-1] if 48<math.hypot(*p)<109]
  candidates += [p for road in self.streets for p in road[1:-1] if math.hypot(*p)>48 and max(abs(p[0]),abs(p[1]))<105]
  for p in candidates:
   if all(math.dist(p,c['center'])>35 for c in self.courtyards):self.courtyards.append({'center':p,'radius':8+zone%3})
   if len(self.courtyards)>=3:break
  for court in self.courtyards[1:]:ground.append(Point(court['center']).buffer(court['radius']+2,quad_segs=2))
  # Upper network follows the distinct street bends, while bypassing the central
  # skylight. Every hall's 6 m gallery connects to it with normal ramp access.
  for i,road in enumerate(self.streets[:2]):
   path=[(max(-108,min(108,x)),max(-108,min(108,z))) if max(abs(x),abs(z))>110 else ((0,17) if i==0 else (-17,0)) if (x,z)==(0,0) else (x,z) for x,z in road]
   path=[p for j,p in enumerate(path) if j==0 or p!=path[j-1]];self.bridge(path)
  bridge_lines=unary_union([LineString(p) for p in self.bridge_paths])
  # Use the existing hall access corridors to reach the upper spine. Avoid
  # cutting through unrelated rooms by connecting first to the nearest road.
  for room in self.rooms:
   x,_,z=room['center'];d=room['half_size'][1];p=(x,z-d-1.5)
   q=nearest_points(Point(p),bridge_lines)[1]
   access=(x,z-d-4.1)
   self.bridge([p]+self.routed(access,(q.x,q.y)))
  # Two optional 4 m, level jetpack gaps. Both sides join the pedestrian network,
  # so neither progression nor pickup access depends on experimental movement.
  for sign in [-1,1]:
   z=sign*12
   for side in [-1,1]:
    p=(side*4,z);q=nearest_points(Point((side*9,z)),bridge_lines)[1]
    self.bridge([p,(side*9,z),(q.x,q.y)])
    self.block((side*4-2,5.65,z-2.5),(side*4+2,6,z+2.5),trim)
   self.hops.append({'from':[-2,6,z],'to':[2,6,z],'gap_metres':4,'rise_metres':0,'landing_size':[4,5],'headroom_metres':5.5})
  self.upper_lines=unary_union([LineString(p) for p in self.bridge_paths])
  self.volume(self.upper_lines.buffer(2.25,join_style=2,cap_style=2),5.65,6,trim)
  junctions=unary_union([Point(p).buffer(4.5) for line in pieces(self.upper_lines) for p in line.coords])
  for path in self.bridge_paths:
   for a,b in zip(path,path[1:]):
    length=math.dist(a,b)
    if length<8:continue
    dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
    for side in [-1,1]:
     edge=LineString([(a[0]-dz*side*2.15,a[1]+dx*side*2.15),(b[0]-dz*side*2.15,b[1]+dx*side*2.15)])
     for rail in pieces(edge.difference(junctions)):
      if rail.length>.3:self.segment(rail.coords[0],rail.coords[-1],.2,6,6.18,IRON)
  bridge_space=unary_union([LineString(p).buffer(3.2,join_style=2,cap_style=3) for p in self.bridge_paths]+[box(-6,z-3,6,z+3) for z in [-12,12]])
  walk=unary_union(ground).buffer(0)
  bounds=box(-124,-124,124,124)
  # Carve three strata; upper bridges can pass through buildings as enclosed
  # galleries, and cross roads as actual underpasses with 5.65 m clearance.
  self.structural=True
  self.volume(bounds.difference(walk),0,5.65,wall)
  self.volume(bounds.difference(walk.union(bridge_space)),5.65,11.7,wall)
  self.volume(bounds.difference(walk),11.7,30,wall)
  sky=unary_union([Point(c['center']).buffer(c['radius'],quad_segs=2) for c in self.courtyards])
  if getattr(self,'campaign_profile','closed')=='mixed':
   sky=sky.union(roads.buffer(7).intersection(box(25,-110,105,110)))
  halls=unary_union(room_areas);gates=unary_union(gate_areas)
  low_ceiling=walk.union(bridge_space).intersection(bounds).difference(halls.union(gates).union(sky))
  self.volume(low_ceiling,11.7,12.2,trim)
  self.volume(halls.difference(sky),24,24.5,trim)
  self.volume(gates.intersection(box(-137,-137,137,137)),19,19.5,trim)
  self.structural=False
  for road in self.streets:
   for a,b in zip(road,road[1:]):
    if math.dist(a,b)>25 and math.hypot((a[0]+b[0])/2,(a[1]+b[1])/2)>32:self.arch(a,b,.5)
  for road in self.streets:
   for a,b in zip(road,road[1:]):
    length=math.dist(a,b);dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
    for step in range(10,int(length)-5,16):
     x=a[0]+dx*step;z=a[1]+dz*step
     for side in [-1,1]:
      if walk.contains(Point(x-dz*side*6.2,z+dx*side*6.2)):continue
      px=x-dz*side*5.92;pz=z+dx*side*5.92
      ends=[(px-dx*2,pz-dz*2),(px+dx*2,pz+dz*2)]
      self.segment(*ends,.18,.3,4.3,trim)
      self.glow(zone,(px,2.7,pz),(3.4,2.5,.22),tint,'window',gothic=style in ['cathedral','garden'],yaw=-math.atan2(dz,dx))
      self.light((px+dz*side,3.4,pz-dx*side),1800,(.55,.7,1),'shop_window')
      self.props.append({'kind':'street_front','position':[px,0,pz]})
  for p in self.passages:
   a,b=p[0],p[-1];self.light(((a[0]+b[0])/2,3.8,(a[1]+b[1])/2),2200,(.66,.76,1),'access_passage')
  for x,z in [(-19,-19),(19,-19),(-19,19),(19,19)]:
   self.glow(zone,(x,10.9,z),(4,.25,4),tint);self.light((x,10.5,z),11000,(.68,.75,1),'atrium')
  # Conservative occluders wholly inside solid mass; never span carved passages.
  solid=bounds.difference(walk.union(bridge_space))
  for x in range(-116,120,12):
   for z in range(-116,120,12):
    if solid.contains(box(x-5,z-5,x+5,z+5)):self.solids.append({'minimum':[x-5,0,z-5],'maximum':[x+5,30,z+5]})
  samples=[]
  for road in self.streets:
   line=LineString(road)
   for step in range(2,int(line.length),6):
    p=line.interpolate(step)
    if max(abs(p.x),abs(p.y))<120:samples.append([p.x,1.8,p.y])
  self.enclosure={'road_width_metres':7,'sidewalk_width_metres':2,'courtyards':self.courtyards,'passages':self.passages,'bridges':self.bridge_paths,'jetpack_hops':self.hops,'roof_samples':samples,'ground_walk_area_m2':walk.intersection(bounds).area,'sky_open_area_m2':sky.intersection(walk).area,'ground_outline':[{'outer':list(p.exterior.coords),'holes':[list(r.coords) for r in p.interiors]} for p in pieces(walk.intersection(bounds))],'revision':'enclosed-city-3'}
