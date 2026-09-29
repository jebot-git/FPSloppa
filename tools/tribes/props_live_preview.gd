extends SceneTree
var g
var camera: Camera3D
func _initialize():run.call_deferred()
func shot(name: String):
	for frame in 10:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://test-results/st-equipment-design/"+name+".png")==OK)
func run():
	root.size=Vector2i(1440,900)
	for map in ["ctf_stonehenge","ctf_raindance"]:
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=map;g.start_host("ST equipment preview",0,100,30,true,"st")
		g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false);g.voice.set_mode(0)
		for id in g.players.keys():
			if id<0:g._peer_left(id)
		g.hud.hide();g.menu_open=false;g.fighters[1].hide()
		camera=Camera3D.new();camera.far=1800;camera.fov=68;g.add_child(camera);camera.make_current()
		var pads=g.match_mode.tribes.stations()
		for row in pads.rows:
			if row.team!=0:continue
			camera.global_position=row.frame*Vector3(3.5,3,-5.2);camera.look_at(row.frame*Vector3(0,1.6,1.5));await shot(map+"-"+row.kind)
		var gen: Dictionary=pads.generators[0];camera.global_position=gen.frame*Vector3(5,2.0,6);camera.look_at(gen.frame*Vector3(0,0,.8));await shot(map+"-generator")
		var sensor: Dictionary=pads.assets.rows.filter(func(row):return row.kind=="pulse" and row.team==0)[0]
		camera.global_position=sensor.frame*Vector3(8.5,7,-12);camera.look_at(sensor.frame*Vector3(0,3,0));await shot(map+"-sensor")
		if not pads.defences.rows.is_empty():
			var turret: Dictionary=pads.defences.rows[0];camera.global_position=turret.position+Vector3(5,4,-8);camera.look_at(turret.position+Vector3.UP*1.5);await shot(map+"-turret")
		g.music.stop();g.announcer.clear_audio();g.disconnect_game();await create_timer(.25).timeout;g.free()
		for i in 3:await process_frame
	print("ST_PROPS_MAP_PREVIEW_PASS");quit()
