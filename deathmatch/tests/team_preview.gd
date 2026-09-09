extends SceneTree
func _initialize():call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run():
	root.size=Vector2i(1280,960);root.content_scale_size=Vector2i(853,640)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	await shot("retro-main-menu")
	g.hud.settings_panel.open();await shot("retro-audio-menu");g.hud.settings_panel.section="graphics";g.hud.settings_panel.refresh();await shot("retro-graphics-menu");g.hud.settings_panel.hide()
	g.match_mode.kind="ctf";g.match_mode.reset();g._add_player(1,"Marine");g.active=true;g.menu_open=true;g.hud.show_menu(true);g.votes.allowed_modes=["dm","tdm","ctf","koth"];g.hud.votes_panel.open()
	await shot("retro-votes-menu");g.hud.hide();g.active=false;g._load_map("lqdm3");g.match_mode.reset();g.match_mode.draw_objectives()
	await physics_frame;await physics_frame
	var base:Vector3=g.match_mode.bases[0]
	var camera:Camera3D=g.get_node("Overview");camera.make_current();camera.position=base+Vector3(2,1.6,2)
	for i in range(16):
		var candidate:=base+Vector3(cos(i*TAU/16)*3,1.6,sin(i*TAU/16)*3)
		var query:=PhysicsRayQueryParameters3D.create(base+Vector3.UP,candidate,1)
		if g.get_world_3d().direct_space_state.intersect_ray(query).is_empty():camera.position=candidate;break
	camera.look_at(base+Vector3.UP*.9)
	await shot("ctf-hyperborea-base")
	g.free();quit()
