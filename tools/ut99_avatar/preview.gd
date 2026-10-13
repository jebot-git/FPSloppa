extends Node3D
var library:Node
var stage:Node3D
var avatars:Array=[]
var selection:OptionButton
var animation:OptionButton
var count:OptionButton
var capture_frames:=0
var timings:Array=[]
var last_tick:=0
func _ready() -> void:
	DisplayServer.window_set_title("UT99 avatars · World Leaders · original vertex animation")
	library=preload("res://deathmatch/avatars/library.gd").new();add_child(library)
	stage=Node3D.new();add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("182522");add_child(env)
	var camera:=Camera3D.new();camera.position=Vector3(0,1.05,-3.5);add_child(camera);camera.look_at(Vector3(0,.9,0));camera.fov=37;camera.current=true
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("3e5140");floor_mesh.material_override=mat;add_child(floor_mesh)
	var layer:=CanvasLayer.new();add_child(layer);var bar:=VBoxContainer.new();bar.position=Vector2(16,16);layer.add_child(bar)
	var title:=Label.new();title.text="WORLD LEADERS · UT99 ORIGINAL ANIMATIONS · 170 cm";bar.add_child(title)
	selection=OptionButton.new();bar.add_child(selection)
	for hash in library.entries:selection.add_item(library.entries[hash].title);selection.set_item_metadata(selection.item_count-1,hash)
	selection.item_selected.connect(func(_i):rebuild())
	animation=OptionButton.new();bar.add_child(animation);animation.item_selected.connect(func(_i):apply_animation())
	count=OptionButton.new();count.add_item("1 avatar",1);count.add_item("32 avatars",32);bar.add_child(count);count.item_selected.connect(func(_i):rebuild())
	var args:=OS.get_cmdline_user_args()
	if args.has("--crowd"):count.select(1)
	if args.has("--capture"):capture_frames=180
	rebuild()
func rebuild() -> void:
	for avatar in avatars:avatar.free()
	avatars.clear()
	var hash:String=selection.get_item_metadata(selection.selected)
	var amount:=count.get_selected_id()
	for i in amount:
		var avatar=library.create_avatar(hash)
		if avatar==null:push_error(library.last_error);return
		stage.add_child(avatar);avatar.unarmed=true;avatar.preview_mode=0
		if amount>1:avatar.position=Vector3((i%8-3.5)*.9,0,(i/8)*1.1);avatar.time=i*.073
		avatars.append(avatar)
	animation.clear()
	if not avatars.is_empty():
		for clip in avatars[0].clips:
			if clip.name=="All":continue
			animation.add_item(clip.name);animation.set_item_metadata(animation.item_count-1,clip.name)
		var preferred:="RunLg" if amount>1 else "Breath1"
		for i in animation.item_count:
			if animation.get_item_metadata(i)==preferred:animation.select(i)
	apply_animation()
	var camera:=get_viewport().get_camera_3d()
	camera.position=Vector3(0,3.4,-10) if amount>1 else Vector3(0,1.05,-3.5);camera.look_at(Vector3(0,.9,1.5 if amount>1 else 0))
func apply_animation() -> void:
	if animation.item_count==0:return
	for avatar in avatars:avatar.selected_sequence=str(animation.get_item_metadata(animation.selected))
func _process(_delta:float) -> void:
	var now:=Time.get_ticks_usec()
	if last_tick>0 and capture_frames>0 and capture_frames<120:timings.append((now-last_tick)/1000.0)
	last_tick=now
	if capture_frames>0:
		capture_frames-=1
		if capture_frames==0:
			await RenderingServer.frame_post_draw
			var destination:="res://test-results/ut99/crowd.png" if avatars.size()>1 else "res://test-results/ut99/preview.png"
			get_viewport().get_texture().get_image().save_png(destination)
			timings.sort()
			var report:={"avatars":avatars.size(),"median_ms":timings[timings.size()/2] if not timings.is_empty() else 0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"animation":animation.get_item_text(animation.selected),"note":"Desktop preview, not stereo, AI or physics benchmark"}
			var file:=FileAccess.open("res://test-results/ut99/preview-stats.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));print("UT99_PREVIEW ",JSON.stringify(report));get_tree().quit()
