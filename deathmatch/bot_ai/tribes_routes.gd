extends RefCounted
## A terrain/portal graph complements the walking mesh. Edges describe real
## clear air corridors, never teleport or grant energy. See ST-CTF-RESEARCH.md.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)
class TerrainGraph extends AStar3D:
	var costs: Dictionary={}
	func _compute_cost(from_id: int,to_id: int) -> float:
		var a:=get_point_position(from_id);var b:=get_point_position(to_id)
		var climb:=maxf(0,b.y-a.y)
		return a.distance_to(b)+climb*1.8+maxf(0,climb-4)*3+float(costs.get(to_id,0))
var graph:=TerrainGraph.new()
var built:=false
var points:=PackedVector3Array()
var cells: Dictionary={}
const SPACING:=16.0

func add(point: Vector3) -> void:
	if not point.is_finite():return
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
		for j in nearby(points[i]):
			if i==j or points[i].distance_to(points[j])>27:continue
			if clear(points[i],points[j]):graph.connect_points(i,j,false)
	print("ST_ROUTES nodes=",points.size())
func attach(point: Vector3,arriving: bool=false) -> int:
	var best:=-1;var cost:=INF
	for i in nearby(point,3):
		var distance: float=point.distance_to(points[i])
		if distance>=cost or distance>45:continue
		if not (clear(points[i],point) if arriving else clear(point,points[i])):continue
		cost=distance;best=i
	return best
func path(start: Vector3,goal: Vector3,lane: int=0,avoid: Array=[]) -> PackedVector3Array:
	build()
	var from:=attach(start);var to:=attach(goal,true)
	if from<0 or to<0:return PackedVector3Array()
	# A destination connection has to be traversable in the arriving direction.
	if not clear(points[to],goal):return PackedVector3Array()
	# Soft, query-local costs keep a sole doorway usable. Only experienced
	# failed approaches supply these penalties; no hidden enemy positions.
	graph.costs.clear()
	for note in avoid:
		if note.until<=ai.game.clock:continue
		for index in nearby(note.point,2):
			var distance: float=points[index].distance_to(note.point)
			if distance<22:graph.costs[index]=float(graph.costs.get(index,0))+80*(1-distance/22)
	var path:=graph.get_point_path(from,to)
	if path.is_empty():graph.costs.clear();return path
	if lane!=0 and start.distance_to(goal)>220:
		# Split long flag runs across terrain corridors instead of feeding both
		# teams into the same midfield duel. The corridor is still a valid graph.
		var offset: Vector3=(goal-start).normalized().cross(Vector3.UP)*float(lane)*72
		var middle:=start.lerp(goal,.5)+offset
		var via:=graph.get_closest_point(middle)
		var first:=graph.get_point_path(from,via);var second:=graph.get_point_path(via,to)
		if not first.is_empty() and not second.is_empty() and route_length(first)+route_length(second)<route_length(path)*1.55:
			path=first;path.append_array(second)
	graph.costs.clear()
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
