extends "res://deathmatch/bot_ai/navigation.gd"
## Keep native searches bounded to 4,096 polygons. Long journeys use the small
## authored road graph and replan short walkable legs instead of searching a
## million forest polygons for every bot decision.
const LEG_DISTANCE:=120.0
var map_source
var graph:=AStar3D.new()
var point_ids: Dictionary={}
var graph_ready:=false
func point_id(point: Vector2) -> int:
	var key:=Vector2i(roundi(point.x*100),roundi(point.y*100))
	if point_ids.has(key):return point_ids[key]
	var id:=point_ids.size();point_ids[key]=id
	graph.add_point(id,Vector3(point.x,map_source.Landscape.surface(point.x,point.y).x+.2,point.y))
	return id
func build_graph() -> void:
	map_source.Landscape.prepare_roads()
	var roads: Array=map_source.Landscape.main_roads
	var cuts: Array=[]
	for road in roads:
		cuts.append([{"t":0.0,"id":point_id(Vector2(road.a.x,road.a.z))},{"t":1.0,"id":point_id(Vector2(road.b.x,road.b.z))}])
	for i in roads.size():
		var a: Dictionary=roads[i]
		for j in range(i+1,roads.size()):
			var b: Dictionary=roads[j]
			var hit=Geometry2D.segment_intersects_segment(Vector2(a.a.x,a.a.z),Vector2(a.b.x,a.b.z),Vector2(b.a.x,b.a.z),Vector2(b.b.x,b.b.z))
			if hit==null:continue
			var id:=point_id(hit)
			cuts[i].append({"t":(hit-Vector2(a.a.x,a.a.z)).dot(a.delta)*a.inverse_length_squared,"id":id})
			cuts[j].append({"t":(hit-Vector2(b.a.x,b.a.z)).dot(b.delta)*b.inverse_length_squared,"id":id})
	for row in cuts:
		row.sort_custom(func(a,b):return a.t<b.t)
		for i in range(1,row.size()):
			if row[i-1].id!=row[i].id and not graph.are_points_connected(row[i-1].id,row[i].id):graph.connect_points(row[i-1].id,row[i].id)
	graph_ready=true
func path(start: Vector3,goal: Vector3,allow_jump: bool=true) -> PackedVector3Array:
	if start.distance_to(goal)<=LEG_DISTANCE:return super.path(start,goal,allow_jump)
	if not ready():return PackedVector3Array()
	if not graph_ready:build_graph()
	var ids:=graph.get_id_path(graph.get_closest_point(start),graph.get_closest_point(goal))
	if ids.is_empty():return PackedVector3Array()
	var waypoint:=graph.get_point_position(ids[0])
	for id in ids:
		var point:=graph.get_point_position(id)
		if point.distance_to(start)>LEG_DISTANCE:break
		waypoint=point
	if waypoint.distance_to(start)<2:waypoint=graph.get_point_position(ids[mini(1,ids.size()-1)])
	return super.path(start,waypoint,false)
