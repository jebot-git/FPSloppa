extends SceneTree
## Native renderer review through the real map/cache selector and DE presentation.
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
var g
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func capture(path: String,eye: Vector3,target: Vector3):
	g.camera.global_position=eye;g.camera.look_at(target);g.camera.fov=78
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.title="DE material review"
	AudioServer.set_bus_mute(0,true)
	var rows: Array=[]
	var selected:=OS.get_cmdline_user_args()
	if not selected.is_empty() and FileAccess.file_exists("res://test-results/de-texturing/views.json"):
		rows=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/de-texturing/views.json"))
	for id in Maps.IDS:
		if not selected.is_empty() and not id in selected:continue
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=id;g.start_host("DE visual review",0,20,10,true,"de")
		g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
		g.menu_open=false;g.hud.hide()
		if is_instance_valid(g.viewmodel):g.viewmodel.hide()
		if not is_instance_valid(g.camera):
			g.camera=Camera3D.new();g.add_child(g.camera);g.camera.make_current()
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		for actor in g.fighters.values():actor.hide()
		await physics_frame;await physics_frame
		var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0);de.clear_visuals();de.draw()
		var labels: Array=[]
		for label in de.visuals.find_children("*","Label3D",true,false):
			if label!=de.visuals.hint and not de.visuals.bomb.is_ancestor_of(label):labels.append(label)
		assert(labels.is_empty(),"Floating site text: "+id)
		var folder: String="res://maps/Dust2Rebuilt/" if id=="de_dust2_rebuilt" else "res://maps/ClassicDE/"+id+"/"
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"manifest.json"))
		var shots: Array=[]
		for view in data.views:
			var file: String=id+"-"+view.name+".png";await capture("res://test-results/de-texturing/"+file,p(view.eye),p(view.look));shots.append(file)
		for site in 2:
			var target: Vector3=de.sites[site]+Vector3.UP*.5
			var eye:=target+Vector3(2,2,3)
			var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target,eye,1))
			if not hit.is_empty():eye=hit.position+hit.normal*.3
			var file: String=id+"-site-"+("a" if site==0 else "b")+".png"
			await capture("res://test-results/de-texturing/"+file,eye,target);shots.append(file)
		rows=rows.filter(func(row):return row.map!=id)
		rows.append({"map":id,"sha256":FileAccess.get_sha256("res://maps/"+id+".bsp"),"floating_site_labels":labels.size(),"images":shots,"renderer":RenderingServer.get_current_rendering_method()})
		print("DE_VISUAL_REVIEW_PASS ",id)
		g.disconnect_game();g.free();await process_frame
	FileAccess.open("res://test-results/de-texturing/views.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
