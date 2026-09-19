extends SceneTree
const BASE="res://maps/Benchmark1km/"
const ID="prototype_km1"
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize():run.call_deferred()
func save_scene(level: Node,path: String) -> void:
	var packed:=PackedScene.new();assert(packed.pack(level)==OK);assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
func zones(level: Node3D,layout: Dictionary) -> Dictionary:
	for node in level.find_children("*","OccluderInstance3D",true,false):node.free()
	var originals:=level.find_children("*","MeshInstance3D",true,false)
	var triangles:=0;var chunks:=0
	for source in originals:
		if not source.mesh:continue
		for surface in source.mesh.get_surface_count():
			var a: Array=source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():indices=PackedInt32Array(range(vertices.size()))
			var tools: Dictionary={}
			for t in range(0,indices.size(),3):
				var center: Vector3=source.global_transform*((vertices[indices[t]]+vertices[indices[t+1]]+vertices[indices[t+2]])/3)
				var zone:=clampi(int(floor((center.x+500)/250)),0,3)+4*clampi(int(floor((center.z+500)/250)),0,3)
				if not tools.has(zone):
					var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(source.get_active_material(surface));tools[zone]=st
				var st: SurfaceTool=tools[zone]
				for corner in 3:
					var index:=indices[t+corner]
					if a[Mesh.ARRAY_NORMAL]!=null and not a[Mesh.ARRAY_NORMAL].is_empty():st.set_normal(source.global_basis*a[Mesh.ARRAY_NORMAL][index])
					if a[Mesh.ARRAY_TEX_UV]!=null and not a[Mesh.ARRAY_TEX_UV].is_empty():st.set_uv(a[Mesh.ARRAY_TEX_UV][index])
					if a[Mesh.ARRAY_TEX_UV2]!=null and not a[Mesh.ARRAY_TEX_UV2].is_empty():st.set_uv2(a[Mesh.ARRAY_TEX_UV2][index])
					if a[Mesh.ARRAY_COLOR]!=null and not a[Mesh.ARRAY_COLOR].is_empty():st.set_color(a[Mesh.ARRAY_COLOR][index])
					st.add_vertex(source.global_transform*vertices[index])
				triangles+=1
			for zone in tools:
				var node:=MeshInstance3D.new();node.name="Zone_%02d_Surface_%03d"%[zone,chunks];node.mesh=tools[zone].commit();node.cast_shadow=source.cast_shadow;level.add_child(node);node.owner=level;node.set_meta("occlusion_zone",zone);chunks+=1
		source.free()
	for i in layout.occluder_boxes.size():
		var row: Dictionary=layout.occluder_boxes[i];var lo:=Vector3(row.minimum[0],row.minimum[1],row.minimum[2]);var hi:=Vector3(row.maximum[0],row.maximum[1],row.maximum[2])
		var node:=OccluderInstance3D.new();var box:=BoxOccluder3D.new();box.size=(hi-lo-Vector3.ONE*.1).max(Vector3.ONE*.01);node.occluder=box
		node.name="SolidOccluder_%03d"%i;level.add_child(node);node.owner=level;node.position=(lo+hi)*.5
	return {"zones":16,"batches":chunks,"triangles":triangles,"occluders":layout.occluder_boxes.size(),"original_meshes":originals.size()}
func run() -> void:
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"layout.json"))
	var began:=Time.get_ticks_usec();var level:=Loader.read(BASE+ID+".bsp");assert(level!=null);root.add_child(level)
	preload("res://deathmatch/maps/filtering.gd").new().apply(level,2,true)
	assert(level.get_meta("baked_light_invalid_faces",0)==0)
	save_scene(level,BASE+"baseline-lightmap1.scn")
	var report:=zones(level,layout)
	for key in ["night_lighting","baked_light_dark_faces","baked_light_faces","baked_light_unlit_faces","baked_light_invalid_faces","baked_light_overflow_faces","baked_light_rgb"]:report[key]=level.get_meta(key,0)
	assert(level.get_meta("baked_light_overflow_faces",0)==0)
	if level.get_meta("night_lighting",false):assert(level.get_meta("baked_light_unlit_faces",0)==level.get_meta("baked_light_dark_faces",0))
	preload("res://tools/km_benchmark/city_art.gd").apply(level,layout)
	save_scene(level,BASE+"zones-lightmap1.scn")
	# The compiler adds an unused skip miptex; mirror the loader's versioned path.
	var replacements=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
	if replacements.has_missing(BASE+ID+".bsp"):save_scene(level,BASE+"zones-lightmap1-textures-"+replacements.version()+".scn")
	var resolved: Node=Loader.scene({"path":BASE+ID+".bsp","scene":BASE+"zones.scn"}).instantiate()
	assert(resolved.has_node("CityPresentation"),"Loader must resolve the decorated cache")
	resolved.free();report.decorated_cache_resolved=true
	report.prepare_ms=(Time.get_ticks_usec()-began)/1000.0
	var mesh:=preload("res://deathmatch/bots.gd").new_mesh(ID);mesh.cell_size=1.0;mesh.cell_height=.25;mesh.agent_radius=1.0;mesh.agent_height=1.75;mesh.edge_max_length=24;mesh.region_min_size=3;mesh.region_merge_size=10
	mesh.filter_baking_aabb=AABB(Vector3(-500,-1,-500),Vector3(1000,60,1000))
	var decoration:=level.get_node("CityPresentation");level.remove_child(decoration)
	var data:=NavigationMeshSourceGeometryData3D.new();NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	decoration.free()
	began=Time.get_ticks_usec();NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	assert(mesh.get_polygon_count()>0);mesh.set_meta("bsp_source_sha256",FileAccess.get_sha256(BASE+ID+".bsp"))
	DirAccess.make_dir_recursive_absolute("res://maps/navigation")
	assert(ResourceSaver.save(mesh,"res://maps/navigation/"+ID+".res")==OK)
	report.nav_ms=(Time.get_ticks_usec()-began)/1000.0;report.nav_polygons=mesh.get_polygon_count();report.cell_size=mesh.cell_size;report.cell_height=mesh.cell_height
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true);NavigationServer3D.map_set_cell_size(nav,mesh.cell_size);NavigationServer3D.map_set_cell_height(nav,mesh.cell_height)
	var region:=NavigationRegion3D.new();level.add_child(region);region.set_navigation_map(nav);region.navigation_mesh=mesh
	for frame in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav)>=2:break
	NavigationServer3D.map_set_active(region.get_navigation_map(),true);NavigationServer3D.map_force_update(region.get_navigation_map())
	var distances: Array=[]
	for row in layout.spawns:
		var point:=Vector3(row[0],row[1],row[2]);distances.append(point.distance_to(NavigationServer3D.map_get_closest_point(region.get_navigation_map(),point)))
	report.spawn_nav_distances=distances;assert(distances.all(func(d):return d<1.0))
	var path:=NavigationServer3D.map_get_path(region.get_navigation_map(),Vector3(-395,.1,-395),Vector3(395,.1,395),true)
	report.cross_map_path_points=path.size();assert(path.size()>1 and path[-1].distance_to(Vector3(395,.1,395))<1)
	report.connected_spawns=0;report.floor_rays=0
	for row in layout.spawns:
		var point:=Vector3(row[0],row[1],row[2]);var route:=NavigationServer3D.map_get_path(nav,Vector3(-395,.1,-395),point,true)
		assert(not route.is_empty() and route[-1].distance_to(point)<1);report.connected_spawns+=1
		var hit:=level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1))
		assert(not hit.is_empty() and hit.normal.y>.9);report.floor_rays+=1
	report.perimeter_rays=0
	for edge in [-1,1]:
		for axis in [0,2]:
			for along in [-375,-125,125,375]:
				var p:=Vector3(along,1.6,along);p[axis]=edge*498
				var end:=p;end[axis]=edge*503
				assert(not level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p,end,1)).is_empty())
				report.perimeter_rays+=1
	report.gate_clearance_rays=0
	for gate in layout.gates:
		var p:=Vector3(gate.position[0],1.6,gate.position[2]);var normal:=Vector3(gate.normal[0],0,gate.normal[2]);var side:=normal.cross(Vector3.UP)
		for offset in [-10,0,10]:
			var at: Vector3=p+side*offset
			var hit:=level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*4,at-normal*4,1))
			assert(hit.is_empty(),"Gate blocked: %s"%gate)
			report.gate_clearance_rays+=1
	DirAccess.make_dir_recursive_absolute("res://test-results/km-benchmark")
	FileAccess.open("res://test-results/km-benchmark/preparation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KM_PREPARED ",JSON.stringify(report));region.free();level.free();NavigationServer3D.free_rid(nav);quit()
