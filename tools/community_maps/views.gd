extends SceneTree
func _initialize() -> void:run.call_deferred()
func q(x: float,y: float,z: float,sx: float,sy: float) -> Vector3:return Vector3(-y*sy,z,-x*sx)/32.0
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	root.title="FPSloppa map texture review"
	# A renderer-only scene avoids initializing menu/audio/avatar singletons.
	var world:=Node3D.new();root.add_child(world)
	var holder:=Node3D.new();holder.name="Map";world.add_child(holder)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color(.10,.13,.18)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.48,.57,.7);env.ambient_light_energy=.6;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=85;camera.far=300;camera.make_current()
	for id in ["as_hislop","as_frigate","dm_lasercade_slop","dm_auhdm2_slop"]:
		var level=load("res://maps/cache/"+id+"-lightmap1.scn").instantiate();world.get_node("Map").add_child(level)
		var views: Array=[]
		if id=="as_hislop":
			views=[[q(-2360,-640,700,1.75,1.25),q(-128,0,48,1.75,1.25)],[q(744,0,64,1.75,1.25),q(464,0,64,1.75,1.25)],[q(1992,112,208,1.75,1.25),q(2028,-96,200,1.75,1.25)]]
		elif id=="as_frigate":
			views=[[q(1472,-1232,704,1.6,1.3),q(-160,0,176,1.6,1.3)],[q(-704,-64,56,1.6,1.3),q(-896,32,48,1.6,1.3)],[q(-160,112,56,1.6,1.3),q(-560,112,56,1.6,1.3)]]
		else:
			for node in level.get_children():
				if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch":
					var pos: Vector3=node.global_position+Vector3.UP*.9
					var yaw:=deg_to_rad(float(node.attributes.get("angle",0)))
					views.append([pos,pos+Vector3(-sin(yaw),-.1,-cos(yaw))*6])
					if views.size()==3:break
		for i in views.size():
			camera.position=views[i][0];camera.look_at(views[i][1])
			for frame in 5:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/community-views/"+id+"-"+str(i)+".png")
			print("MAP_VIEW ",id," ",i)
		level.free()
	world.free();quit.call_deferred()
