extends RefCounted
## Fine human-scale navigation baked in bounded chunks, following Godot's
## navigation_mesh_chunks demo: matching ghost borders and snapped seam vertices.
const SIDE:=230.4 # 768 cells at .3 metres
const BORDER:=3.0
static func cache_path(map) -> String:
	var version:=FileAccess.get_sha256("res://tools/voxel_battle/jungle_navigation.gd")+FileAccess.get_sha256("res://tools/voxel_battle/map.gd")
	for source in preload("res://tools/voxel_battle/rock_cover.gd").sources():version+=FileAccess.get_sha256(source)
	return map.collision_cache_path().replace("heightmap","navigation-chunks").replace(".res","-%s.scn"%version.sha256_text().left(8))
static func build(map) -> Node3D:
	var path:=cache_path(map)
	if FileAccess.file_exists(path):return load(path).instantiate()
	var root:=Node3D.new();root.name="JungleNavigation"
	var heights: PackedFloat32Array=map.terrain_collision().map_data
	var pending: Array=[]
	var meshes: Array=[]
	var span:=ceili(map.LIMIT/SIDE)
	for z in range(-span,span):
		for x in range(-span,span):
			var nav:=preload("res://deathmatch/bots.gd").new_mesh("voxel_jungle")
			var bounds:=AABB(Vector3(x*SIDE,map.Landscape.MIN_HEIGHT,z*SIDE),Vector3(SIDE,map.Landscape.MAX_HEIGHT-map.Landscape.MIN_HEIGHT,SIDE))
			# Power-of-two cell count survives the engine's float32 property
			# conversion exactly; ten cells can round just above ten and ceil to eleven.
			nav.border_size=nav.cell_size*16
			nav.filter_baking_aabb=bounds.grow(nav.border_size)
			var source=map.navigation_source_chunk(nav.filter_baking_aabb,heights)
			NavigationServer3D.bake_from_source_geometry_data_async(nav,source)
			pending.append(nav);meshes.append(nav)
			while pending.size()>=2:
				for i in range(pending.size()-1,-1,-1):
					if not NavigationServer3D.is_baking_navigation_mesh(pending[i]):pending.remove_at(i)
				if pending.size()>=2:await map.get_tree().process_frame
		print("JUNGLE_NAV row ",z," / ",span-1)
	while not pending.is_empty():
		for i in range(pending.size()-1,-1,-1):
			if not NavigationServer3D.is_baking_navigation_mesh(pending[i]):pending.remove_at(i)
		if not pending.is_empty():await map.get_tree().process_frame
	for nav in meshes:
		nav.filter_baking_aabb=AABB()
		var vertices: PackedVector3Array=nav.get_vertices()
		for i in vertices.size():vertices[i]=vertices[i].snappedf(.0003)
		nav.set_vertices(vertices)
		var region:=NavigationRegion3D.new();region.navigation_mesh=nav;root.add_child(region);region.owner=root
	root.set_meta("chunks",meshes.size())
	connect_road_seams(root,map)
	var packed:=PackedScene.new();assert(packed.pack(root)==OK);assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
	return root

static func connect_road_seams(root: Node3D,map) -> void:
	# Explicit walk links on clear roads avoid a global edge-margin search among
	# a million forest polygons. Physics remains continuous across these seams.
	var links:=0
	for road in map.Landscape.main_roads:
		for axis in [0,2]:
			var change: float=road.b[axis]-road.a[axis]
			if absf(change)<.001:continue
			var lo:=ceili(minf(road.a[axis],road.b[axis])/SIDE)
			var hi:=floori(maxf(road.a[axis],road.b[axis])/SIDE)
			for boundary in range(lo,hi+1):
				var t: float=(boundary*SIDE-road.a[axis])/change
				if t<0 or t>1:continue
				var center: Vector3=road.a.lerp(road.b,t)
				# Three crossings cover both sides of a road at a chunk corner.
				# Endpoints stay off the other seam, avoiding ambiguous projection.
				var normal:=Vector3(1,0,0) if axis==0 else Vector3(0,0,1)
				var tangent:=Vector3(0,0,1) if axis==0 else Vector3(1,0,0)
				for offset in [-3.0,0.0,3.0]:
					var a: Vector3=center+tangent*offset-normal*.9;var b: Vector3=center+tangent*offset+normal*.9
					a.y=map.Landscape.surface(a.x,a.z).x+.2;b.y=map.Landscape.surface(b.x,b.z).x+.2
					var link:=NavigationLink3D.new();link.start_position=a;link.end_position=b;link.bidirectional=true
					root.add_child(link);link.owner=root;links+=1

	root.set_meta("seam_links",links)
