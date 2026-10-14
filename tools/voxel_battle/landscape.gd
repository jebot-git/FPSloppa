extends RefCounted
## One Godot unit = one metre. The prototype's deterministic natural height source,
## worker/cache budgets and generation pipeline are retained; scaled jungle world.
const EXTENT := 2828.4271247461903 # sqrt(8,000,000 square metres)
const GRID := 89
const TILE := EXTENT / GRID
const MIN_HEIGHT := -16.0
const MAX_HEIGHT := 640.0
const SAMPLES := 65
const COARSE_SAMPLES := 129
const TYPES := ["town", "factory", "port", "military", "radar", "west ridge relay", "canyon crossing", "river expedition camp", "canopy outpost", "summit observatory", "east ruins"]
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const CENTERS := [Vector3(-850,55,-600), Vector3(750,110,-720), Vector3(-650,2.4,750), Vector3(700,135,600), Vector3(0,85,4), Vector3(-1050,110,350), Vector3(-400,48,-350), Vector3(250,58,1000), Vector3(350,100,-280), Vector3(-200,350,-1100), Vector3(1100,175,450)]
const RADII := [76.0,68.0,78.0,76.0,48.0,40.0,35.0,45.0,42.0,38.0,50.0]
# x,z,radius,added elevation. Pads and graded roads cut into these cover ridges.
const COVER := [Vector4(-72,-66,30,9),Vector4(64,-70,25,11),Vector4(-79,39,28,8),Vector4(71,56,28,11),Vector4(18,102,23,7),Vector4(-10,-120,24,10),Vector4(-262,-25,22,8),Vector4(263,-30,22,9)]
# x,z,radius,height: rock formations are part of the terrain height/color field.
const ROCK_FORMATIONS := [Vector4(-410,-260,48,28),Vector4(-580,140,58,36),Vector4(390,360,65,31),Vector4(1050,180,95,55),Vector4(-1100,-800,80,43),Vector4(540,-1080,65,38)]
const ADDITIONAL_SITES := [
	{"name":"west ridge relay","position":Vector3(-1050,110,350),"radius":40.0},
	{"name":"canyon crossing","position":Vector3(-400,48,-350),"radius":35.0},
	{"name":"river expedition camp","position":Vector3(250,58,1000),"radius":45.0},
	{"name":"canopy outpost","position":Vector3(350,100,-280),"radius":42.0},
	{"name":"summit observatory","position":Vector3(-200,350,-1100),"radius":38.0},
	{"name":"east ruins","position":Vector3(1100,175,450),"radius":50.0}]
static var connectors:Array=[]
static var main_roads: Array=[]
static var access_roads: Array=[]
static var road_bins: Dictionary={}
static var access_bins: Dictionary={}
static var earthwork_bins: Dictionary={}
const ROAD_SHOULDER:=3.0
const MAX_EARTHWORK:=220.0
func _init() -> void:prepare_roads()
static func bin_key(p: Vector2) -> Vector2i:return Vector2i(floori((p.x+EXTENT*.5)/TILE),floori((p.y+EXTENT*.5)/TILE))
static func index_road(row: Dictionary,bins: Dictionary) -> void:
	var margin: float=row.get("earthwork",row.width+5)
	var lo:=bin_key(Vector2(minf(row.a.x,row.b.x)-margin,minf(row.a.z,row.b.z)-margin))
	var hi:=bin_key(Vector2(maxf(row.a.x,row.b.x)+margin,maxf(row.a.z,row.b.z)+margin))
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var key:=Vector2i(x,z)
			if not bins.has(key):bins[key]=[]
			bins[key].append(row)
static func add_road(a: Vector3,b: Vector3,width: float,along: float=0,earthworks: bool=false) -> void:
	var delta:=Vector2(b.x-a.x,b.z-a.z)
	var row:={"a":a,"b":b,"width":width,"along":along,"delta":delta,"inverse_length_squared":1.0/delta.length_squared()}
	main_roads.append(row);index_road(row,road_bins)
	if earthworks:
		# Broad graded cut/fill, never a thin asphalt ridge floating over a valley.
		var relief:=0.0
		for t in [0.0,.5,1.0]:
			var p:=a.lerp(b,t)
			relief=maxf(relief,absf(p.y-natural(p.x,p.z)))
		var margin:=clampf(width+ROAD_SHOULDER+16+relief*2.5,28,MAX_EARTHWORK)
		var foundation:=row.duplicate();foundation.earthwork=margin
		index_road(foundation,earthwork_bins)
static func curve(a: Vector3,b: Vector3,c1: Vector2,c2: Vector2,ignored_sites: Array=[]) -> void:
	var last:=a;var along:=0.0
	for i in range(1,13):
		var t:=float(i)/12;var u:=1-t
		var p:=Vector2(a.x,a.z)*u*u*u+c1*3*u*u*t+c2*3*u*t*t+Vector2(b.x,b.z)*t*t*t
		for site in ADDITIONAL_SITES:
			var center:=Vector2(site.position.x,site.position.z)
			var radius: float=(site.radius+10)*sqrt(2)
			if ignored_sites.has(site.name):continue
			var offset:=p-center
			if offset.length()<radius:p=center+offset.normalized()*radius
		var next:=Vector3(p.x,lerpf(a.y,b.y,smoothstep(0,1,t)),p.y)
		along+=routed_road(last,next,along,ignored_sites);last=next
static func crosses_pad(a:Vector2,b:Vector2,c:Vector2,radius:float) -> bool:
	# Slab intersection with the interior square, including complete through-cuts.
	var start:=0.0;var finish:=1.0;var delta:=b-a
	for axis in 2:
		if absf(delta[axis])<.000001:
			if a[axis]<=c[axis]-radius or a[axis]>=c[axis]+radius:return false
		else:
			var lo:float=(c[axis]-radius-a[axis])/delta[axis]
			var hi:float=(c[axis]+radius-a[axis])/delta[axis]
			start=maxf(start,minf(lo,hi));finish=minf(finish,maxf(lo,hi))
			if start>=finish:return false
	return true
static func routed_road(a:Vector3,b:Vector3,along:float,ignored:Array) -> float:
	var points:Array[Vector2]=[Vector2(a.x,a.z),Vector2(b.x,b.z)]
	for site in ADDITIONAL_SITES:
		if ignored.has(site.name):continue
		var center:=Vector2(site.position.x,site.position.z)
		var inner:float=site.radius+8;var outer:float=site.radius+10
		var corners:Array[Vector2]=[center+Vector2(-outer,-outer),center+Vector2(outer,-outer),center+Vector2(outer,outer),center+Vector2(-outer,outer)]
		var routed:Array[Vector2]=[points[0]]
		for i in range(1,points.size()):
			var start:Vector2=points[i-1];var end:Vector2=points[i]
			if crosses_pad(start,end,center,inner):
				var best:Array[Vector2]=[];var length:=INF
				for first in 4:
					for second in [first,(first+1)%4,(first+3)%4]:
						if crosses_pad(start,corners[first],center,inner) or crosses_pad(corners[second],end,center,inner):continue
						var candidate:float=start.distance_to(corners[first])+corners[first].distance_to(corners[second])+corners[second].distance_to(end)
						if candidate<length:
							length=candidate;best=[corners[first]]
							if second!=first:best.append(corners[second])
				routed.append_array(best)
			routed.append(end)
		points=routed
	var total:=0.0
	for i in range(1,points.size()):total+=points[i-1].distance_to(points[i])
	var walked:=0.0;var last:=a
	for i in range(1,points.size()):
		var distance:=points[i-1].distance_to(points[i]);walked+=distance
		var next:=Vector3(points[i].x,lerpf(a.y,b.y,walked/maxf(.0001,total)),points[i].y)
		add_road(last,next,5,along+walked-distance,true);last=next
	return total
static func prepare_roads() -> void:
	if not main_roads.is_empty():return
	for i in 5:
		var c: Vector3=CENTERS[i];var r: float=RADII[i];var w:=3.5 if i==4 else 5.0
		add_road(c-Vector3(r,0,0),c+Vector3(r,0,0),w)
		add_road(c-Vector3(0,0,r),c+Vector3(0,0,45 if i==2 else r),w)
	var town: Vector3=CENTERS[0]+Vector3(76,0,0)
	var factory: Vector3=CENTERS[1]-Vector3(68,0,0)
	var port: Vector3=CENTERS[2]-Vector3(0,0,78)
	var military: Vector3=CENTERS[3]-Vector3(76,0,0)
	var radar: Vector3=CENTERS[4]
	for pair in [[town,factory],[CENTERS[0]+Vector3(0,0,76),port],[CENTERS[1]+Vector3(0,0,68),CENTERS[3]-Vector3(0,0,76)],[CENTERS[2]+Vector3(78,0,0),military],[town,radar-Vector3(0,0,48)],[factory,radar+Vector3(48,0,0)],[port,radar-Vector3(48,0,0)],[military,radar+Vector3(0,0,48)]]:
		connect_sites(pair[0],pair[1])
	# Attach additional sites to an outdoor part of the existing road network,
	# never draw a diagonal spur through the occupied settlement blocks.
	var network:=main_roads.duplicate()
	for site in ADDITIONAL_SITES:
		var c: Vector3=site.position
		var target:=Vector3.ZERO;var distance:=INF
		for road in network:
			var point:=Vector2(c.x,c.z)
			var t:=clampf((point-Vector2(road.a.x,road.a.z)).dot(road.delta)*road.inverse_length_squared,0,1)
			var p: Vector3=road.a.lerp(road.b,t)
			var outdoor:=true
			for i in CENTERS.size():
				if maxf(absf(p.x-CENTERS[i].x),absf(p.z-CENTERS[i].z))<RADII[i]+25:outdoor=false
			if outdoor and c.distance_squared_to(p)<distance:target=p;distance=c.distance_squared_to(p)
		var delta:=target-c
		var direction:=Vector3(signf(delta.x),0,0) if absf(delta.x)>absf(delta.z) else Vector3(0,0,signf(delta.z))
		connect_sites(c+direction*site.radius,target)
	# Local crossroads connect the cardinal spur gates, leaving four buildable quadrants.
	for i in range(5,CENTERS.size()):
		var c:Vector3=CENTERS[i];var r:float=RADII[i]
		add_road(c-Vector3(r,0,0),c+Vector3(r,0,0),3.5)
		add_road(c-Vector3(0,0,r),c+Vector3(0,0,r),3.5)
	for spec in Architecture.specifications():
		var origin: Vector3=CENTERS[spec.kind]
		var width: float=3.5 if spec.kind>=4 else 5.0
		for side in [-1,1]:
			var a: Vector3=origin+spec.center+Vector3(0,0,side*(spec.size.y/2+.95))
			var b:=Vector3(origin.x+signf(spec.center.x)*(width+.9),origin.y,a.z)
			var delta:=Vector2(b.x-a.x,b.z-a.z)
			var row:={"a":a,"b":b,"width":.9,"along":0.0,"delta":delta,"inverse_length_squared":1.0/delta.length_squared(),"kind":spec.kind}
			access_roads.append(row);index_road(row,access_bins)
static func gate_direction(point: Vector3) -> Vector2:
	for i in CENTERS.size():
		var offset:=Vector2(point.x-CENTERS[i].x,point.z-CENTERS[i].z)
		if absf(absf(offset.x)-RADII[i])<.1 and absf(offset.y)<.1:return Vector2(signf(offset.x),0)
		if absf(absf(offset.y)-RADII[i])<.1 and absf(offset.x)<.1:return Vector2(0,signf(offset.y))
	return Vector2.ZERO
static func connect_sites(a: Vector3,b: Vector3) -> void:
	var begin:=main_roads.size()
	var delta:=Vector2(b.x-a.x,b.z-a.z)
	var bend:=Vector2(-delta.y,delta.x).normalized()*minf(210,delta.length()*.17)
	var ignored_sites: Array=[]
	for site in ADDITIONAL_SITES:
		for endpoint in [a,b]:
			if maxf(absf(endpoint.x-site.position.x),absf(endpoint.z-site.position.z))<=site.radius+1 and absf(endpoint.y-site.position.y)<.1:ignored_sites.append(site.name)
	var points: Array[Vector3]=[a]
	for t in [1.0/3,2.0/3]:
		var p: Vector2=Vector2(a.x,a.z)+delta*t+bend*(1 if t<.5 else -.65)
		points.append(Vector3(p.x,lerpf(a.y,b.y,smoothstep(0,1,t)),p.y))
	points.append(b)
	for i in 3:
		var start: Vector3=points[i];var end: Vector3=points[i+1]
		var length:=Vector2(end.x-start.x,end.z-start.z).length()
		var before: Vector3=points[maxi(0,i-1)];var after: Vector3=points[mini(3,i+2)]
		var start_direction:=Vector2(end.x-before.x,end.z-before.z).normalized()
		var end_direction:=Vector2(after.x-start.x,after.z-start.z).normalized()
		if i==0 and gate_direction(a)!=Vector2.ZERO:start_direction=gate_direction(a)
		if i==2 and gate_direction(b)!=Vector2.ZERO:end_direction=-gate_direction(b)
		var tangent:=minf(140,length*.30)
		curve(start,end,Vector2(start.x,start.z)+start_direction*tangent,Vector2(end.x,end.z)-end_direction*tangent,ignored_sites)
	var length:=0.0
	for index in range(begin,main_roads.size()):length+=main_roads[index].delta.length()
	connectors.append({"length":length,"straight_length":delta.length()})
static func road_foundation(point: Vector2,height: float) -> Vector2:
	var strongest:=0.0;var target:=height
	for row in earthwork_bins.get(bin_key(point),[]):
		var t:=clampf((point-Vector2(row.a.x,row.a.z)).dot(row.delta)*row.inverse_length_squared,0,1)
		var distance:=point.distance_to(Vector2(row.a.x,row.a.z)+row.delta*t)
		var influence:=1-smoothstep(row.width+ROAD_SHOULDER,row.earthwork,distance)
		if influence>strongest:
			strongest=influence;target=lerpf(row.a.y,row.b.y,t)
	return Vector2(lerpf(height,target,strongest),strongest)
static func nearest_road(point: Vector2,bins: Dictionary) -> Dictionary:
	var result: Dictionary={};var nearest:=INF
	for row in bins.get(bin_key(point),[]):
		var t:=clampf((point-Vector2(row.a.x,row.a.z)).dot(row.delta)*row.inverse_length_squared,0,1)
		var d:=point.distance_to(Vector2(row.a.x,row.a.z)+row.delta*t)
		if d<nearest:nearest=d;result={"distance":d,"t":t,"road":row}
	return result
static func sites() -> Array:
	var result: Array=[]
	for i in CENTERS.size(): result.append({"kind":i,"name":TYPES[i],"position":CENTERS[i]})
	return result
static func rock_mask(x: float,z: float) -> float:
	var result:=0.0
	for rock in ROCK_FORMATIONS:
		var d: float=Vector2(x-rock.x,z-rock.y).length()/rock.z
		result=maxf(result,1-smoothstep(.35,1.0,d))
	return result
static func natural(x: float,z: float) -> float:
	var h:=85.0+sin(x*.0032)*cos(z*.003)*32.0+sin(x*.011+z*.008)*8.0
	# Broad relief and sharp-sided ridges, all in the same terrain source.
	for peak in [Vector4(-300,-1130,380,310),Vector4(1030,-1040,350,390),Vector4(1110,120,290,205),Vector4(-1150,100,300,145),Vector4(160,530,310,85)]:
		var d: float=Vector2(x-peak.x,z-peak.y).length()/peak.z
		h+=peak.w*exp(-d*d*2.3)
	var canyon_x: float=-470+sin(z*.003)*95
	var canyon: float=(1-smoothstep(28,125,absf(x-canyon_x)))*(1-smoothstep(650,1050,absf(z)))
	h=lerpf(h,22+sin(z*.009)*5,canyon)
	var second: float=(1-smoothstep(22,105,absf(z-(-800+sin(x*.003)*70))))*smoothstep(50,260,x)*(1-smoothstep(850,1250,x))
	h=lerpf(h,46+sin(x*.006)*7,second)
	for rock in ROCK_FORMATIONS:
		var d: float=Vector2(x-rock.x,z-rock.y).length()/rock.z
		var ridge: float=(1-smoothstep(.2,1.0,d))*(.82+.18*sin(x*.09+z*.07))
		h+=rock.w*ridge
	for cover in COVER:
		var distance:=Vector2(x-cover.x,z-cover.y).length()
		if distance<cover.z:h+=cover.w*(1-smoothstep(0,cover.z,distance))
	return h
const Hydrology=preload("res://tools/voxel_battle/hydrology.gd")
const SEA_LEVEL:=0.0
static func estuary_mask(x: float,z: float) -> float:
	# Harbour opens into an estuary that widens continuously to the south map edge.
	var south:=z-CENTERS[2].z
	var distance:=maxf(0,south-68)
	var center:=CENTERS[2].x+sin(distance*.003)*28
	var width:=63+distance*.24
	return (1-smoothstep(width,width+11,absf(x-center)))*smoothstep(57,68,south)
static func water_sample(x:float,z:float) -> Vector3:
	var river:=Hydrology.sample(x,z)
	# Preserve inhabited pads; the authored channels pass outside their footprints.
	for i in CENTERS.size():
		var distance:=maxf(absf(x-CENTERS[i].x),absf(z-CENTERS[i].z))
		river.x*=smoothstep(RADII[i]+4,RADII[i]+16,distance)
	var sea:=estuary_mask(x,z)
	return Vector3(sea,SEA_LEVEL,8.0) if sea>river.x else river
static func water_mask(x:float,z:float) -> float:return water_sample(x,z).x
static func in_water(p:Vector3) -> bool:
	if not p.is_finite():return false
	var water:=water_sample(p.x,p.z)
	return water.x>.5 and p.y<water.y and p.y>surface(p.x,p.z).x-.15
static func is_road(x:float,z:float) -> bool:
	# Same boundaries as painted asphalt and access-lane terrain; shoulders excluded.
	prepare_roads()
	var point:=Vector2(x,z);var nearest:=nearest_road(point,road_bins)
	if not nearest.is_empty() and nearest.distance<nearest.road.width:return true
	var access:=nearest_road(point,access_bins)
	return not access.is_empty() and access.distance<.9
static func surface(x: float,z: float) -> Vector4:
	prepare_roads()
	var point:=Vector2(x,z)
	var h:=natural(x,z)
	var shade:=.5+.5*sin(x*.065+sin(z*.07)*2.0)
	# Distant grass and litter remain in the atlas. A bounded near-field grass
	# experiment streams with these tiles; it never replaces the ground cover.
	var cover:=forest_cover(x,z)
	var color:=Color(.24,.36,.18).lerp(Color(.12,.25,.12),cover)
	color=color.lerp(Color(.49,.46,.36),shade*.20)
	var gravel:=smoothstep(.72,.95,.5+.5*sin(x*.33)*sin(z*.27))*(1-cover)
	color=color.lerp(Color(.48,.47,.40),gravel*.35)
	color=color.lerp(Color(.42,.43,.38),maxf(rock_mask(x,z),smoothstep(220,390,h))*.85)
	var foundation:=road_foundation(point,h)
	h=foundation.x
	for site in ADDITIONAL_SITES:
		var c: Vector3=site.position
		var pad:=1-smoothstep(site.radius,site.radius+16,maxf(absf(x-c.x),absf(z-c.z)))
		h=lerpf(h,c.y,pad);color=color.lerp(Color(.36,.39,.23),pad*.75)
	for i in 5:
		var c: Vector3=CENTERS[i]
		var distance:=maxf(absf(x-c.x),absf(z-c.z))
		var pad:=1.0-smoothstep(RADII[i],RADII[i]+(8.0 if i==4 else 28.0),distance)
		h=lerpf(h,c.y,pad)
		color=color.lerp(Color(.38,.39,.29),pad*.6)
	# Access lanes stop at the asphalt edge. Main-road paint wins at a junction;
	# both types are part of the same height/color atlas, without overlapping strips.
	var access:=nearest_road(point,access_bins)
	if not access.is_empty() and access.distance<.9:
		color=Color(.53,.50,.40)
	var nearest:=nearest_road(point,road_bins)
	if not nearest.is_empty():
		var row: Dictionary=nearest.road;var width: float=row.width
		h=lerpf(h,lerpf(row.a.y,row.b.y,nearest.t),1-smoothstep(width,width+5,nearest.distance))
		if nearest.distance<width:
			color=Color(.24,.25,.23)
			if nearest.distance<.16 and fmod(row.along+nearest.t*row.delta.length(),10)<5:color=Color(.78,.72,.49)
	# Incoming additional-site spurs cannot tilt the flat building footprint.
	for site in ADDITIONAL_SITES:
		if maxf(absf(x-site.position.x),absf(z-site.position.z))<=site.radius:h=site.position.y
	# The heightfield is the solid river/sea bed. Water is a separate non-solid mesh.
	var water:=water_sample(x,z)
	h=lerpf(h,minf(h,water.y-water.z),water.x)
	color=color.lerp(Color(.28,.30,.23),water.x)
	return Vector4(h,color.r,color.g,color.b)
static func forest_cover(x: float,z: float) -> float:
	return .45+.55*smoothstep(-.5,.6,sin(x*.021+sin(z*.012)*2)*cos(z*.017)+sin((x+z)*.009)*.4)
static func planting_allowed(point: Vector2) -> bool:
	prepare_roads()
	for i in 5:
		var c: Vector3=CENTERS[i]
		if maxf(absf(point.x-c.x),absf(point.y-c.z))<RADII[i]+16:return false
	for site in ADDITIONAL_SITES:
		var c: Vector3=site.position
		if maxf(absf(point.x-c.x),absf(point.y-c.z))<site.radius+8:return false
	var near:=nearest_road(point,road_bins)
	if not near.is_empty() and near.distance<near.road.width+4:return false
	if water_mask(point.x,point.y)>.01:return false
	return true
static func features(coord: Vector2i) -> Array:
	# Independent per-tile RNG: repeatable across load order, workers and eviction.
	var rng:=RandomNumberGenerator.new();rng.seed=1977+coord.x*73856093+coord.y*19349663
	var result: Array=[]
	var origin:=Vector2(coord)*TILE-Vector2.ONE*EXTENT*.5
	for z in 4:
		for x in 4:
			var p:=origin+Vector2((x+.2+rng.randf()*.6)*TILE/4,(z+.2+rng.randf()*.6)*TILE/4)
			var choice:=rng.randf();var scale:=rng.randf_range(.75,1.25);var angle:=rng.randf()*TAU
			if not planting_allowed(p):continue
			var h:=surface(p.x,p.y).x
			if h<1:continue
			var slope:=Vector2(natural(p.x+1,p.y)-natural(p.x-1,p.y),natural(p.x,p.y+1)-natural(p.x,p.y-1)).length()*.5
			var cover:=forest_cover(p.x,p.y)
			var kind:=0
			if slope>.85 or rock_mask(p.x,p.y)>.65 or h>360:continue
			if choice<cover*.72:kind=0 # Broadleaf canopy on moist, moderate slopes.
			elif choice<.88 and h<180:kind=1 # Palms favour lower elevations.
			else:kind=2 # Fern understory, no rock mesh instances.
			result.append({"kind":kind,"position":Vector3(p.x,h,p.y),"scale":scale,"angle":angle})
	return result
func generate_tile(coord: Vector2i) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var heights := PackedFloat32Array()
	var colors := PackedByteArray()
	heights.resize(SAMPLES * SAMPLES)
	colors.resize(SAMPLES * SAMPLES * 4)
	var origin := Vector2(coord) * TILE - Vector2.ONE * EXTENT * .5
	for z in SAMPLES:
		for x in SAMPLES:
			var value := surface(origin.x + x * TILE / (SAMPLES-1), origin.y + z * TILE / (SAMPLES-1))
			var i := z * SAMPLES + x
			heights[i] = value.x
			colors[i * 4] = roundi(value.y * 255.0)
			colors[i * 4 + 1] = roundi(value.z * 255.0)
			colors[i * 4 + 2] = roundi(value.w * 255.0)
			colors[i * 4 + 3] = 255
	return {"coord": coord, "heights": heights.to_byte_array(), "colors": colors, "features": features(coord), "grass": grass_features(coord,heights), "generation_ms": (Time.get_ticks_usec() - begin) / 1000.0}

static func grass_features(coord: Vector2i,heights: PackedFloat32Array) -> PackedVector4Array:
	# Existing worker height samples provide height/slope: no new surface passes.
	var rows:=PackedVector4Array()
	var rng:=RandomNumberGenerator.new();rng.seed=8137+coord.x*73856093+coord.y*19349663
	var origin:=Vector2(coord)*TILE-Vector2.ONE*EXTENT*.5
	for z in 32:
		for x in 32:
			var fx: float=(x+.25+rng.randf()*.5)*2;var fz: float=(z+.25+rng.randf()*.5)*2
			var angle:=rng.randf()*TAU
			# Dense rooted clumps; retain the same bounded, deterministic candidate grid.
			if rng.randf()>.90:continue
			var p:=origin+Vector2(fx,fz)*TILE/(SAMPLES-1)
			if not planting_allowed(p) or rock_mask(p.x,p.y)>.4:continue
			var ix:=floori(fx);var iz:=floori(fz);var i:=iz*SAMPLES+ix
			var a:=heights[i];var b:=heights[i+1];var c:=heights[i+SAMPLES];var d:=heights[i+SAMPLES+1]
			var h:=lerpf(lerpf(a,b,fx-ix),lerpf(c,d,fx-ix),fz-iz)
			if h<1 or h>330:continue
			var slope:=Vector2(b-a,c-a).length()/(TILE/(SAMPLES-1))
			if slope>.55:continue
			rows.append(Vector4(p.x,h-.03,p.y,angle))
	return rows

func coarse_images() -> Array[Image]:
	var heights := Image.create(COARSE_SAMPLES, COARSE_SAMPLES, false, Image.FORMAT_RF)
	var colors := Image.create(COARSE_SAMPLES, COARSE_SAMPLES, false, Image.FORMAT_RGBA8)
	for z in COARSE_SAMPLES:
		for x in COARSE_SAMPLES:
			var value := surface(x * EXTENT/(COARSE_SAMPLES-1) - EXTENT*.5, z * EXTENT/(COARSE_SAMPLES-1) - EXTENT*.5)
			heights.set_pixel(x, z, Color(value.x, 0, 0))
			colors.set_pixel(x, z, Color(value.y, value.z, value.w))
	return [heights, colors]
