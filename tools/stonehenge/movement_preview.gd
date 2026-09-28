extends SceneTree
var g
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge";g.start_host("Tribes flight",0,100,30,true,"st","tribes")
	g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	await physics_frame;await physics_frame
	var a=g.fighters[1]
	a.position=g.match_mode.bases[0]+Vector3(18,25,0);a.velocity=Vector3.ZERO;a.reset_tribes();a.jet_held=true;a.ski_held=true
	g.local_yaw=0;g.local_pitch=-.15
	for i in 150:a.simulate(Vector2.ZERO,0,false,1.0/60)
	a.reset_view()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/tribes/stonehenge-flight.png")
	print("TRIBES_PREVIEW ",JSON.stringify({"energy":a.tribes_state.energy,"speed":a.velocity.length(),"position":str(a.position),"hud":g.hud.ability_notice.text}))
	g.disconnect_game();g.queue_free();await process_frame;quit()
