extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var region:=NavigationRegion3D.new();world.add_child(region)
	var map:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(map,true);NavigationServer3D.map_set_cell_size(map,.2)
	region.set_navigation_map(map)
	var mesh:=NavigationMesh.new();mesh.cell_size=.2
	mesh.vertices=PackedVector3Array([Vector3(100,100,100),Vector3(0,0,0),Vector3(2,0,0),Vector3(2,0,10),Vector3(0,0,10),Vector3(0,0,12),Vector3(2,0,12),Vector3(8,0,10),Vector3(8,0,12),Vector3(8,0,0),Vector3(10,0,0),Vector3(10,0,10),Vector3(10,0,12)])
	for indices in [[0,1,2,3],[3,2,5,4],[2,6,7,5],[8,9,10,6],[6,10,11,7]]:mesh.add_polygon(PackedInt32Array(indices.map(func(index):return index+1)))
	region.navigation_mesh=mesh
	for frame in 4:await physics_frame
	var nav=preload("res://deathmatch/bot_ai/navigation.gd").new();nav.region=region
	check(nav.ready(),"Unused off-mesh vertices do not prevent navigation readiness")
	var start:=Vector3(1,0,1);var end:=Vector3(9,0,1)
	var walking: PackedVector3Array=nav.path(start,end)
	check(walking.size()>2 and nav.cost(start,end,walking)>20,"Route follows a U-shaped corridor instead of crossing its solid center")
	check(nav.path(start,Vector3(30,0,30)).is_empty(),"Unreachable endpoint is rejected instead of projecting onto an unrelated ledge")
	var link:=NavigationLink3D.new();link.bidirectional=false;link.navigation_layers=2;link.start_position=Vector3(2,0,1);link.end_position=Vector3(8,0,1);link.enter_cost=1;region.add_child(link);link.set_navigation_map(map)
	for frame in 4:await physics_frame
	var shortcut: PackedVector3Array=nav.path(start,end,true)
	var restricted: PackedVector3Array=nav.path(start,end,false)
	check(nav.cost(start,end,shortcut)<nav.cost(start,end,restricted)-8,"Movement link provides a shorter route only to a capable bot")
	var reverse: PackedVector3Array=nav.path(end,start)
	check(nav.cost(end,start,reverse)>20,"Directed movement link cannot be traversed backwards")
	world.free();NavigationServer3D.free_rid(map)
	print("BOT_NAVIGATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
