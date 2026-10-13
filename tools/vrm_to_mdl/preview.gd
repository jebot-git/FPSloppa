extends SceneTree
var materials: Array[ShaderMaterial]=[]
var meta: Array=[]
var output:="res://experimental-assets/mdl"
var live:=false
var elapsed:=0.0
var playback_speed:=1.0
var playback_paused:=false
var selector: OptionButton
var details: Label
func _process(delta: float) -> bool:
	if live:
		if not playback_paused:elapsed+=delta*playback_speed
		for material in materials:material.set_shader_parameter("animation_clock",elapsed)
	return false
func select_clip(index: int) -> void:
	elapsed=0.0
	var name:=selector.get_item_text(index).to_lower()
	for i in materials.size():
		var row: Dictionary=meta[i].clips.filter(func(c):return c.name==name)[0]
		materials[i].set_shader_parameter("clip_start",int(row.start))
		materials[i].set_shader_parameter("clip_count",int(row.count))
		materials[i].set_shader_parameter("clip_fps",float(row.fps))
		materials[i].set_shader_parameter("clip_loop",bool(row.loop))
		materials[i].set_shader_parameter("animation_clock",elapsed)
	var row: Dictionary=meta[0].clips[index]
	details.text="%d frames · %d FPS · %s" % [row.count,row.fps,"loop" if row.loop else "plays once"]
	print("MDL_LIVE_CLIP ",name)
func live_controls() -> void:
	root.title="FPSloppa — experimental MDL avatar gallery"
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var panel:=PanelContainer.new();canvas.add_child(panel);panel.position=Vector2(20,20)
	var margin:=MarginContainer.new();panel.add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
	var box:=VBoxContainer.new();margin.add_child(box)
	var title:=Label.new();title.text="11 low-poly MDL avatars · 170 cm · baked vertex animation";box.add_child(title)
	var row:=HBoxContainer.new();box.add_child(row);row.add_theme_constant_override("separation",12)
	selector=OptionButton.new();selector.custom_minimum_size=Vector2(150,38)
	for clip in meta[0].clips:selector.add_item(String(clip.name).capitalize())
	row.add_child(selector);selector.item_selected.connect(select_clip)
	var restart:=Button.new();restart.text="Restart";row.add_child(restart);restart.pressed.connect(func():elapsed=0.0)
	var pause:=CheckButton.new();pause.text="Pause";row.add_child(pause);pause.toggled.connect(func(value):playback_paused=value)
	var speed:=OptionButton.new()
	for text in ["0.5× speed","1× speed","2× speed"]:speed.add_item(text)
	speed.select(1);row.add_child(speed);speed.item_selected.connect(func(index):playback_speed=[.5,1.0,2.0][index])
	details=Label.new();box.add_child(details)
	select_clip(0)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var env:=WorldEnvironment.new();root.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.10,.14,.18)
	var plane:=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(30,30);plane.position.y=-.015;root.add_child(plane)
	var ground:=StandardMaterial3D.new();ground.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ground.albedo_color=Color(.16,.19,.20);plane.material_override=ground
	var camera:=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.2;camera.position=Vector3(0,9,10);camera.look_at(Vector3(0,.6,-2.3));camera.current=true
	var names:=Array(DirAccess.get_files_at(output)).filter(func(s):return s.ends_with(".mdl"));names.sort()
	for i in names.size():
		var built:=preload("res://tools/vrm_to_mdl/model.gd").load_model(output.path_join(names[i]));materials.append(built[1])
		var model:=MeshInstance3D.new();model.mesh=built[0];model.material_override=built[1];root.add_child(model)
		model.rotation.y=PI
		model.position=Vector3((i%6-2.5)*1.65,0,-int(i/6)*4.8);model.custom_aabb=AABB(Vector3(-1,0,-1),Vector3(2,2,2))
		var label:=Label3D.new();label.text=names[i].trim_suffix(".mdl");root.add_child(label);label.position=model.position+Vector3(0,.05,.45);label.font_size=28;label.pixel_size=.003;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		meta.append(JSON.parse_string(FileAccess.get_file_as_string(output.path_join(names[i].trim_suffix(".mdl")+".json"))))
	if "--live" in OS.get_cmdline_user_args():
		live=true
		live_controls()
		if "--smoke" in OS.get_cmdline_user_args():
			for index in selector.item_count:
				selector.select(index);selector.item_selected.emit(index)
				for frame in 30:await process_frame
			selector.select(0);selector.item_selected.emit(0)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("live-preview.png"))
			print("MDL_LIVE_SELECTOR_OK clips=",selector.item_count," models=",materials.size())
		return
	for clip in ["idle","walk","run","death"]:
		for i in materials.size():
			var row: Dictionary=meta[i].clips.filter(func(c):return c.name==clip)[0]
			materials[i].set_shader_parameter("clip_start",int(row.start));materials[i].set_shader_parameter("clip_count",int(row.count));materials[i].set_shader_parameter("clip_fps",float(row.fps))
		for frame in 60:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("gallery-"+clip+".png"))
	print("MDL_PREVIEW models=",names.size()," skeletons=0 morphs=0 CPU_animation=0 vertex_animation=GPU")
	quit()
