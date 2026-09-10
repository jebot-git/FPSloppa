extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var world: Node3D
var space: PhysicsDirectSpaceState3D
var raw: PackedByteArray
var lumps: Array=[]
var extended:=false
var report: Dictionary={}
func _initialize():call_deferred("run")
func fluid(pos: Vector3) -> bool:
	var q:=Vector3(-pos.z,-pos.x,pos.y)*32
	var node: int=raw.decode_s32(lumps[14].x+36)
	for i in 2048:
		if node<0:
			var leaf: int=lumps[10].x+(-1-node)*(44 if extended else 28)
			return raw.decode_s32(leaf) in [-2,-3,-4,-5,-6]
		var at: int=lumps[5].x+node*(44 if extended else 24)
		var plane: int=lumps[1].x+raw.decode_s32(at)*20
		var normal:=Vector3(raw.decode_float(plane),raw.decode_float(plane+4),raw.decode_float(plane+8))
		var child:=0 if normal.dot(q)>=raw.decode_float(plane+12) else 1
		node=raw.decode_s32(at+4+child*4) if extended else raw.decode_s16(at+4+child*2)
	return true
func floor_at(pos: Vector3) -> Variant:
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*1.0,pos-Vector3.UP*5.0,1))
	if hit.is_empty() or hit.normal.y<.7:return null
	var foot: Vector3=hit.position+Vector3.UP*.03
	if fluid(foot+Vector3.UP*.1):return null
	var shape:=CapsuleShape3D.new();shape.radius=.4;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=foot+Vector3.UP*.88;query.collision_mask=1;query.margin=.005
	if not space.intersect_shape(query,1).is_empty():return null
	return foot
func route(nav: RID,a: Vector3,b: Vector3) -> PackedVector3Array:
	var path:=NavigationServer3D.map_get_path(nav,a,b,true)
	return path if path.size()>1 and path[-1].distance_to(b)<1.2 else PackedVector3Array()
func distance(path: PackedVector3Array) -> float:
	var result:=0.0
	for i in range(1,path.size()):result+=path[i-1].distance_to(path[i])
	return result
func finish(path: String,ok: bool) -> void:
	report.passed=ok
	var file:=FileAccess.open(path.get_basename()+"-layout.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("AD_LAYOUT_RESULT ",JSON.stringify(report));world.free();await process_frame;quit(0 if ok else 1)
func run() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	report={"id":path.get_file().get_basename(),"errors":[],"spawns":[],"goals":[],"pickups":[]}
	world=Node3D.new();root.add_child(world)
	var error:=Maps.validate(path)
	if not error.is_empty():report.errors.append(error);await finish(path,false);return
	raw=FileAccess.get_file_as_bytes(path);extended=raw.decode_u32(0)!=29
	for i in 15:lumps.append(Vector2i(raw.decode_u32(4+i*8),raw.decode_u32(8+i*8)))
	var level:=Maps.read(path)
	if not level:report.errors.append("Importer failed");await finish(path,false);return
	world.add_child(level)
	for node in level.get_children():
		if "attributes" in node and node.attributes.get("classname","")=="func_illusionary" and node is CollisionObject3D:node.collision_layer=0
	await physics_frame;await physics_frame
	space=world.get_world_3d().direct_space_state
	report.meshes=0;report.triangles=0;report.invalid_triangles=0
	for node in level.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		report.meshes+=1
		var faces: PackedVector3Array=node.mesh.get_faces();report.triangles+=faces.size()/3
		for i in range(0,faces.size(),3):
			if not faces[i].is_finite() or not faces[i+1].is_finite() or not faces[i+2].is_finite() or (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<1e-14:report.invalid_triangles+=1;print("DEGENERATE ",node.name," ",faces.slice(i,i+3)," area ",(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared())
	report.baked_faces=level.get_meta("baked_light_faces",0);report.rgb=level.get_meta("baked_light_rgb",false)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_basename()+".json"))
	var candidates: Array=[]
	var count:=0
	for p in data.points:
		count+=1
		if data.points.size()>500 and count%ceili(float(data.points.size())/500)!=0:continue
		var value=floor_at(Vector3(-p[1],p[2],-p[0])/32.0)
		if value!=null and not candidates.any(func(v):return v.distance_to(value)<2.0):candidates.append(value)
	report.clear_candidates=candidates.size()
	if candidates.size()<8:report.errors.append("Fewer than eight dry capsule-clear positions");await finish(path,false);return
	var mesh:=preload("res://deathmatch/bots.gd").new_mesh()
	mesh.cell_size=.25
	var source:=NavigationMeshSourceGeometryData3D.new();NavigationServer3D.parse_source_geometry_data(mesh,source,level)
	NavigationServer3D.bake_from_source_geometry_data(mesh,source)
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true)
	NavigationServer3D.map_set_cell_size(nav,mesh.cell_size)
	NavigationServer3D.map_set_use_edge_connections(nav,false)
	if NavigationServer3D.has_method("map_set_merge_rasterizer_cell_scale"):NavigationServer3D.call("map_set_merge_rasterizer_cell_scale",nav,.1)
	var region:=NavigationRegion3D.new();region.navigation_mesh=mesh;world.add_child(region);region.set_navigation_map(nav)
	NavigationServer3D.map_force_update(nav);await physics_frame;await physics_frame
	for attempt in 100:
		if NavigationServer3D.map_get_iteration_id(nav)>0 and NavigationServer3D.map_get_closest_point(nav,candidates[0]).distance_to(candidates[0])<2:break
		await create_timer(.02).timeout
	report.nav_polygons=mesh.get_polygon_count()
	print("NAV_DEBUG ",NavigationServer3D.map_get_regions(nav)," first ",candidates[0]," near ",NavigationServer3D.map_get_closest_point(nav,candidates[0])," vertex ",mesh.get_vertices()[0])
	var points: Array=[]
	for p in candidates:
		var near:=NavigationServer3D.map_get_closest_point(nav,p)
		if near.distance_to(p)<1.0:points.append(p)
	var best: Array=[];var remaining:=points.duplicate()
	while not remaining.is_empty():
		var seed: Vector3=remaining.pop_front();var group: Array=[seed]
		for p in remaining:
			if not route(nav,seed,p).is_empty() and not route(nav,p,seed).is_empty():group.append(p)
		if group.size()>best.size():best=group
		for p in group:remaining.erase(p)
		if best.size()>=remaining.size():break
	report.connected_candidates=best.size()
	if best.size()<8:report.errors.append("No connected component with eight clear positions");NavigationServer3D.free_rid(nav);await finish(path,false);return
	# Farthest-point sampling spreads spawns over one navigable component.
	var selected: Array=[best[0]]
	while selected.size()<mini(16,best.size()):
		var next:=Vector3.ZERO;var largest:=-1.0
		for p: Vector3 in best:
			var closest:=INF
			for s: Vector3 in selected:closest=minf(closest,p.distance_to(s))
			if closest>largest:largest=closest;next=p
		if largest<2.0:break
		selected.append(next)
	var a: Vector3=selected[0];var b: Vector3=selected[1];var longest:=0.0
	for p: Vector3 in selected:
		for q: Vector3 in selected:
			var length:=distance(route(nav,p,q))
			if length>longest:longest=length;a=p;b=q
	var between:=route(nav,a,b);var middle: Vector3=between[between.size()/2]
	var hill: Vector3=selected[0]
	for p: Vector3 in selected:
		if p.distance_to(middle)<hill.distance_to(middle):hill=p
	report.route_checks=0;report.max_route_m=longest
	for p in selected:
		for q in selected:
			if p==q:continue
			report.route_checks+=1
			if route(nav,p,q).is_empty():report.errors.append("Disconnected selected spawn")
	report.spawn_yaws=[]
	for p: Vector3 in selected:
		report.spawns.append([p.x,p.y,p.z])
		var yaw:=0.0;var best_view:=-1.0
		for step in 16:
			var angle:=TAU*step/16;var score:=0.0
			for spread in [-.25,0.0,.25]:
				var direction:=Vector3(-sin(angle+spread),0,-cos(angle+spread));var eye:=p+Vector3.UP*1.5
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*24,1))
				score+=24.0 if hit.is_empty() else eye.distance_to(hit.position)
			if score>best_view:best_view=score;yaw=rad_to_deg(angle)
		report.spawn_yaws.append(yaw)
	for p: Vector3 in [a,b,hill]:report.goals.append([p.x,p.y,p.z])
	for p: Vector3 in best:
		if report.pickups.size()>=32:break
		if selected.any(func(s):return s.distance_to(p)<1):continue
		report.pickups.append([p.x,p.y,p.z])
	# Small hubs may have fewer original entities than our spawn budget. Probe
	# nearby dry floor for separate pickup locations instead of spawn camping items.
	if report.pickups.size()<8:
		for seed: Vector3 in best:
			for offset in [Vector3(1.5,0,0),Vector3(-1.5,0,0),Vector3(0,0,1.5),Vector3(0,0,-1.5)]:
				var value=floor_at(seed+offset)
				if value==null or selected.any(func(s):return s.distance_to(value)<1.1):continue
				if report.pickups.any(func(p):return Vector3(p[0],p[1],p[2]).distance_to(value)<1.5):continue
				if route(nav,selected[0],value).is_empty() or route(nav,value,selected[0]).is_empty():continue
				report.pickups.append([value.x,value.y,value.z])
				if report.pickups.size()>=16:break
			if report.pickups.size()>=16:break
	report.modes=["dm","tdm","ig","ft"]
	if longest<180:report.modes.append("koth")
	if longest<90:report.modes.append("cc")
	# Asymmetric single-player layouts are experimental for flag modes, not balanced originals.
	if longest>=25 and longest<250:report.modes.append_array(["ctf","tf"])
	var nav_path:=path.get_basename()+"-navigation.res";ResourceSaver.save(mesh,nav_path)
	NavigationServer3D.free_rid(nav)
	await finish(path,report.errors.is_empty() and report.invalid_triangles==0)
