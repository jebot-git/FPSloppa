extends SceneTree
var game
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-motion-test.scn","sha256":hash}]
	check(game._load_map(key),"Moving-scenery BSP loads")
	var motion=game.get_node_or_null("Map/MapRuntime/TrainMotion")
	check(motion!=null,"Map opts into cosmetic animation")
	if motion==null:game.free();quit(1);return
	motion.set_process(false)
	check(motion.materials.size()==3 and motion.moving.size()==2,"Three conveyor materials and two batched scenery movers")
	var solids: Dictionary={}
	for node in game.get_node("Map").find_children("*","CollisionObject3D",true,false):
		if node.collision_layer&1:solids[node]=node.global_transform
	var before: Array=motion.moving.map(func(row):return row.node.position)
	motion._process(.113)
	check(motion.moving[0].node.position!=before[0],"Track ties visibly advance")
	check(motion.materials.all(func(row):return row.material.get_shader_parameter("map_uv_offset").x!=0),"Ground, rails and cutting textures scroll")
	check(motion.moving.all(func(row):return row.node.collision_layer==0),"Animated scenery has no player collision")
	check(solids.keys().all(func(node):return node.global_transform==solids[node]),"Train and solid world collision remain stationary")
	before=motion.moving.map(func(row):return row.node.position)
	game.presentation.train_motion=false;motion._process(.5)
	check(motion.moving[0].node.position==before[0],"Reduced-motion setting freezes scenery")
	game.presentation.train_motion=true;motion._process(.1)
	check(motion.moving[0].node.position!=before[0],"Scenery resumes without resetting the map")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	var camera: Camera3D=game.get_node("Overview");camera.position=Vector3(530,420,2200)/32;camera.look_at(Vector3(0,80,1200)/32);camera.make_current()
	if game.hud:game.hud.hide()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hispeed-motion.png")
	print("MOTION_RESULT ",JSON.stringify({"failures":failures}));game.free();quit(0 if failures.is_empty() else 1)
