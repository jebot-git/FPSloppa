extends SceneTree
class Director extends Node:
	var game
	var view: String
	var title: Label
	var inspection_second:=-1
	var captured: Dictionary={}
	var tail_frames:=0
	func _process(_delta: float) -> void:
		if not game.demos.playing:return
		# MovieMaker advances once per captured frame, independent of physics catch-up.
		game.clock+=1.0/30
		game.demos.tick(1.0/30)
		if game.demos.paused:
			tail_frames+=1
			var voice_busy: bool=is_instance_valid(game.announcer.player) and (game.announcer.player.playing or not game.announcer.pending.is_empty())
			if tail_frames>=90 and not voice_busy or tail_frames>=240:
				print("MOVIE_FINAL ",JSON.stringify({"demo_seconds":game.demos.duration,"tail_seconds":tail_frames/30.0,"voice_pending":game.announcer.pending.size(),"voice_playing":voice_busy}))
				game.demos.finish_movie();return
		var rules=game.match_mode.assault
		var id:=1 if rules.attacking==0 else -1
		if not game.players.has(id):
			var candidates: Array=game.players.keys().filter(func(peer):return not game.players[peer].spectator and game.players[peer].team==rules.attacking)
			candidates.sort_custom(func(a,b):return game.players[a].name<game.players[b].name)
			if candidates.is_empty():return
			id=candidates[0]
			for peer in candidates:
				if not game.players[peer].dead:id=peer;break
		game.demos.selected_player=id
		game.demos.viewpoint="free" if view=="trackside" else "chase" if view=="vrm-chase" else view
		game.demos.update_camera(0)
		var actor=game.fighters[id];var s: Dictionary=game.players[id]
		if view=="trackside":
			var x: float=-actor.position.z*32
			var eye: Vector3
			if x<176:
				eye=Vector3(560,320,-clampf(x-220,-2800,2600))/32
			else:
				var center: float=480+640*clampi(int((x-176)/640),0,2)
				eye=Vector3(-140,260 if actor.position.y>2 else 100,-(center+224))/32
			game.demos.camera.position=eye;game.demos.camera.look_at(actor.position+Vector3.UP)
			game.demos.free_rotation=Vector2(game.demos.camera.rotation.y,game.demos.camera.rotation.x)
		if view=="vrm-chase":
			game.demos.camera.fov=55
			var second:=int(game.demos.position_seconds)
			if second!=inspection_second:
				inspection_second=second
				var runtime=game.get_node_or_null("Map/MapRuntime")
				var visible_lights:=0
				if runtime:for light in runtime.lights:visible_lights+=int(light.visible)
				print("VRM_CHASE ",JSON.stringify({"second":second,"player":id,"model":actor.avatar_hash,"loaded":is_instance_valid(actor.avatar),"position":str(actor.position),"lights":visible_lights}))
				if second in [10,25,40,60,75,90] and not captured.has(second):
					captured[second]=true
					capture_still(second)
		var label: String="TRACKSIDE / INTERIOR CAMERAS" if view=="trackside" else "ATTACKER FIRST PERSON" if view=="first" else "ATTACKER CHASE CAMERA"
		if view=="vrm-chase":label="VRM LIGHTING · CHASE · "+s.name
		title.text="FPSloppa · HiSpeed BSP29 concept · "+label+" · "+s.name+" · "+str(game.players.size())+" PLAYERS\n"+rules.status()+" · HP %d · %s · %.1fs"%[s.hp,game.W.DATA[s.weapon].name,game.demos.position_seconds]
	func capture_still(second: int) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://test-results/hispeed-vrm-chase-%03d.png"%second)
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var args:=OS.get_cmdline_user_args();var demo: String=args[0];var path: String=args[1];var view: String=args[2]
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-movie.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}]
	if not game.demos.open_demo(demo):push_error(game.demos.message);quit(1);return
	game.set_physics_process(false)
	if is_instance_valid(game.announcer.player):
		game.announcer.player.finished.connect(func():print("MOVIE_VOICE_FINISHED ",game.announcer.player.stream.resource_path))
		game.announcer.cue_started.connect(func(cue):print("MOVIE_VOICE_STARTED ",cue," ",game.demos.position_seconds))
	game.demos.exit_at_end=false
	if args.size()>3:game.demos.stop_at=float(args[3])
	if game.hud:game.hud.hide()
	var director:=Director.new();director.game=game;director.view=view;director.process_priority=100;game.add_child(director)
	var canvas:=CanvasLayer.new();game.add_child(canvas)
	var background:=ColorRect.new();background.color=Color(0,0,0,.65);background.size=Vector2(1440,64);canvas.add_child(background)
	var title:=Label.new();title.position=Vector2(16,8);title.add_theme_font_size_override("font_size",19);canvas.add_child(title);director.title=title
