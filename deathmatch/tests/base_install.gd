extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.hud=game.Interface.new();game.add_child(game.hud);game.hud.setup(game)
	var panel=preload("res://deathmatch/assets/panel.gd").new();game.add_child(panel);panel.setup(game)
	var args:=OS.get_cmdline_user_args()
	panel.request.download_file=args[args.find("--archive")+1]
	await panel.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray())
	var passed: bool=game.map_catalog.size()==8 and game.avatars.library.entries.size()==3
	print("BASE_INSTALL_RESULT ",passed," maps=",game.map_catalog.size()," models=",game.avatars.library.entries.size())
	game.free();quit(0 if passed else 1)
