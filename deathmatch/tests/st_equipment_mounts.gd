extends SceneTree
## Real-map equipment alignment and native-art integration regressions.
const Props=preload("res://deathmatch/tribes/prop_library.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	for map in ["ctf_stonehenge","ctf_raindance","ctf_katabatic"]:
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=map;g.start_host("Equipment alignment",0,100,30,true,"st")
		g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
		for id in g.players.keys():
			if id<0:g._peer_left(id)
		await physics_frame;await physics_frame
		var pads=g.match_mode.tribes.stations()
		for source in pads.generators:
			var start: Vector3=source.frame*Vector3(0,0,4);var end: Vector3=source.frame*Vector3(0,0,0)
			var hit: Dictionary=g._trace(start,end,0)
			check(hit.get("power_source",-1)==source.key,map+" generator front is aligned to physical damage surface")
			check(start.distance_to(hit.position)>2.5,map+" generator is not rotated across its BSP housing")
		for key in pads.assets.rows.size():
			var row: Dictionary=pads.assets.rows[key]
			if row.kind!="pulse":continue
			var hit: Dictionary=g._trace(row.point+row.frame.basis*Vector3(0,0,-5),row.point,0)
			check(hit.get("base_asset",-1)==key,map+" fixed sensor has solid, damageable housing")
		for spawn in g.spawn_points:
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.45;capsule.height=1.8;query.shape=capsule;query.transform.origin=spawn+Vector3.UP*.96;query.collision_mask=1
			check(g.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),map+" equipment leaves original spawn capsule clear")
		for i in pads.rows.size():
			var row: Dictionary=pads.rows[i];g.players[1].team=row.team;g.fighters[1].position=row.position
			check(pads.at(1,[row.kind])==i,map+" station service area stays clear: "+row.kind)
		g.disconnect_game();g.free()
		for i in 2:await process_frame
	var native_audit: Dictionary={}
	for file in DirAccess.get_files_at("res://deathmatch/tribes/props"):
		if not file.ends_with(".scn"):continue
		var kind:=file.get_basename();var model=Props.make(kind,0);root.add_child(model)
		var stats: Dictionary={"meshes":0,"surfaces":0,"triangles":0,"mipmapped":true}
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			stats.meshes+=1
			for i in mesh.mesh.get_surface_count():
				stats.surfaces+=1;var arrays=mesh.mesh.surface_get_arrays(i)
				stats.triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
				var mat=mesh.get_active_material(i)
				if mat.albedo_texture:stats.mipmapped=stats.mipmapped and mat.albedo_texture.get_image().has_mipmaps()
		check(stats.mipmapped and stats.meshes<=2 and stats.surfaces<=7,kind+" mipmapped and batched")
		if kind.begins_with("fixed_"):
			var data=preload("res://deathmatch/tribes/fixed_defence_data.gd");var head=model.get_node("Head")
			check(is_equal_approx(head.position.y,data.size(kind.trim_prefix("fixed_")).y-.25),kind+" head pivot follows authoritative eye")
			var direction:=Vector3(.6,.2,-.7).normalized();head.look_at(head.global_position+direction)
			check((-head.global_basis.z).dot(direction)>.999,kind+" head still tracks firing direction")
		Props.set_active(model,false);var blue=Props.make(kind,1);root.add_child(blue)
		check(not model.get_meta("st_active") and blue.get_meta("st_active"),kind+" disabled state is isolated from other instances")
		blue.free();model.free();native_audit[kind]=stats
	for kind in ["turret","camera"]:
		var deployed=preload("res://deathmatch/tribes/deployable_model.gd").make(kind,0)
		var carried=preload("res://deathmatch/tribes/deployable_model.gd").make(kind,0,true)
		var expected: Vector3=deployed.get_node("Head").position-deployed.get_node("Body").position
		check((carried.get_node("Head").position-carried.get_node("Body").position).is_equal_approx(expected),kind+" packed head remains attached to body")
		deployed.free();carried.free()
	FileAccess.open("res://test-results/st-equipment-design/native-audit.json",FileAccess.WRITE).store_string(JSON.stringify(native_audit,"\t"))
	print("ST_EQUIPMENT_MOUNTS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
