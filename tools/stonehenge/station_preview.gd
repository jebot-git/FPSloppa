extends SceneTree
var g
func _initialize():run.call_deferred()
func shot(label: String):
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/stonehenge-ctf/"+label+".png")
func run():
	root.size=Vector2i(1440,900)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge";g.start_host("Station preview",0,100,30,true,"st","tribes")
	g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	g.hud.hide();g.menu_open=false;g.fighters[1].hide()
	var camera:=Camera3D.new();camera.far=1800;camera.fov=72;g.add_child(camera);camera.make_current()
	var pads=g.match_mode.tribes.stations()
	for team in [0,1]:
		var row: Dictionary=pads.rows.filter(func(r):return r.team==team)[0]
		var angle: float=(-.799978 if team==0 else 2.48306)+PI
		camera.position=row.position+Vector3(3.6,2.8,-5.5).rotated(Vector3.UP,angle)
		camera.look_at(row.position+Vector3.UP*1.35);await shot("station-"+str(team))
		g.players[1].team=team;g.fighters[1].position=row.position
		g.match_mode.tribes.open_inventory();await shot("inventory-"+str(team));g.match_mode.tribes.panel.close()
	print("STONEHENGE_STATION_PREVIEW_OK");g.disconnect_game();g.free();quit()
