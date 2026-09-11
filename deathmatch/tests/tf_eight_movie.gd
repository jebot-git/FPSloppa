extends SceneTree
class Director extends Node:
	var game
	var timeline: Array=[]
	var title: Label
	var tail_frames:=0
	var view:="chase"
	var stills: Dictionary={}
	func _process(_delta: float) -> void:
		if not game.demos.playing:return
		game.clock+=1.0/30;game.demos.tick(1.0/30)
		if game.demos.paused:
			tail_frames+=1
			var voice_busy: bool=is_instance_valid(game.announcer.player) and (game.announcer.player.playing or not game.announcer.pending.is_empty())
			if tail_frames>=90 and not voice_busy or tail_frames>=240:
				print("TF_MOVIE_FINAL ",JSON.stringify({"seconds":game.demos.duration,"voice_pending":game.announcer.pending.size(),"voice_playing":voice_busy}))
				game.demos.finish_movie();return
		var current: Dictionary=timeline[0] if not timeline.is_empty() else {}
		for row in timeline:
			if row.time<=game.demos.position_seconds:current=row
		var id: int=current.get("focus",game.demos.selected_player)
		if not game.players.has(id):return
		game.demos.selected_player=id;game.demos.viewpoint=view;game.demos.update_camera(0)
		var state: Dictionary=game.players[id];var tf=game.match_mode.fortress
		title.text="FPSloppa · Turtler local conversion · 8 PLAYERS · "+str(current.get("label","TF")).replace("_"," ").to_upper()+"\n"+state.name+" · "+tf.definition(id).name+" · HP %d · RED %d : %d BLUE · %.1fs"%[state.hp,game.match_mode.scores[0],game.match_mode.scores[1],game.demos.position_seconds]+"\n"+tf.status(id)
		var phase: String=current.get("label","")
		if game.demos.position_seconds-current.get("time",0)>.35 and not stills.has(phase):
			stills[phase]=true;capture(phase)
	func capture(phase: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://test-results/tf-eight-"+phase+".png")
func _initialize():call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var demo_path: String=args[0];var path: String=args[1]
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var hash:=FileAccess.get_sha256(path);var key:=path.get_file().get_basename()
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-tf-movie.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}]
	if not game.demos.open_demo(demo_path):push_error(game.demos.message);quit(1);return
	game.set_physics_process(false);game.demos.exit_at_end=false
	if game.hud:game.hud.hide()
	var director:=Director.new();director.game=game;director.process_priority=100
	var data=JSON.parse_string(FileAccess.get_file_as_string(demo_path.get_basename()+".json"));director.timeline=data.phases
	if args.size()>2:director.view=args[2]
	game.add_child(director)
	var canvas:=CanvasLayer.new();game.add_child(canvas)
	var background:=ColorRect.new();background.color=Color(0,0,0,.75);background.size=Vector2(1280,90);canvas.add_child(background)
	var title:=Label.new();title.position=Vector2(12,6);title.add_theme_font_size_override("font_size",18);canvas.add_child(title);director.title=title
	game.announcer.cue_started.connect(func(cue):print("TF_MOVIE_VOICE ",cue))
