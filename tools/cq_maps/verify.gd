extends SceneTree
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Atlas=preload("res://deathmatch/conquest/district_maps.gd")
const Contents=preload("res://deathmatch/maps/contents.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	create_timer(90).timeout.connect(func():quit(3));run.call_deferred()
func run():
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/CQDistricts/manifest.json"))
	var world:=Node3D.new();root.add_child(world)
	for zone in 16:
		var folder:="res://maps/CQDistricts/district_%02d/"%zone;var entry: Dictionary=manifest.districts[zone]
		var origin:=Vector3(entry.origin[0],0,entry.origin[2])
		check(origin.distance_to(Rules.center(zone)*Vector3(1,0,1))<.001,"Shared district origin %d"%zone)
		var visual: Node3D=load(folder+"presentation.scn").instantiate()
		check(visual.get_meta("baked_light_faces",0)>9000,"Dense district lightmapped %d"%zone)
		check(visual.get_meta("baked_light_overflow_faces",0)==0 and visual.get_meta("baked_light_invalid_faces",0)==0,"Full bake fits atlas %d"%zone)
		check(visual.get_meta("baked_light_rgb",false),"RGB bake %d"%zone)
		visual.free()
		var level: Node3D=load(folder+"collision.scn").instantiate();level.position=origin;world.add_child(level)
		Atlas.add_sky_bounds(level)
		var contents:=Contents.new();check(contents.open(folder+"district.bsp"),"Local BSP contents %d"%zone);contents.origin=origin
		await physics_frame;await physics_frame
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3.UP]:
			var start:=origin+Vector3(0,70,0)
			check(not world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+direction*150,1)).is_empty(),"Closed upper district boundary %d %s"%[zone,direction])
		for point in entry.spawns+entry.pickup_positions:
			var p:=origin+Vector3(point[0],point[1],point[2])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*.6,1))
			check(not hit.is_empty() and hit.normal.y>.7,"Translated spawn/pickup floor %d %s"%[zone,p])
		check(contents.at(origin+Vector3(0,1,0))==-1 and contents.at(origin+Vector3(0,-1,0))==-2,"Translated BSP contents agree with floor %d"%zone)
		for neighbor in Rules.neighbors(zone):
			var gate: Vector3=(Rules.center(zone)+Rules.center(neighbor))*.5;var direction: Vector3=(Rules.center(neighbor)-Rules.center(zone)).normalized()
			check(Atlas.portal_allowed(zone,neighbor,gate+direction*.1),"Aligned crossing accepted %d %d"%[zone,neighbor])
			check(not Atlas.portal_allowed(zone,neighbor,gate+Vector3.UP*20),"No roof bypass %d %d"%[zone,neighbor])
			check(not Atlas.portal_allowed(zone,neighbor,gate+direction.cross(Vector3.UP)*20),"No wall bypass %d %d"%[zone,neighbor])
		check(not Atlas.portal_allowed(zone,(zone+5)%16,Rules.center(zone)),"No diagonal district teleport %d"%zone)
		level.free();await physics_frame
	# The existing two-effect occlusion tree must still block walls after translation.
	var tree=preload("res://deathmatch/lighting/solid_tree.gd").new();check(tree.open("res://maps/CQDistricts/district_00/district.bsp"),"Load translated illumination tree")
	var local=preload("res://deathmatch/lighting/solid_tree.gd").new();var offset:=Vector3(-375,0,-375)
	local.head=tree.prune_into(local,tree.head,AABB(Vector3(-1,-1,-1),Vector3(2,3,2)))
	for i in local.planes.size():local.planes[i].d+=local.planes[i].normal.dot(offset)
	check(leaf(local,offset+Vector3(0,1,0))==-1 and leaf(local,offset+Vector3(0,-.5,0))==-2,"Translated shader occlusion preserves air and solid")
	check(preload("res://deathmatch/lighting/weapon_pool.gd").MAX_EFFECTS==2,"Desktop and VR illumination cap remains two")
	var report:={"checks":checks,"failures":failures,"districts":16};FileAccess.open("res://test-results/cq-maps/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CQ_DISTRICT_GEOMETRY ",JSON.stringify(report));world.free();quit(0 if failures.is_empty() else 1)
func leaf(tree,point: Vector3) -> int:
	var index: int=tree.head
	for i in 512:
		if index<0:return index
		index=tree.children[index].x if tree.planes[index].distance_to(point)>=0 else tree.children[index].y
	return -99
