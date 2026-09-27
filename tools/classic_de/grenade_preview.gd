extends SceneTree
var g
func _initialize():run.call_deferred()
func capture(name: String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/classic-de/"+name+".png")
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="de_nuke_rebuilt";g.start_host("Grenade visual audit",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0);de.carrier=0;de.held=false
	g.menu_open=false;g.camera.make_current();g.camera.position=de.sites[0]+Vector3(0,1.6,2);g.camera.rotation=Vector3.ZERO
	var u=de.utility;u.flashes.clear();u.clouds.clear();u.draw()
	var props:=Node3D.new();g.camera.add_child(props)
	for kind in 3:
		var prop=load("res://deathmatch/counterstrike/grenade_visuals.gd").model(kind);props.add_child(prop);prop.position=Vector3((kind-1)*.18,0,-.55);prop.rotation=Vector3(.1,-.35,-.2)
	await capture("grenade-models");props.free()
	u.clouds[1]={"position":g.camera.position+Vector3(0,-.5,-7),"age":3.0};u.draw();await capture("grenade-smoke")
	u.clouds.clear();u.flashes[1]={"hold":g.clock+2,"end":g.clock+5,"alpha":.6,"serial":g.players[1].serial};u.draw();await capture("grenade-flash")
	# Compile and render the XR clip-space shader on a camera quad as well.
	u.flashes.clear();u.draw();var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2);quad.extra_cull_margin=100
	var mat:=ShaderMaterial.new();mat.shader=load("res://deathmatch/counterstrike/utility_overlay.gdshader");mat.set_shader_parameter("smoke",.7);quad.material_override=mat;g.camera.add_child(quad);quad.position.z=-.08
	await capture("grenade-xr-shader");print("GRENADE_VISUAL_RESULT OK")
	g.disconnect_game();g.free();await process_frame;quit()
