extends SceneTree
func _initialize():run.call_deferred()
func v(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])
func run():
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Cindercoil/probes.json"))
	var mesh: NavigationMesh=load("res://maps/navigation/tb_cindercoil.res")
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true);NavigationServer3D.map_set_cell_size(nav,mesh.cell_size);NavigationServer3D.map_set_cell_height(nav,mesh.cell_height)
	var region:=NavigationRegion3D.new();root.add_child(region);region.set_navigation_map(nav);region.navigation_mesh=mesh
	for i in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav)>=2:break
	NavigationServer3D.map_force_update(nav)
	var rows: Array=[]
	for i in probes.tunnels.size():
		for j in range(i+1,probes.tunnels.size()):
			var a: Dictionary=probes.tunnels[i];var b: Dictionary=probes.tunnels[j]
			var path:=NavigationServer3D.map_get_path(nav,v(a.entry),v(b.entry),true);var distance:=0.0
			assert(path.size()>1 and path[-1].distance_to(v(b.entry))<1)
			for step in range(1,path.size()):distance+=path[step-1].distance_to(path[step])
			var road: float=absf(a.distance-b.distance)
			if road>150:assert(distance<road*.65)
			rows.append({"from_route_m":a.distance,"to_route_m":b.distance,"road_route_m":road,"walking_path_m":distance,"saved_m":road-distance,"path":Array(path).map(func(p):return [p.x,p.y,p.z])})
	FileAccess.open("res://test-results/cindercoil/shortcuts.json",FileAccess.WRITE).store_string(JSON.stringify({"sha256":FileAccess.get_sha256("res://maps/tb_cindercoil.bsp"),"pairs":rows,"passed":true},"  "))
	print("CINDERCOIL_SHORTCUTS_PASS ",rows.map(func(r):return [r.from_route_m,r.to_route_m,r.walking_path_m]))
	region.free();NavigationServer3D.free_rid(nav);quit()
