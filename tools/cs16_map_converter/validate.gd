extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Layout=preload("res://deathmatch/modes/defusal_maps.gd")
const Doors=preload("res://deathmatch/maps/de_navigation.gd")
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():printerr("Expected converted BSP path");quit(1);return
	var path:=args[0]
	var error:=Loader.validate(path)
	check(error.is_empty(),"BSP validation: "+error)
	if not error.is_empty():quit(1);return
	var layout:=Layout.register_map(path,FileAccess.get_sha256(path))
	check(not layout.is_empty(),"Embedded DE layout")
	if layout.is_empty():quit(1);return
	var level:=Loader.read(path)
	check(level!=null,"BSP scene import")
	if not level:quit(1);return
	root.add_child(level)
	check(int(level.get_meta("baked_light_invalid_faces",0))==0 and int(level.get_meta("baked_light_overflow_faces",0))==0,"Lightmap offsets and atlas budget")
	await physics_frame;await physics_frame
	var points: Array=layout.sites+layout.starts[0]+layout.starts[1]
	var space:=level.get_world_3d().direct_space_state
	for i in points.size():
		var p:=Layout.vector(points[i])
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*.25,1))
		check(not hit.is_empty(),"Point %d has supporting floor"%i)
		var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=1.65
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=p+Vector3.UP*.84
		check(space.intersect_shape(query).is_empty(),"Point %d has standing clearance"%i)
	var mesh:=preload("res://deathmatch/bots.gd").new_mesh()
	var data:=NavigationMeshSourceGeometryData3D.new()
	var doors:=Doors.open_for_navigation(level)
	NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	Doors.restore(doors)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	check(mesh.get_polygon_count()>0,"Bot navigation baked")
	var region:=NavigationRegion3D.new();level.add_child(region);region.navigation_mesh=mesh
	var map:=region.get_navigation_map();NavigationServer3D.map_set_cell_size(map,mesh.cell_size)
	NavigationServer3D.map_set_active(map,true)
	for frame in 120:
		await physics_frame
		NavigationServer3D.map_force_update(map)
		if NavigationServer3D.region_get_iteration_id(region.get_region_rid())>0 and NavigationServer3D.map_get_iteration_id(map)>1:break
	print("CS_MAP_NAV ",JSON.stringify({"polygons":mesh.get_polygon_count(),"vertices":mesh.get_vertices().size(),"active":NavigationServer3D.map_is_active(map),"regions":NavigationServer3D.map_get_regions(map).size(),"iteration":NavigationServer3D.map_get_iteration_id(map)}))
	for role in 2:
		for raw in layout.starts[role]:
			var start:=Layout.vector(raw)
			for site in layout.sites:
				var target:=Layout.vector(site)
				var route:=NavigationServer3D.map_get_path(map,start,target,true)
				if route.is_empty():print("CS_MAP_NAV_EMPTY ",start," -> ",target)
				check(not route.is_empty() and route[0].distance_to(start)<1 and route[-1].distance_to(target)<1,"Role %d spawn can route to site %s"%[role,target])
	# Verify imported colour textures use mipmaps; sky/utility surfaces have no material.
	for instance in level.find_children("*","MeshInstance3D",true,false):
		for s in instance.mesh.get_surface_count():
			var material=instance.mesh.surface_get_material(s)
			var texture=material.albedo_texture if material is BaseMaterial3D else material.get_shader_parameter("base_texture") if material is ShaderMaterial else null
			if texture is Texture2D:check(texture.get_image().has_mipmaps(),"Texture mipmaps")
	print("CS_MAP_VALIDATION_PASS" if failures.is_empty() else "CS_MAP_VALIDATION_FAIL "+JSON.stringify(failures))
	level.free();quit(0 if failures.is_empty() else 1)
