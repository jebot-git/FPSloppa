extends SceneTree
var g
var views: Array=[]
func _initialize():run.call_deferred()
func shot(name: String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cindercoil/"+name+".png")
	views.append({"view":name,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="tb_cindercoil";g.start_host("Cindercoil views",0,100,10,true,"tb")
	g.set_process(false);g.set_physics_process(false);g.bots.free();g.bots=null
	g.match_mode.titanball.advance_time(60);g.menu_open=false;g.hud.hide();g.camera.make_current();g.camera.far=500
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Cindercoil/probes.json"))
	for view in probes.views:
		g.camera.position=Vector3(view.eye[0],view.eye[1],view.eye[2]);g.camera.look_at(Vector3(view.look[0],view.look[1],view.look[2]));await shot(view.name)
	g.camera.position=Vector3(-9,5,-7);g.camera.look_at(Vector3(0,5,-24));await shot("attacker-hangar")
	g.camera.position=Vector3(66,180,-10);g.camera.look_at(Vector3(66,0,-10),Vector3.FORWARD);g.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;g.camera.size=230
	await shot("overview")
	FileAccess.open("res://test-results/cindercoil/views.json",FileAccess.WRITE).store_string(JSON.stringify({"bsp_sha256":FileAccess.get_sha256("res://maps/tb_cindercoil.bsp"),"views":views},"  "))
	print("CINDERCOIL_VIEWS_OK");g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit()
