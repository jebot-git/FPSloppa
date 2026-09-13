extends SceneTree
## Compare pre-baked AO by swapping one atlas in the SAME live scene.
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/lighting-ao/"
var rows: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func baked_materials(level: Node) -> Array:
	var filter:=Filtering.new();filter.apply(level,2,true,1)
	return filter.materials.keys().filter(func(mat):return mat is ShaderMaterial and mat.shader==Filtering.BAKED)
func uv_signature(level: Node) -> Array:
	var result: Array=[]
	for node in level.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		for i in node.mesh.get_surface_count():
			var uv=node.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV2]
			if uv==null:continue
			var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(uv.to_byte_array());result.append(digest.finish().hex_encode())
	result.sort();return result
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	var output:=OUT+RenderingServer.get_current_rendering_method()+"/";DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.hud.hide();game.voice.set_mode(0)
	game.presentation.texture_filter=2;game.presentation.contrast_lighting=true
	root.msaa_3d=Viewport.MSAA_4X;root.scaling_3d_scale=1
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"bake.json"))
	for input in prepared.maps:
		if input.has("rejected"):continue
		var map: String=input.map
		var path: String=OUT+map+"-off.bsp";var hash:=FileAccess.get_sha256(path)
		game.match_mode.kind="dm";game.map_catalog=[{"id":map,"title":map,"path":path,"sha256":hash,"scene":OUT+"cache/"+hash+".scn"}]
		check(game._load_map(map),map+": off bake load")
		var level: Node=game.get_node("Map").get_child(0)
		var low:=Loader.read(OUT+map+"-low.bsp")
		check(low!=null,map+": AO import")
		if not low:continue
		for node in [level,low]:
			check(node.get_meta("baked_light_invalid_faces",-1)==0 and node.get_meta("baked_light_overflow_faces",-1)==0,map+": valid lightmap")
		var materials:=baked_materials(level);var low_materials:=baked_materials(low)
		check(uv_signature(level)==uv_signature(low),map+": identical atlas UVs")
		check(materials.size()==low_materials.size() and not materials.is_empty(),map+": same material count")
		var off_atlas: Texture2D=materials[0].get_shader_parameter("bake_texture")
		var low_atlas: Texture2D=low_materials[0].get_shader_parameter("bake_texture")
		check(off_atlas.get_size()==low_atlas.get_size(),map+": same atlas dimensions")
		for mat in materials:check(mat.get_shader_parameter("bake_texture")==off_atlas,map+": single original atlas")
		for mat in low_materials:check(mat.get_shader_parameter("bake_texture")==low_atlas,map+": single AO atlas")
		low.free();low_materials.clear()
		for node in game.get_node("Map").find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
		var camera: Camera3D=game.get_node("Overview");game.camera=camera
		var views: Array=[]
		if map=="tf_pressureworks":views=[[Vector3(16.25,2.2,23.75),Vector3(0,5.6,-9.4),"turbine"],[Vector3(-7.5,1.7,-51.25),Vector3(0,1.25,-55.5),"flag"]]
		elif map=="tf_vesper":views=[[Vector3(18,2.2,24),Vector3(-8,12,-28),"nave"],[Vector3(7,9.7,-50),Vector3(9.5,9.2,-58.5),"sanctuary"]]
		else:
			var coverage: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/lighting-coverage/mobile/render.json"))
			for row in coverage.records:
				if row.id=="external-optin" and row.pass==0:
					var pos:=Vector3(row.camera[0],row.camera[1],row.camera[2]);var direction:=Vector3(row.look[0],row.look[1],row.look[2])
					views.append([pos,pos+direction*20,"spawn"+str(int(row.view))])
		check(views.size()==2,map+": two views")
		for view in views:
			camera.position=view[0];camera.look_at(view[1]);camera.make_current()
			game.get_node("Map/MapRuntime")._process(1.0)
			for contrast in [false,true]:
				Filtering.new().apply(level,2,false,int(contrast))
				for pass_index in 4:
					var enabled: bool=[false,true,true,false][pass_index]
					for mat in materials:mat.set_shader_parameter("bake_texture",low_atlas if enabled else off_atlas)
					for i in 45:await process_frame
					var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var textures: Array=[]
					for i in 180:
						await process_frame
						gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
						draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));textures.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
					rows.append({"map":map,"view":view[2],"contrast":contrast,"ao":enabled,"pass":pass_index,"gpu_ms":stats(gpu),"cpu_ms":stats(cpu),"draws":stats(draws),"texture_bytes":stats(textures),"atlas_size":[off_atlas.get_width(),off_atlas.get_height()]})
					if pass_index in [0,1,3]:
						await RenderingServer.frame_post_draw
						var suffix: String=["off","low","unused","restored"][pass_index]
						root.get_texture().get_image().save_png(output+map+"-"+view[2]+("-contrast-" if contrast else "-classic-")+suffix+".png")
			print("AO_RENDER ",map," ",view[2])
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"resolution":[1280,800],"msaa":4,"measured_frames":rows.size()*180,"records":rows,"failures":failures}
	FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free();for i in 3:await process_frame
	print("AO_RESULT ",failures);quit(0 if failures.is_empty() else 1)
