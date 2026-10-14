extends SceneTree
var game
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game)
	game.start_host("CQ objectives preview",28818,100,1,false)
	game.set_process(false);game.set_physics_process(false);game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED
	game.match_mode.objectives.rules.owners[0]=0;game.match_mode.objectives.rules.progress[1]=[0.0,5.0]
	game.battle_map.lighting.phase_override=1.0;game.battle_map.lighting.apply();game.match_mode.draw_objectives()
	game.hud.visible=false;game.camera.make_current();game.menu_open=true
	DirAccess.make_dir_recursive_absolute("res://docs/validation/voxel-battle/frontier-points")
	for zone in [0,1]:
		var point:Vector3=game.match_mode.objectives.sites[zone].position
		game.camera.position=point+Vector3(0,1.7,5);game.camera.look_at(point+Vector3.UP*.9);game.battle_map.update_view(game.camera)
		for frame in 120:game.battle_map.update_view(game.camera);await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/voxel-battle/frontier-points/capture-room-%d.png"%zone)
		print("CQ_OBJECTIVE_PREVIEW ",zone," ",game.match_mode.objectives.labels[zone][0].text)
	print("CQ_OBJECTIVE_PREVIEW_RESULT PASS");game.disconnect_game();game.free();quit()
