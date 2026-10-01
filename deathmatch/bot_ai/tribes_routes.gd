extends RefCounted
## A terrain/portal graph complements the walking mesh. Edges describe real
## clear air corridors, never teleport or grant energy. See ST-CTF-RESEARCH.md.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)
class TerrainGraph extends AStar3D:
	var costs: Dictionary={}
	var travel: Dictionary={}
	var covered: Dictionary={}
	var cached_travel: Dictionary={}
	var edge_costs: Dictionary={}
	func prepare(context: Dictionary):
		travel=context
		if context!=cached_travel:cached_travel=context.duplicate();edge_costs.clear()
	func _estimate_cost(from_id: int,to_id: int) -> float:
		return get_point_position(from_id).distance_to(get_point_position(to_id))*(.35 if not travel.is_empty() else 1.0)
	func _compute_cost(from_id: int,to_id: int) -> float:
		var edge:=Vector2i(from_id,to_id)
		if not travel.is_empty() and edge_costs.has(edge):return edge_costs[edge]+float(costs.get(to_id,0))
		var a:=get_point_position(from_id);var b:=get_point_position(to_id)
		var climb:=maxf(0,b.y-a.y)
		if not travel.is_empty():
			var distance:=a.distance_to(b)
			var speed: float=travel.walk if climb>1 else travel.speed
			var cost: float=distance*maxf(.35,travel.walk/speed)+climb*(2+4*(1-travel.reserve))
			if covered.has(from_id) or covered.has(to_id):cost+=distance*.9+travel.walk*.4
			edge_costs[edge]=cost
			return cost+float(costs.get(to_id,0))
		return a.distance_to(b)+climb*1.8+maxf(0,climb-4)*3+float(costs.get(to_id,0))
var graph:=TerrainGraph.new()
var built:=false
var points:=PackedVector3Array()
var cells: Dictionary={}
var cover_cache: Dictionary={}
const SPACING:=16.0

func add(point: Vector3) -> void:
	if not point.is_finite():return
	# A downward terrain probe can start inside a bunker slab after its roof
	# hit. Front-face collision then exposes terrain buried in that solid.
	# Trace the same vertical segment in both directions: an upward-facing
	# surface only visible from above is an exit from solid, not a ceiling.
	var low:=point+Vector3.UP*.15;var high:=point+Vector3.UP*40
	var ceiling: Dictionary=ai.navigation.ray(low,high)
	if not ceiling.is_empty():high=ceiling.position-Vector3.UP*.02
	var top: Dictionary=ai.navigation.ray(high,low)
	if not top.is_empty():return
	for index in nearby(point,2):
		if points[index].distance_to(point)<.5:return
	var index:=points.size();points.append(point);graph.add_point(index,point)
	var cell:=Vector2i(floori(point.x/SPACING),floori(point.z/SPACING))
	if not cells.has(cell):cells[cell]=[]
	cells[cell].append(index)
func nearby(point: Vector3,radius: int=2) -> Array:
	var result: Array=[];var cell:=Vector2i(floori(point.x/SPACING),floori(point.z/SPACING))
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):result.append_array(cells.get(cell+Vector2i(x,z),[]))
	return result
func clear(a: Vector3,b: Vector3) -> bool:
	var rise:=b.y-a.y
	if rise>17 or rise < -38:return false
	var height:=maxf(a.y,b.y)+1.3
	var high_a:=Vector3(a.x,height,a.z);var high_b:=Vector3(b.x,height,b.z)
	if not ai.navigation.ray(a+Vector3.UP*.3,high_a).is_empty():return false
	if not ai.navigation.ray(b+Vector3.UP*.3,high_b).is_empty():return false
	var side:=(high_b-high_a).normalized().cross(Vector3.UP)*.48
	for offset in [Vector3.ZERO,side,-side]:
		if not ai.navigation.ray(high_a+offset,high_b+offset).is_empty():return false
	return true
func build() -> void:
	if built:return
	built=true
	var pads=ai.game.match_mode.tribes.stations()
	if not pads:return
	# Use actual collision, including imported-map bounds, not a flat heightmap.
	var bounds: AABB=pads.playable_bounds
	if bounds.size==Vector3.ZERO:return
	var low:=bounds.position;var high:=bounds.end
	for x in range(ceili((low.x+3)/SPACING),floori((high.x-3)/SPACING)+1):
		for z in range(ceili((low.z+3)/SPACING),floori((high.z-3)/SPACING)+1):
			var cursor:=Vector3(x*SPACING,high.y-.1,z*SPACING)
			# Bridges and bunker roofs can cover a second traversable floor.
			# Sampling only the top made a skier below a bridge target its deck
			# vertically, burning jets against the underside on every replan.
			for layer in 4:
				var hit: Dictionary=ai.navigation.ray(cursor,Vector3(cursor.x,low.y+.1,cursor.z))
				if hit.is_empty():break
				if hit.normal.y>.35 and hit.position.y>low.y+.2:add(hit.position+Vector3.UP*.06)
				cursor=hit.position-Vector3.UP*.2
				if cursor.y<=low.y+.1:break
	for point in ai.game.spawn_points:add(point)
	for point in ai.game.match_mode.bases:add(point)
	for row in pads.rows:add(row.position)
	# Authored floor/doorway samples supplement vertical terrain probes, which
	# otherwise select a bunker roof. Edges still require real collision clearance.
	for point in pads.navigation_points:add(point)
	# Native Stonehenge inventory bunkers: upper door centres connect the
	# interior to terrain without selecting the roof above an indoor station.
	if pads.navigation_points.is_empty() and ai.game.current_map=="ctf_stonehenge":
		for row in pads.generators:
			var frame: Transform3D=row.frame;frame.origin=row.position+frame.basis.z*9
			for x in [-19.5,-14.0,0.0,14.0,19.5]:add(frame*Vector3(x,0,0))
			for z in [-17.0,-12.0,0.0,12.0,17.0]:add(frame*Vector3(0,0,z))
			add(row.position+row.frame.basis.z*3.8)
			add(row.repair_position)
	for i in points.size():
		if covered(points[i]):graph.covered[i]=true
		for j in nearby(points[i]):
			if i==j or points[i].distance_to(points[j])>27:continue
			if clear(points[i],points[j]):graph.connect_points(i,j,false)
	print("ST_ROUTES nodes=",points.size())
func covered(point: Vector3) -> bool:
	var key:=point.snapped(Vector3.ONE*.5)
	if not cover_cache.has(key):
		var hit: Dictionary=ai.navigation.ray(point+Vector3.UP*1.7,point+Vector3.UP*21)
		cover_cache[key]=not hit.is_empty() and hit.normal.y<-.5
	return cover_cache[key]
func attach(point: Vector3,arriving: bool=false) -> int:
	var best:=-1;var cost:=INF
	for i in nearby(point,3):
		var distance: float=point.distance_to(points[i])
		if distance>=cost or distance>45:continue
		if not (clear(points[i],point) if arriving else clear(point,points[i])):continue
		cost=distance;best=i
	return best
func path(start: Vector3,goal: Vector3,lane: int=0,avoid: Array=[],travel: Dictionary={}) -> PackedVector3Array:
	build()
	var from:=attach(start);var to:=attach(goal,true)
	if from<0 or to<0:return PackedVector3Array()
	# A destination connection has to be traversable in the arriving direction.
	if not clear(points[to],goal):return PackedVector3Array()
	# Soft, query-local costs keep a sole doorway usable. Only experienced
	# failed approaches supply these penalties; no hidden enemy positions.
	graph.costs.clear()
	# Alternative lanes share identical armour/energy costs. Memoize those
	# immutable edge calculations; failure penalties remain query-local.
	graph.prepare(travel)
	for note in avoid:
		if note.until<=ai.game.clock:continue
		for index in nearby(note.point,2):
			var distance: float=points[index].distance_to(note.point)
			if distance<22:graph.costs[index]=float(graph.costs.get(index,0))+80*(1-distance/22)
	var path:=graph.get_point_path(from,to)
	if path.is_empty():graph.costs.clear();graph.travel={};return path
	if lane!=0 and start.distance_to(goal)>220:
		# Split long flag runs across terrain corridors instead of feeding both
		# teams into the same midfield duel. The corridor is still a valid graph.
		var offset: Vector3=(goal-start).normalized().cross(Vector3.UP)*float(lane)*72
		var middle:=start.lerp(goal,.5)+offset
		var via:=graph.get_closest_point(middle)
		var first:=graph.get_point_path(from,via);var second:=graph.get_point_path(via,to)
		if not first.is_empty() and not second.is_empty() and route_length(first)+route_length(second)<route_length(path)*1.55:
			path=first;path.append_array(second)
	graph.costs.clear();graph.travel={}
	# A via point can lie on a spur shared by both halves. Erase that loop
	# rather than making a skier reverse down the same hill after visiting it.
	var simple:=PackedVector3Array()
	for point in path:
		var previous:=simple.find(point)
		if previous>=0:simple.resize(previous+1)
		else:simple.append(point)
	path=simple
	path.insert(0,start);path.append(goal)
	return path
func escape(start: Vector3,blocked: Vector3) -> Vector3:
	build()
	var away:=start-blocked;away.y=0
	if away.length()<1:away=Vector3.BACK
	away=away.normalized()
	var best:=Vector3.INF;var cost:=INF
	for index in nearby(start,2):
		var point: Vector3=points[index];var offset:=point-start
		if offset.length()<8 or offset.length()>26 or offset.y>3 or offset.y < -10 or not clear(start,point):continue
		var value: float=offset.length()-offset.normalized().dot(away)*15+maxf(0,offset.y)*3
		if value<cost:cost=value;best=point
	return best
func route_length(path: PackedVector3Array) -> float:
	var length:=0.0
	for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
	return length
