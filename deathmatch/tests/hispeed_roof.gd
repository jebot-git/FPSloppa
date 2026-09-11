extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-roof.scn","sha256":hash}];game.selected_map=key;game.start_host("Roof probe",0,20,7,true,"as")
	for attempt in 1200:
		if game.bots.ready_to_walk:break
		await create_timer(.05).timeout
	game.practice=false;game.dedicated=true
	for id in game.players:game.players[id].spectator=id!=1
	for gun in game.match_mode.fortress.buildings.values():gun.ready=1000000
	var actor=game.fighters[1];var s: Dictionary=game.players[1];s.team=0;s.dead=false
	actor.position=Vector3(224,6,-112)/32;actor.velocity=Vector3.ZERO
	var rose:=false;var landed:=false;var frames:=0
	for frame in 300:
		await physics_frame;s.last_input=game.clock
		if actor.position.y>10.7:rose=true
		s.move=Vector2(-.35,-.94) if rose else Vector2.ZERO;s.yaw=0
		game._physics_process(1.0/60);frames=frame
		if rose and actor.is_on_floor() and actor.position.y>9.9:landed=true;break
	var landing: Vector3=actor.position
	if landed:
		# Traverse the roofs, entering the authored CAR 1 hatch at y=0.
		for frame in 650:
			await physics_frame;s.last_input=game.clock
			var target:=Vector3(0,10,-1824.0/32)
			var delta: Vector3=target-actor.position
			s.move=Vector2(delta.x,delta.z).normalized();s.yaw=0
			game._physics_process(1.0/60)
			if actor.position.y<6:break
	var hatch: bool=landed and actor.position.y<6 and actor.position.z<-54
	var result: Dictionary={"rose_above_roof":rose,"landed_on_car3_roof":landed,"landing":str(landing),"launch_frames":frames,"entered_car1_hatch":hatch,"end":str(actor.position),"hp":s.hp,"failed":not rose or not landed or not hatch or s.dead}
	FileAccess.open("res://test-results/hispeed-roof.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("ROOF_RESULT ",JSON.stringify(result));game.free();quit(1 if result.failed else 0)
