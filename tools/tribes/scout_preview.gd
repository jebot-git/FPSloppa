extends SceneTree
var g
func _initialize():run.call_deferred()
func shot(label: String):
	for i in 10:
		g.match_mode.tribes.vehicles.update(1.0/60);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/st-vehicles/"+label+".png")
func run():
	root.size=Vector2i(1280,800)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Scout preview",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false);g.voice.set_mode(0)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g.hud.hide();g.menu_open=false;g.fighters[1].hide()
	var camera:=Camera3D.new();camera.far=1800;camera.fov=72;g.add_child(camera);camera.make_current()
	var rules=g.match_mode.tribes;var c=rules.vehicles;var pads=rules.stations();g.players[1].team=0;g.players[1].input_blocked=false
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	g.fighters[1].position=pads.rows[index].position
	await physics_frame;await physics_frame
	assert(c.purchase(1,g.map_epoch,g.players[1].serial));g.clock+=4
	var key: int=c.rows.keys()[0];var row: Dictionary=c.rows[key]
	camera.position=row.position+Vector3(7,5,8);camera.look_at(row.position+Vector3.UP*.3)
	await shot("scout-pad")
	camera.position=row.position+Vector3(-5,2,-6);camera.look_at(row.position+Vector3.UP*.4)
	await shot("scout-front")
	g.fighters[1].position=c.frame(row)*Vector3(2.7,0,0);assert(c.board(1,key))
	camera.position=g.fighters[1].position+Vector3.UP*1.48;camera.rotation=Vector3.ZERO
	await shot("scout-cockpit")
	assert(c.leave(1));g.fighters[1].position=pads.rows[index].position
	rules.open_inventory();await shot("scout-buy");rules.panel.close()
	print("SCOUT_PREVIEW_OK");g.music.stop();g.announcer.clear_audio();c.reset();g.disconnect_game()
	await create_timer(.25).timeout
	g.free()
	for i in 3:await process_frame
	quit()
