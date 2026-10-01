extends SceneTree
## Explicit diagnostic entry point. Does not save presentation/tracking/haptics settings.
const Metrics=preload("res://deathmatch/avatars/animation_metrics.gd")
const Events=preload("res://tools/performance_suite/events.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var config: Dictionary
var game
var sampler: Node
var base:=Vector3.ZERO
var rigs: Array=[]
var simulation:=0.0
var next_shot:=0.0
var library
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--suite-config")
	if index<0 or index+1>=args.size():push_error("Missing --suite-config");quit(2);return
	config=JSON.parse_string(FileAccess.get_file_as_string(args[index+1]))
	seed(20260930)
	game=load(config.scene).instantiate();root.add_child(game);current_scene=game
	if config.live and not game.is_vr():push_error("Live suite requires an initialized headset");quit(2);return
	if not config.live:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=0;root.size=Vector2i(1440,900);root.content_scale_size=root.size
		game.practice=true;game.active=true;game.menu_open=false
		game.set_process(false);game.set_physics_process(false);game.hud.visible=false
		game.haptics.shutdown();game.voice.set_mode(0);game.avatars.set_process(false);game.avatars.load_queue.clear()
		game.armory.select(config.rules)
		base=Vector3(0,game.get_node("Map/MapRuntime").bounds.end.y+4,0)
		library=preload("res://deathmatch/avatars/library.gd").new()
		for model_name in ["sample_d","sample_f","sample_g"]:
			var model_path: String="res://vrm/"+model_name+".vrm"
			library.entries[FileAccess.get_sha256(model_path)]={"path":model_path}
		var models: Array=library.entries.keys();models.sort()
		if models.is_empty():push_error("No VRM available for profiling");quit(2);return
		for id in [1,-1,-2,-3,-4,-5,-6,-7]:
			game._add_player(id,"Performance fixture")
			var actor=game.fighters[id]
			actor.position=base+Vector3((abs(id)%4-1.5)*1.1,0,-2.5-abs(id)/4.0)
			actor.visual_velocity=Vector3(0,0,3);actor.rotation=Vector3.ZERO
			var hash_here: String=models[absi(id)%mini(3,models.size())]
			var rig=preload("res://deathmatch/avatars/visual_loader.gd").create_avatar(library,hash_here)
			if not rig:push_error(library.last_error);quit(2);return
			actor.set_avatar(rig,hash_here);actor.show_alive(true,id==1);rigs.append(rig)
		# Apply isolation after the last roster update, which resets avatar process modes.
		for rig in rigs:
			if config.variant=="frozen":rig.process_mode=Node.PROCESS_MODE_DISABLED
			if config.variant=="hidden":rig.get_parent().visible=false;rig.process_mode=Node.PROCESS_MODE_DISABLED
		game.camera.global_position=base+Vector3(0,1.55,3);game.camera.global_rotation=Vector3.ZERO
		game.effects.enabled=config.variant!="no-effects"
	Metrics.enabled=config.stage=="profile"
	sampler=load("res://tools/performance_suite/sampler.gd").new()
	sampler.finished.connect(func():
		rigs.clear()
		if library:library.free();library=null)
	sampler.game=game;sampler.config=config;sampler.process_priority=100000;root.add_child(sampler)
	print("PERFORMANCE_SUITE_READY ",config.output)
func _process(delta: float) -> bool:
	if not game or config.get("live",true) or not sampler or game.quitting:return false
	simulation+=delta;game.clock+=delta
	game.camera.global_rotation=Vector3(0,sin(simulation*.3)*.25,0)
	for i in rigs.size():
		var pose:=Poses.neutral();var t:=simulation+i*.37
		pose.head.origin.y+=sin(t*2)*.035
		pose.left.origin+=Vector3(0,sin(t*2)*.05,sin(t)*.07)
		pose.right.origin+=Vector3(0,cos(t*2)*.05,cos(t)*.07)
		pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"chest":Transform3D(Basis.IDENTITY,Vector3(0,1.2,0))}
		for side in ["left","right"]:
			var sign_side:=-1.0 if side=="left" else 1.0
			pose.body[side+"_foot"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.13,.08+maxf(0,sin(t*3*sign_side))*.06,sin(t*3*sign_side)*.13))
			pose.body[side+"_knee"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.16,.5,-.2))
		rigs[i].get_parent().xr_pose=pose
	var test_time: float=maxf(0,simulation-config.warmup)
	var weapon: int=int(test_time/5.0)%game.armory.table.size()
	game.players[1].weapon=weapon;game.players[-1].weapon=weapon
	for actor in game.fighters.values():actor.visual_weapon=weapon
	if simulation>=next_shot:
		next_shot=simulation+maxf(.1,float(game.armory.data(weapon).cycle))
		if config.variant!="no-effects":
			game._play_shot_fx(-1,weapon)
			var where: Vector3=base+Vector3(0,1,-3)
			game.effects.hit(-1,where,Vector3.FORWARD,10,false,false,20260930)
			game._weapon_visuals().impacts(config.rules,where+Vector3(0,0,3),PackedVector3Array([where]),weapon,game.armory.data(weapon))
	return false
