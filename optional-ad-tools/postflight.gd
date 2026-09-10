extends SceneTree
var game
var failures: Array=[]
var checks:=0
func _initialize():call_deferred("run")
func require(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func vector(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])
func safe(pos: Vector3) -> bool:
	var space=game.get_world_3d().direct_space_state
	var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.5,pos-Vector3.UP*.3,1))
	if hit.is_empty() or hit.normal.y<.7:return false
	var shape:=CapsuleShape3D.new();shape.radius=.4;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=pos+Vector3.UP*.88;query.collision_mask=1;query.margin=.005
	return space.intersect_shape(query,1).is_empty()
func run() -> void:
	var args:=OS.get_cmdline_user_args();var folder: String=args[0];var only: String=args[1] if args.size()>1 else ""
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/adaptation-report.json"))
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	for kind in ["flame","flame2"]:
		var mesh=preload("res://deathmatch/maps/librequake_props.gd").fixture(kind);require(mesh!=null and mesh.get_surface_count()==1,"LibreQuake fixture "+kind)
	var results: Array=[]
	for row: Dictionary in report.maps:
		if row.status!="installed-candidate" or (not only.is_empty() and row.id!=only):continue
		var before:=failures.size();var path: String=folder+"/maps/"+row.id+".bsp"
		game.map_catalog=[{"id":row.id,"title":row.title,"path":path,"scene":folder+"/cache/"+row.sha256+".scn","sha256":row.sha256}]
		require(game._load_map(row.id),row.id+": runtime load")
		await physics_frame;await physics_frame
		for pos in game.spawn_points:require(safe(pos),row.id+": clear runtime spawn "+str(pos))
		for pos in game.map_objectives.values():require(safe(pos),row.id+": clear objective")
		for pickup in game.pickups:require(safe(pickup.position),row.id+": clear pickup")
		require(game.ctf_spawns[0].size()>0 and game.ctf_spawns[1].size()>0,row.id+": both teams have spawns")
		require(game.tf_resupply[0].size()==1 and game.tf_resupply[1].size()==1 and game.tf_capture.size()==2,row.id+": TF objectives")
		for mode in row.modes:
			game.match_mode.kind=mode;game.map_rotation=[];game._restart_round()
			if mode=="koth":require(game.match_mode.hill.distance_to(vector(row.validation.goals[2]))<.01,row.id+": authored hill")
			if mode in ["cc","ig"]:
				for pickup in game.pickups:require(not pickup.available,row.id+": "+mode+" disables pickups")
		var bot=preload("res://deathmatch/bots.gd").new();game.add_child(bot);bot.setup(game)
		for i in 30:await physics_frame
		var nav: RID=bot.region.get_navigation_map();var goals: Array=game.map_objectives.values()
		for pickup in game.pickups:goals.append(pickup.position)
		var routes:=0
		for spawn in game.spawn_points:
			for goal in goals:
				if spawn.distance_to(goal)<1:continue
				var route:=NavigationServer3D.map_get_path(nav,spawn,goal,true);routes+=1
				require(route.size()>1 and route[-1].distance_to(goal)<1.2,row.id+": final objective/pickup route")
		bot.free();await physics_frame
		var level: Node=game.get_node("Map").get_child(0)
		var triangles:=0;var cutouts:=0
		for node in level.find_children("*","MeshInstance3D",true,false):
			if not node.mesh:continue
			for surface in node.mesh.get_surface_count():
				var material=node.get_active_material(surface)
				if material is ShaderMaterial and material.shader==preload("res://deathmatch/maps/baked_light.gdshader") and material.get_shader_parameter("alpha_cutout")==true:
					cutouts+=1
					var texture: Texture2D=material.get_shader_parameter("base_texture")
					require(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,row.id+": cutout pixels retain alpha")
			var faces: PackedVector3Array=node.mesh.get_faces();triangles+=faces.size()/3
			for i in range(0,faces.size(),3):require((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()>1e-14,row.id+": nondegenerate final geometry")
		if row.id=="ad_arena_ad_akalakha":require(cutouts>0,row.id+": masked cobweb materials present")
		results.append({"cutout_materials":cutouts,"id":row.id,"passed":before==failures.size(),"spawns":game.spawn_points.size(),"pickups":game.pickups.size(),"routes":routes,"triangles":triangles,"rgb":level.get_meta("baked_light_rgb",false)})
		print("AD_POSTFLIGHT ",JSON.stringify(results.back()))
	var out:=FileAccess.open(folder+"/postflight"+("-"+only if not only.is_empty() else "")+".json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"maps":results,"failures":failures},"  "));out.close()
	print("AD_POSTFLIGHT_RESULT ",checks," checks, ",failures.size()," failures");game.free();await process_frame;quit(0 if failures.is_empty() else 1)
