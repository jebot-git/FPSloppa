extends RefCounted
## Authored BSP29 convex solids, independent of render atlases and merged RIDs.
## Missing/invalid metadata fails closed. Only CS firing opts into this trace.
const LUMP="FSLP_BALLISTICS"
const MAX_BRUSHES=8192
const MAX_CANDIDATES=256
const EPS=.002
# Successful wall exits, power (BSP units), maximum range before penetration.
# ReGameDLL FireBullets3 counts include the terminal impact, hence count - 1.
const WEAPONS={6:[1,39.0,5000.0/39.37],7:[1,35.0,4000.0/39.37],8:[1,35.0,4000.0/39.37],9:[2,45.0,8000.0/39.37],10:[1,30.0,1000.0/39.37]}
const MATERIALS={"wood":[1.0,.6],"metal":[.15,.2],"concrete":[.25,.5],"vent":[.5,.45],"glass":[1.0,.5],"stop":[0.0,0.0]}
var brushes: Array=[]
var tree: Array=[]
var movers: Array=[]
var map_root: Node3D
var ready:=false
var queries:=0

func open(path: String,root: Node3D) -> bool:
	ready=false;brushes.clear();tree.clear();movers.clear();map_root=root
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()<124 or bytes.size()>25_000_000 or bytes.decode_u32(0)!=29:return false
	var end:=124
	for i in 15:
		var offset:=bytes.decode_u32(4+i*8);var length:=bytes.decode_u32(8+i*8)
		if offset+length>bytes.size():return false
		end=maxi(end,offset+length)
	end=(end+3)&~3
	if end+8>bytes.size() or bytes.slice(end,end+4).get_string_from_ascii()!="BSPX":return false
	var count:=bytes.decode_u32(end+4)
	if count>64 or end+8+count*32>bytes.size():return false
	for i in count:
		var at:=end+8+i*32
		if bytes.slice(at,at+24).get_string_from_ascii()!=LUMP:continue
		var offset:=bytes.decode_u32(at+24);var length:=bytes.decode_u32(at+28)
		if length>8_000_000 or offset+length>bytes.size():return false
		var data=JSON.parse_string(bytes.slice(offset,offset+length).get_string_from_utf8())
		return configure(data,root)
	return false

static func vector(value) -> bool:
	return value is Array and value.size()==3 and value.all(func(v):return (v is float or v is int) and is_finite(v) and absf(v)<100000)
static func v3(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
static func decode_brushes(values) -> Array:
	var result: Array=[]
	if not values is Array or values.size()>MAX_BRUSHES:return []
	for row in values:
		if not row is Array or row.size()!=4 or not vector(row[0]) or not vector(row[1]):return []
		if not row[2] is Array or row[2].size()<4 or row[2].size()>32 or not row[3] is Array or row[2].size()!=row[3].size():return []
		var low:=v3(row[0]);var high:=v3(row[1]);var planes: Array[Plane]=[]
		if high.x<low.x or high.y<low.y or high.z<low.z:return []
		for i in row[2].size():
			var p=row[2][i]
			if not p is Array or p.size()!=4 or not vector(p.slice(0,3)) or not (p[3] is float or p[3] is int) or not is_finite(p[3]) or absf(p[3])>100000 or not MATERIALS.has(row[3][i]):return []
			var n:=Vector3(p[0],p[1],p[2])
			if absf(n.length_squared()-1)>.001:return []
			planes.append(Plane(n,p[3]))
		result.append({"bounds":AABB(low,high-low),"planes":planes,"materials":row[3]})
	return result

func configure(data,root: Node3D) -> bool:
	ready=false;brushes.clear();tree.clear();movers.clear();map_root=root
	if not data is Dictionary or data.get("version")!=1 or not data.get("tree") is Array or not data.get("movers") is Array:return false
	brushes=decode_brushes(data.get("static"))
	if brushes.is_empty() or data.tree.is_empty() or data.tree.size()>MAX_BRUSHES*2 or data.movers.size()>128:return false
	for i in data.tree.size():
		var row=data.tree[i]
		if not row is Array or row.size()!=4 or not vector(row[0]) or not vector(row[1]) or not row[2] is bool or not row[3] is Array:return false
		if row[3].is_empty() or row[3].size()>(6 if row[2] else 2):return false
		for child in row[3]:
			if not (child is int or child is float) or int(child)!=child or child<0 or child>=(brushes.size() if row[2] else data.tree.size()) or not row[2] and child<=i:return false
		tree.append({"bounds":AABB(v3(row[0]),v3(row[1])-v3(row[0])),"leaf":row[2],"children":row[3]})
	var entities: Dictionary={}
	for node in root.find_children("*","Node3D",true,false):
		if node.get_script()==preload("res://deathmatch/maps/entity.gd"):
			entities[str(node.attributes.get("_fps_id",node.attributes.get("targetname","")))]=node
	for row in data.movers:
		if not row is Dictionary or not row.get("name") is String or not entities.has(row.name):return false
		var parts:=decode_brushes(row.get("brushes"))
		if parts.is_empty():return false
		var node: Node3D=entities[row.name]
		movers.append({"node":node,"rest":node.global_position,"brushes":parts})
	ready=true;return true

static func box_hits(bounds: AABB,start: Vector3,direction: Vector3,limit: float) -> bool:
	var low:=0.0;var high:=limit
	for axis in 3:
		if absf(direction[axis])<.0000001:
			if start[axis]<bounds.position[axis]-EPS or start[axis]>bounds.end[axis]+EPS:return false
		else:
			var a: float=(bounds.position[axis]-start[axis])/direction[axis]
			var b: float=(bounds.end[axis]-start[axis])/direction[axis]
			low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
			if low>high+EPS:return false
	return true

static func clip(brush: Dictionary,start: Vector3,direction: Vector3,limit: float) -> Dictionary:
	if not box_hits(brush.bounds,start,direction,limit):return {}
	var enter:=-INF;var leave:=INF;var material: String="stop"
	for i in brush.planes.size():
		var plane: Plane=brush.planes[i];var offset:=plane.distance_to(start);var slope:=plane.normal.dot(direction)
		if absf(slope)<.0000001:
			if offset>.00001:return {}
		elif slope<0:
			var at: float=-offset/slope
			if at>enter:enter=at;material=brush.materials[i]
		else:leave=minf(leave,-offset/slope)
		if enter>leave+.00001:return {}
	if leave<0 or enter>limit:return {}
	return {"enter":maxf(0,enter),"leave":leave,"material":material}

func intervals(start: Vector3,direction: Vector3,limit: float) -> Array:
	queries=0
	var found: Array=[];var stack: Array=[0];var visited:=0
	while not stack.is_empty():
		visited+=1
		if visited>2048:return []
		var branch: Dictionary=tree[stack.pop_back()]
		if not box_hits(branch.bounds,start,direction,limit):continue
		if not branch.leaf:stack.append_array(branch.children);continue
		for index in branch.children:
			queries+=1
			if queries>MAX_CANDIDATES:return []
			var hit:=clip(brushes[index],start,direction,limit)
			if not hit.is_empty():found.append(hit)
	for mover in movers:
		if not is_instance_valid(mover.node) or mover.node.collision_layer&1==0:continue
		var local: Vector3=start-(mover.node.global_position-mover.rest)
		for brush in mover.brushes:
			queries+=1
			if queries>MAX_CANDIDATES:return []
			var hit:=clip(brush,local,direction,limit)
			if not hit.is_empty():found.append(hit)
	found.sort_custom(func(a,b):return a.enter<b.enter)
	return found

func exit_surface(entry: Vector3,direction: Vector3,power: float,space: PhysicsDirectSpaceState3D=null) -> Dictionary:
	if not ready or not entry.is_finite() or not direction.is_normalized() or power<=0 or power>2:return {}
	var start:=entry-direction*EPS;var limit:=power+EPS*2
	var hits:=intervals(start,direction,limit)
	if hits.is_empty() or hits[0].enter>EPS*2:return {}
	# Merge touching solids, preserving the strongest material in overlaps. There
	# must be a true air gap before resuming; adjacent brushes are not loopholes.
	var end: float=hits[0].leave;var active: Array=[];var cuts: Array[float]=[]
	for hit in hits:
		if hit.enter>end+.0001:break
		end=maxf(end,hit.leave);active.append(hit);cuts.append(hit.enter);cuts.append(hit.leave)
	if end>=limit or end<EPS:return {}
	cuts.sort();var cost:=0.0;var retention:=1.0
	for i in cuts.size()-1:
		var width:=cuts[i+1]-cuts[i]
		if width<.000001:continue
		var middle: float=(cuts[i]+cuts[i+1])*.5;var resistance:=0.0
		for hit in active:
			if middle<hit.enter or middle>hit.leave:continue
			var rules: Array=MATERIALS[hit.material]
			if rules[0]<=0:return {}
			resistance=maxf(resistance,1.0/float(rules[0]));retention=minf(retention,rules[1])
		cost+=width*resistance
		if cost>power+.00001:return {}
	var outside:=start+direction*(end+EPS)
	if space:
		# BSP compilation clips/merges faces. Authored volumes must still end at
		# a real collision surface; mismatched or enclosed exits fail closed.
		var query:=PhysicsRayQueryParameters3D.create(outside,entry-direction*.05,1)
		query.hit_from_inside=true
		var reverse:=space.intersect_ray(query)
		if reverse.is_empty() or reverse.normal.is_zero_approx() or reverse.position.distance_to(outside)>.012:return {}
	return {"position":outside,"thickness":end-hits[0].enter,"cost":cost,"retention":retention}

func trace(game: Node,start: Vector3,end: Vector3,id: int,rewind: float,weapon: int) -> Array:
	var results: Array=[];var current:=start;var direction: Vector3=(end-start).normalized()
	var profile: Array=WEAPONS.get(weapon,[0,0.0,0.0]);var power: float=profile[1]/32.0;var factor:=1.0
	for layer in int(profile[0])+1:
		var hit: Dictionary=game._trace(current,end,id,rewind)
		hit["damage_scale"]=factor;results.append(hit)
		if not ready or layer==int(profile[0]) or not hit.hit or hit.id!=0 or hit.has("building") or start.distance_to(hit.position)>profile[2]:break
		# Only the authored map can use its metadata; runtime props, players and
		# deployables still block. Never exclude a merged map collider RID.
		var query:=PhysicsRayQueryParameters3D.create(hit.position-direction*.02,hit.position+direction*.02,1)
		query.hit_from_inside=true
		var contact: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if contact.is_empty() or not map_root.is_ancestor_of(contact.collider):break
		var passage:=exit_surface(hit.position,direction,power,game.get_world_3d().direct_space_state)
		if passage.is_empty():break
		var remaining: float=passage.position.distance_to(end)*.5
		if (end-passage.position).dot(direction)<=0 or remaining<EPS:break
		factor*=float(passage.retention);power-=float(passage.cost)
		current=passage.position;end=current+direction*remaining
	return results
