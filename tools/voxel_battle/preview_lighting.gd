extends SceneTree
var scene
var ready:=false
const OUTPUT:="res://test-results/baked-jungle"
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if ready:scene.map.update_view(scene.camera)
	return false
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,800)
	scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;scene.map.structures.force_near=true;ready=true
	var title:=Label.new();title.position=Vector2(20,20);title.add_theme_font_size_override("font_size",24);root.add_child(title)
	var center:Vector3=scene.Landscape.CENTERS[4]
	var records:Array=[]
	for view in ["radar","interior","forest"]:
		if view=="radar":scene.camera.position=center+Vector3(-12,3.8,45);scene.camera.look_at(center+Vector3(12,2,-23))
		elif view=="interior":scene.camera.position=center+Vector3(23,1.7,-29);scene.camera.look_at(center+Vector3(23,1.7,-15))
		else:scene.set_view(0)
		await process_frame
		var begin:=Time.get_ticks_msec()
		while not scene.map.terrain.settled():
			await process_frame
			if Time.get_ticks_msec()-begin>90000:push_error("Stream timeout");quit(1);return
		for light in [1.0,0.0]:
			scene.map.lighting.phase_override=light;title.text=view.to_upper()+" · "+("BAKED DAY" if light else "BAKED NIGHT")
			await create_timer(.8).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT+"/"+view+("-day" if light else "-night")+".png")
			records.append({"view":view,"daylight":light,"grass_draws":scene.map.grass.draw_calls,"grass_instances":scene.map.grass.visible_tufts,"terrain_tiles":scene.map.terrain.resident.size()})
			print("BAKED_CAPTURE ",view," ",light)
	for mode in ["mesh","billboard","svo"]:
		scene.map.environment.set_mode(mode);scene.map.lighting.phase_override=0;title.text="FOREST · BAKED NIGHT · "+mode.to_upper()
		scene.map.environment.last_position=Vector3.INF
		await create_timer(.8).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/forest-night-"+mode+".png")
		print("BAKED_MODE_CAPTURE ",mode)
	FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"bake":scene.map.lighting.metadata,"views":records},"\t"))
	scene.map.terrain.shutdown();quit()
