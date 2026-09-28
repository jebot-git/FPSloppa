extends SceneTree
## Controlled still / sub-pixel camera-jitter captures on the live map.
func _initialize():run.call_deferred()
func run():
	var output: String=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(960,640);root.position=Vector2i(6000,6000);Engine.max_fps=60
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Avatar renderer comparison",0,20,30,true,"st");g.set_physics_process(false);g.set_process(false);g.hud.hide()
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g.fighters[1].hide()
	var center: Vector3=g.match_mode.bases[1];var metadata: Array=[]
	for i in 3:
		var id:=-1000-i;g._add_player(id,"Probe");var actor=g.fighters[id]
		actor.position=center+Vector3((i-1)*1.3,0,0);actor.target=actor.position;actor.rotation.y=PI;g.players[id].yaw=PI
		g.match_mode.tribes.apply_equipment(id,["light","medium","heavy"][i],[3,2,1],"energy")
		actor.show_alive(true,false);actor._process(.016);actor.label.hide()
		await process_frame;await process_frame;actor._process(.016)
		var rows: Array=[]
		for node in actor.find_children("*","MeshInstance3D",true,false):
			if not node.mesh:continue
			var materials: Array=[]
			for j in node.mesh.get_surface_count():
				var material=node.get_active_material(j)
				materials.append({"type":material.get_class() if material else "null","name":material.resource_name if material else "","shader":material.shader.resource_path if material is ShaderMaterial and material.shader else "","policy":material.get_shader_parameter("_ArenaLightingEnabled") if material is ShaderMaterial else null})
			rows.append({"name":str(node.get_path()),"visible":node.visible,"surfaces":node.mesh.get_surface_count(),"materials":materials})
		metadata.append({"hash":actor.avatar_hash,"meshes":rows})
	var camera:=Camera3D.new();g.add_child(camera);camera.far=1600;camera.near=.04;camera.fov=50
	var eye:=center+Vector3(0,1.15,-5.0);var focus:=center+Vector3.UP*1.03
	camera.position=eye;camera.look_at(focus);camera.make_current()
	for i in 30:await process_frame
	g.process_mode=Node.PROCESS_MODE_DISABLED
	var images: Array=[]
	for index in 40:
		camera.position=eye+Vector3(sin(index*2.4)*.00015 if index>=20 else 0.0,0,0);camera.look_at(focus)
		await process_frame;await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image();img.save_png(output+"/frame-%02d.png"%index)
	FileAccess.open(output+"/materials.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  "))
	print("AVATAR_FLICKER_PROBE_DONE ",RenderingServer.get_current_rendering_method())
	g.process_mode=Node.PROCESS_MODE_INHERIT;g.disconnect_game();g.free();quit()
