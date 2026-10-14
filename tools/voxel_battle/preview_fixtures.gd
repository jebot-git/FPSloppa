extends SceneTree
## Standing eye-height capture of every POI, with an animated UT99 player and NVG comparison.
const OUTPUT:="res://test-results/poi-fixtures"
var scene
var ready:=false
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if ready:scene.map.update_view(scene.camera)
	return false
func capture(label:String) -> void:
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")==OK)
	print("FIXTURE_CAPTURE ",label)
func live_lights(node:Node) -> int:
	var count:=1 if node is Light3D and node.is_visible_in_tree() and node.light_energy>0 else 0
	for child in node.get_children():count+=live_lights(child)
	return count
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,800)
	scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;ready=true
	for child in scene.get_children():
		if child is WorldEnvironment:child.compositor=Compositor.new();child.compositor.compositor_effects=[effect]
	var library=preload("res://deathmatch/avatars/library.gd").new();scene.add_child(library)
	var manifest:Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	var avatar=library.create_avatar(manifest[0].hash);assert(avatar!=null);scene.add_child(avatar);avatar.unarmed=true;avatar.selected_sequence="Breath1";avatar.preview_mode=-1;avatar.tracked_arms_enabled=false
	var title:=Label.new();title.position=Vector2(20,20);title.add_theme_font_size_override("font_size",22);root.add_child(title)
	var records:Array=[]
	var args:=OS.get_cmdline_user_args()
	var only:=int(args[args.find("--site")+1]) if args.has("--site") else -1
	for kind in 11:
		if only>=0 and kind!=only:continue
		var center:Vector3=scene.Landscape.CENTERS[kind]
		scene.camera.position=center+Vector3(0,1.7,48);scene.camera.look_at(center+Vector3(0,1.7,10))
		avatar.position=center+Vector3(5,.15,35)
		scene.map.lighting.phase_override=0;title.text=scene.Landscape.sites()[kind].name.to_upper()+" · BAKED NIGHT · NVG OFF"
		var deadline:=Time.get_ticks_msec()+90000
		while not scene.map.terrain.settled():
			await process_frame
			if Time.get_ticks_msec()>deadline:push_error("Terrain stream timeout");quit(1);return
		await capture("site-%02d-night"%kind)
		records.append({"kind":kind,"visible_fixture_groups":scene.map.lighting.fixture_groups.filter(func(group):return group.visible).size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		if kind==4:
			effect.configure(6000,false,0,1);effect.enabled=true;title.text="RADAR · STANDARD NVG";await capture("radar-nvg");effect.enabled=false
			scene.map.lighting.phase_override=1;title.text="RADAR · BAKED DAY";await capture("radar-day")
	assert(live_lights(scene)==0,"POI lighting must remain exclusively baked")
	FileAccess.open(OUTPUT+("/result.json" if only<0 else "/result-site-%02d.json"%only),FileAccess.WRITE).store_string(JSON.stringify({"fixtures":scene.map.lighting.metadata.lamps.size(),"runtime_lights":live_lights(scene),"views":records},"\t"))
	scene.map.terrain.shutdown();RenderingServer.call_on_render_thread(effect.release);quit()
