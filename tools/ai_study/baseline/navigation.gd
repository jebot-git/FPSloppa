extends RefCounted
## Route queries are bounded by the brain's planning cadence. Links describe real
## map mechanics; traversing them still requires the normal trigger/physics code.
var game
var region: NavigationRegion3D
var links: Array[Dictionary]=[]
var installed:=false
var jump_candidates: Array[Vector3]=[]
var jump_cursor:=0
var jump_links:=0
func setup(arena,nav_region: NavigationRegion3D) -> void:
	game=arena;region=nav_region
func ready() -> bool:
	return region.navigation_mesh!=null and NavigationServer3D.region_get_iteration_id(region.get_rid())>0
func project_local(point: Vector3) -> Vector3:
	if not ready():return point
	var projected:=NavigationServer3D.map_get_closest_point(region.get_navigation_map(),point)
	return projected if projected.distance_to(point)<=2.0 else point
func ray(a: Vector3,b: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func path(start: Vector3,goal: Vector3,allow_jump: bool=true) -> PackedVector3Array:
	if not ready():return PackedVector3Array()
	# Never project a distant island/test arena onto an unrelated part of the map.
	var map:=region.get_navigation_map()
	if NavigationServer3D.map_get_closest_point(map,start).distance_to(start)>2.5:return PackedVector3Array()
	var result:=NavigationServer3D.map_get_path(map,start,goal,true,3 if allow_jump else 1)
	if result.is_empty() or result[-1].distance_to(goal)>2.0:return PackedVector3Array()
	return result
func cost(start: Vector3,goal: Vector3,route: PackedVector3Array) -> float:
	if route.is_empty():
		return start.distance_to(goal) if absf(start.y-goal.y)<1.0 and ray(start+Vector3.UP*.8,goal+Vector3.UP*.8).is_empty() else INF
	var result:=0.0
	var previous:=start
	for point in route:
		var distance:=previous.distance_to(point)
		for link in links:
			if previous.distance_to(link.start)<1.0 and point.distance_to(link.end)<1.0:
				distance=link.cost;break
		result+=distance;previous=point
	return result+previous.distance_to(goal)
func install_links() -> void:
	if installed or not ready():return
	installed=true
	queue_jump_links()
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime==null:return
	for volume in runtime.regions:
		if not volume.kind in ["trigger_teleport","trigger_push"]:continue
		var bounds: AABB=runtime.node_bounds(volume.area)
		var start:=bounds.get_center();start.y=bounds.position.y+.1
		var end:=start
		var kind: String=volume.kind
		if kind=="trigger_teleport":
			var destination: Dictionary=runtime.destinations.get(volume.data.get("target",""),{})
			if destination.is_empty():continue
			end=destination.position
		else:
			var velocity: Vector3=runtime.push_velocity(volume.data,1.0 if runtime.legacy_train_push else 10.0)
			if velocity.y>10 and Vector2(velocity.x,velocity.z).length()<1:
				vertical_pad_links(start,velocity.y)
				continue
			var previous:=start+Vector3.UP*.5
			var landed:=false
			for step in range(1,81):
				var t:=step*.05
				var point:=start+Vector3.UP*.5+velocity*t+Vector3.DOWN*10*t*t
				var hit:=ray(previous,point)
				if not hit.is_empty():
					if hit.normal.y>.7 and velocity.y-20*t<0:end=hit.position;landed=true
					break
				previous=point
			if not landed:continue
		var map:=region.get_navigation_map()
		var entry:=NavigationServer3D.map_get_closest_point(map,start)
		var exit_point:=NavigationServer3D.map_get_closest_point(map,end)
		if entry.distance_to(start)>2 or exit_point.distance_to(end)>2:continue
		var link:=NavigationLink3D.new()
		link.bidirectional=false;link.start_position=entry;link.end_position=exit_point
		link.travel_cost=0.0 if kind=="trigger_teleport" else .5;link.enter_cost=1.0
		region.add_child(link)
		links.append({"start":entry,"end":exit_point,"entry":start,"kind":kind,"cost":1.0 if kind=="trigger_teleport" else entry.distance_to(exit_point)*.5+1})
	for lift in game.lifts:
		var bounds: AABB=runtime.node_bounds(lift.node)
		if bounds.size.is_zero_approx():continue
		var start:=bounds.get_center();start.y=bounds.end.y-(lift.node.position.y-lift.base)
		var end:=start+Vector3.UP*float(lift.get("travel",1.65))
		var map:=region.get_navigation_map()
		var entry:=NavigationServer3D.map_get_closest_point(map,start)
		var exit_point:=NavigationServer3D.map_get_closest_point(map,end)
		if entry.distance_to(start)>2.0 or exit_point.distance_to(end)>2.0 or exit_point.y-entry.y<.8:continue
		var link:=NavigationLink3D.new();link.bidirectional=false
		link.start_position=entry;link.end_position=exit_point;link.enter_cost=18;region.add_child(link)
		links.append({"start":entry,"end":exit_point,"entry":start,"kind":"lift","lift":lift,"cost":18+start.distance_to(end)})
func vertical_pad_links(start: Vector3,up_speed: float) -> void:
	# Vertical pads need air steering onto nearby roofs. A straight ballistic ray
	# otherwise lands back on the pad and leaves the upper nav island unreachable.
	var map:=region.get_navigation_map()
	var entry:=NavigationServer3D.map_get_closest_point(map,start)
	if entry.distance_to(start)>2:return
	var destinations: Array[Vector3]=[]
	for height in [2.0,4.5,7.0,10.0]:
		if height>up_speed*up_speed/40-.5:continue
		for index in 8:
			var angle:=TAU*index/8.0
			var probe:=start+Vector3(cos(angle)*4,height,sin(angle)*4)
			var end:=NavigationServer3D.map_get_closest_point(map,probe)
			if end.y<start.y+1.2 or end.distance_to(probe)>2 or hazardous(end):continue
			if destinations.any(func(point):return point.distance_to(end)<2):continue
			if not pad_arc_clear(start,end,up_speed):continue
			var link:=NavigationLink3D.new();link.bidirectional=false
			link.start_position=entry;link.end_position=end;link.enter_cost=3;region.add_child(link)
			links.append({"start":entry,"end":end,"entry":start,"kind":"pad","cost":8+start.distance_to(end)})
			destinations.append(end)
			if destinations.size()>=6:return
func pad_arc_clear(start: Vector3,end: Vector3,up_speed: float) -> bool:
	var rise:=end.y-start.y
	var discriminant:=up_speed*up_speed-40*(rise+.35)
	if discriminant<=0:return false
	var delay: float=(up_speed-sqrt(discriminant))/20
	var duration: float=(up_speed+sqrt(up_speed*up_speed-40*rise))/20
	if Vector2(end.x-start.x,end.z-start.z).length()>(duration-delay)*5:return false
	var capsule:=CapsuleShape3D.new();capsule.radius=.33;capsule.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	for index in range(1,25):
		var t:=duration*index/25.0
		var point:=start.lerp(end,clampf((t-delay)/(duration-delay),0,1));point.y=start.y+up_speed*t-10*t*t
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.85)
		if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func active_link(position: Vector3,next: Vector3) -> Dictionary:
	for link in links:
		if next.distance_to(link.end)>=1.0:continue
		if position.distance_to(link.start)<2.0:return link
		if link.kind=="lift" and Vector2(position.x-link.start.x,position.z-link.start.z).length()<2 and position.y>=link.start.y-.5 and position.y<link.end.y+.1:return link
	return {}
func hazardous(point: Vector3) -> bool:
	if point.y<game.fall_limit+1:return true
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime==null:return false
	for volume in runtime.regions:
		if volume.kind in ["trigger_hurt","slime","lava"] and runtime.node_bounds(volume.area).grow(.35).has_point(point):return true
	return false

func landing_clear(point: Vector3) -> bool:
	# Leave a little more wall clearance than the teleport system's minimum
	# capsule so the bot can actually walk away from its landing.
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.89)
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func jump_clear(start: Vector3,end: Vector3,speed: float=6.0) -> bool:
	# Conservative hull samples for an ordinary jump, valid even for slow TF
	# classes. No movement/teleport is applied by the planner.
	var distance:=Vector2(end.x-start.x,end.z-start.z).length()
	if distance>4.8 or end.y-start.y>1.0 or end.y-start.y< -6.5:return false
	var duration: float=(7.4+sqrt(maxf(0,7.4*7.4-40*(end.y-start.y))))/20.0
	if distance>duration*speed:return false
	var capsule:=CapsuleShape3D.new();capsule.radius=.31;capsule.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	for index in range(1,9):
		var t:=duration*index/9.0
		var point:=start.lerp(end,t/duration);point.y=start.y+7.4*t-10*t*t
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.85)
		if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func drop_clear(start: Vector3,end: Vector3) -> bool:
	var height:=start.y-end.y
	if height<1.4 or height>6.5:return false
	var duration:=sqrt(height/10)+.2
	if Vector2(end.x-start.x,end.z-start.z).length()>duration*6:return false
	var capsule:=CapsuleShape3D.new();capsule.radius=.33;capsule.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	for index in range(1,17):
		var t:=duration*index/17.0
		var point:=start.lerp(end,t/duration);point.y=start.y-10*pow(maxf(0,t-.2),2)
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.85)
		if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func queue_jump_links() -> void:
	# Boundary midpoints expose ledges and separated platforms that a walking
	# navmesh cannot connect. Sample evenly and build a few queries per frame.
	var mesh:=region.navigation_mesh
	var vertices:=mesh.get_vertices()
	var edges: Dictionary={}
	for polygon in mesh.get_polygon_count():
		var indices:=mesh.get_polygon(polygon)
		for index in indices.size():
			var a:=indices[index];var b:=indices[(index+1)%indices.size()]
			var key:=Vector2i(mini(a,b),maxi(a,b))
			edges[key]=int(edges.get(key,0))+1
	var boundary: Array[Vector3]=[]
	for key in edges:
		if edges[key]==1:boundary.append((vertices[key.x]+vertices[key.y])*.5)
	# Prioritize edges near mandatory objectives before uniform map sampling;
	# small roof hatches otherwise disappear between samples on long BSPs.
	if game.match_mode.kind=="as":
		var nearby: Array[Vector3]=[]
		for point in boundary:
			for objective in game.match_mode.assault.objectives:
				if point.distance_to(objective.position)<10:nearby.append(point);break
		nearby.sort_custom(func(a,b):
			var da:=INF;var db:=INF
			for objective in game.match_mode.assault.objectives:
				da=minf(da,a.distance_to(objective.position));db=minf(db,b.distance_to(objective.position))
			return da<db)
		for index in mini(128,nearby.size()):jump_candidates.append(nearby[index])
	var stride:=maxi(1,ceili(boundary.size()/(512.0 if game.match_mode.kind=="as" else 128.0)))
	for index in range(0,boundary.size(),stride):jump_candidates.append(boundary[index])
func update_jump_links() -> void:
	if not ready() or jump_links>=96:return
	for work in 2:
		if jump_cursor>=jump_candidates.size()*8:return
		var start:=jump_candidates[jump_cursor/8]
		var angle:=TAU*float(jump_cursor%8)/8.0
		jump_cursor+=1
		var probe:=start+Vector3(cos(angle),0,sin(angle))*3.5
		var end:=NavigationServer3D.map_get_closest_point(region.get_navigation_map(),probe)
		# A lower platform can be hidden from a nearest-point query by the
		# ledge we are standing on. Probe real ground below an exposed boundary.
		var landing:=ray(probe+Vector3.UP*.3,probe-Vector3.UP*6.5)
		if not landing.is_empty() and landing.normal.y>.7 and start.y-landing.position.y>1.4:
			var lower:=NavigationServer3D.map_get_closest_point(region.get_navigation_map(),landing.position)
			if lower.distance_to(landing.position)<.6:end=lower
		var distance:=start.distance_to(end)
		var horizontal:=Vector2(end.x-start.x,end.z-start.z).length()
		if horizontal<1.5 or horizontal>4.2 or Vector2(end.x-probe.x,end.z-probe.z).length()>1.5 or end.y-start.y>1 or start.y-end.y>6.5 or hazardous(end):continue
		if links.any(func(link):return start.distance_to(link.start)<1.5 and end.distance_to(link.end)<1.5):continue
		var dropping: bool=start.y-end.y>1.4
		if not (drop_clear(start,end) if dropping else jump_clear(start,end)):continue
		var walking:=path(start,end)
		if not walking.is_empty() and cost(start,end,walking)<distance*1.8:continue
		var link:=NavigationLink3D.new();link.bidirectional=false
		link.start_position=start;link.end_position=end;link.enter_cost=2;link.travel_cost=1.1;link.navigation_layers=2
		region.add_child(link)
		links.append({"start":start,"end":end,"entry":start,"kind":"drop" if dropping else "jump","cost":distance*1.1+2})
		jump_links+=1
