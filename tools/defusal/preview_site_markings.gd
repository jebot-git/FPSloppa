extends SceneTree
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
var g
func _initialize():run.call_deferred()
func point(p: Array) -> Vector3:return Vector3((p[1]-300)*6,p[2],(400-p[0])*6)/32.0
func capture(path: String,eye: Vector3,target: Vector3):
	g.camera.position=eye;g.camera.look_at(target);g.camera.fov=72
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;AudioServer.set_bus_mute(0,true)
	var selected:=OS.get_cmdline_user_args()
	for map in Maps.IDS:
		if not selected.is_empty() and not map in selected:continue
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=map;g.start_host("DE site markings",0,20,10,true,"de")
		g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);g.hud.hide()
		if is_instance_valid(g.viewmodel):g.viewmodel.hide()
		for actor in g.fighters.values():actor.hide()
		g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var folder: String="res://maps/Dust2Rebuilt/" if map=="de_dust2_rebuilt" else "res://maps/ClassicDE/"+map+"/"
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"manifest.json"))
		var marks: Array=data.get("site_markings",[{"site":"A","cross":[184,132,224],"wall":[150,127,301],"normal":[1,0]},{"site":"B","cross":[184,531,64],"wall":[135,489,148],"normal":[1,0]}])
		await physics_frame;await physics_frame
		g.match_mode.defusal.tick(0);g.match_mode.defusal.draw()
		for mark in marks:
			var floor_point:=point(mark.cross);var wall_point:=point(mark.wall)
			var normal:=Vector3(mark.normal[1],0,-mark.normal[0])
			var prefix: String="res://test-results/de-site-markings/"+map+"-"+mark.site.to_lower()
			var eye:=floor_point+normal*.3+Vector3.UP*3
			var space=g.get_world_3d().direct_space_state
			for offset in [normal*.3+Vector3.UP*2.8+normal.cross(Vector3.UP)*1.8,normal*.3+Vector3.UP*2.8-normal.cross(Vector3.UP)*1.8,normal*.3+Vector3.UP*3]:
				var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*.2,floor_point+offset,1))
				if hit.is_empty():eye=floor_point+offset;break
			await capture(prefix+"-cross.png",eye,floor_point)
			var sight: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(wall_point+normal*4,wall_point-normal*.1,1))
			assert(not sight.is_empty() and sight.position.distance_to(wall_point)<.1,"Obscured wall marking: "+map+" "+mark.site)
			await capture(prefix+"-letter.png",wall_point+normal*4,wall_point)
		print("DE_SITE_VISUAL_PASS ",map)
		g.disconnect_game();g.free();await process_frame
	quit()
