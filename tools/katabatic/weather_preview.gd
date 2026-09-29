extends SceneTree
var g
func _initialize():run.call_deferred()
func vector(a):return Vector3(a[0],a[1],a[2])
func shot(name: String):
	for i in 12:await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/st-katabatic/"+name+".png")
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	for map in ["ctf_katabatic","ctf_raindance","ctf_stonehenge"]:
		g.selected_map=map;g.start_host("Weather preview",0,100,15,true,"st")
		g.set_process(false);g.set_physics_process(false);g.menu_open=false;g.hud.hide()
		for id in g.players:g.players[id].spectator=true
		g.get_node("Menu").hide() if g.has_node("Menu") else null
		var folder: String={"ctf_katabatic":"Katabatic","ctf_raindance":"Raindance","ctf_stonehenge":"Stonehenge"}[map]
		var probes=JSON.parse_string(FileAccess.get_file_as_string("res://maps/"+folder+"/probes.json"))
		g.camera.far=3000;g.camera.make_current()
		var name: String=map.trim_prefix("ctf_")
		g.camera.global_position=vector(probes.views[0].eye);g.camera.look_at(vector(probes.views[0].look))
		g.get_node("Environment").environment.fog_enabled=false;await shot(name+"-weather-clear")
		preload("res://deathmatch/maps/atmosphere.gd").distance_fog(g.get_node("Environment").environment,map)
		await shot(name+"-weather-fog")
		if map=="ctf_katabatic":
			g.camera.global_position=vector(probes.views[2].eye);g.camera.look_at(vector(probes.views[2].look));await shot(name+"-interior")
		var flag: Vector3=g.match_mode.bases[0]
		g.camera.global_position=flag+Vector3(0,3,-8) if map=="ctf_raindance" else flag+Vector3(0,2,12)
		g.camera.look_at(g.camera.global_position+Vector3(0,.1,-1));await shot(name+"-weather-close")
		g.disconnect_game();await physics_frame;await physics_frame
	g.queue_free();await process_frame;print("WEATHER_PREVIEW_DONE");quit()
