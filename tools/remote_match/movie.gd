extends SceneTree
var game
var options: Dictionary
var director=preload("res://tools/remote_match/director.gd")
var saved:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
	options=JSON.parse_string(OS.get_cmdline_user_args()[0])
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.demos.viewpoint="free";game.demos.exit_at_end=true;game.demos.stop_at=options.end
	if not game.demos.open_demo(options.demo):push_error(game.demos.message);quit(2);return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.demos.seek(options.start)
	print("MOVIE_READY duration=",game.demos.duration)
	process_frame.connect(direct,CONNECT_DEFERRED)
func direct() -> void:
	if not game.demos.playing:return
	var shot: Dictionary=director.frame(game,game.demos.position_seconds)
	if not shot.is_empty():game.demos.selected_player=shot.player
	if not saved and options.has("screenshot") and game.demos.position_seconds>options.start+5:
		saved=true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(options.screenshot)
