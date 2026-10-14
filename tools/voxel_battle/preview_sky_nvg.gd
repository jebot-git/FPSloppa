extends SceneTree
const OUTPUT:="res://test-results/staged-jungle"
var scene
var ready:=false
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
func _initialize()->void:run.call_deferred()
func _process(_delta:float)->bool:
	if ready:scene.map.update_view(scene.camera)
	return false
func capture(label:String)->void:
	await create_timer(.8).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")==OK);print("SKY_CAPTURE ",label)
func settle()->void:
	var begin:=Time.get_ticks_msec()
	while not scene.map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()-begin>90000:push_error("Terrain timeout");quit(1);return
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,800)
	scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;ready=true
	for child in scene.get_children():
		if child is WorldEnvironment:child.compositor=Compositor.new();child.compositor.compositor_effects=[effect]
	var center:Vector3=scene.Landscape.CENTERS[4]
	scene.camera.position=center+Vector3(-50,19,65);scene.camera.look_at(center+Vector3(-23,14,23));scene.map.structures.force_near=true
	await settle()
	var names:=["day","golden","dusk","twilight","night","dawn-twilight","dawn","morning"]
	var times:=[0,288,348,396,600,804,852,912]
	for i in names.size():
		scene.map.lighting.phase_override=-1;scene.map.lighting.synchronize(times[i]);await capture("radar-"+names[i])
	scene.camera.position=center+Vector3(-29,12,33);scene.camera.look_at(center+Vector3(-23,12.5,23));scene.map.lighting.phase_override=1;await capture("dish-support")
	scene.set_view(0);await settle();scene.map.lighting.phase_override=0
	await capture("forest-night")
	for scout in [false,true]:
		effect.configure(6000,scout,0,1);effect.enabled=true;await capture("forest-nvg-"+("scout" if scout else "standard"))
	effect.configure(6000,false,1,1);await capture("nvg-blinded");effect.enabled=false
	for i in [0,2,3,4,5,6,7]:
		scene.map.lighting.phase_override=-1;scene.map.lighting.synchronize(times[i]);await capture("forest-"+names[i])
	scene.map.terrain.shutdown();RenderingServer.call_on_render_thread(effect.release);quit()
