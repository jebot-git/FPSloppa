extends SceneTree
## Rendered diagnostic: profile sampler-only switches and pipeline reuse.
class Probe extends "res://deathmatch/maps/filtering.gd":
	var omit_pixels:=false
	var pixel_us:=0
	var image_reads:=0
	var rebuilt:=0
	var shader_changes:=0
	func texture(source: Texture2D) -> Texture2D:
		if omit_pixels:return source
		var read_image:=source!=null and not source is ViewportTexture and not source.has_mipmaps() and not textures.has(source)
		var before:=Time.get_ticks_usec()
		var result:=super.texture(source)
		pixel_us+=Time.get_ticks_usec()-before
		if read_image:image_reads+=1
		if source!=result:rebuilt+=1
		return result
	func material(source: Material) -> void:
		var shader: Shader=source.shader if source is ShaderMaterial else null
		super.material(source)
		if shader and source.shader!=shader:shader_changes+=1
var records: Array=[]
func _initialize():call_deferred("run")
func pipelines() -> Dictionary:
	var result: Dictionary={}
	for key in ClassDB.class_get_integer_constant_list("Performance"):
		if "PIPELINE" in key:result[key]=Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",key))
	return result
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Run this diagnostic with a real renderer, --xr-mode off.");quit(1);return
	Engine.max_fps=144
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.voice.set_mode(0)
	game.start_host("Filter profiling",0,20,10,true)
	game.menu_open=true;game.hud.show_menu(true)
	if game.bots:game.bots.free();game.bots=null
	if OS.get_cmdline_user_args().has("--baked-fixture"):
		var image:=Image.create(32,32,true,Image.FORMAT_RGB8);image.fill(Color.WHITE)
		var texture:=ImageTexture.create_from_image(image)
		var baked:=ShaderMaterial.new();baked.shader=load("res://deathmatch/maps/baked_light.gdshader")
		baked.set_shader_parameter("base_texture",texture);baked.set_shader_parameter("bake_texture",texture)
		var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.material_override=baked;quad.position.z=-2
		game.camera.add_child(quad)
		Probe.new().apply(quad)
	await create_timer(3).timeout
	var audit:=Probe.new()
	for node in game.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		for surface in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(surface)
			if mat is BaseMaterial3D and audit.textured(mat) and not mat.has_meta(audit.BANK):print("UNPREPARED_FILTER_MATERIAL ",node.get_path()," ",mat.resource_path)
	for pixels in [true,false,true,false]:
		for mode in [-1,0,1,2]:
			await process_frame
			var probe:=Probe.new();probe.omit_pixels=not pixels
			var counters:=pipelines()
			var begin:=Time.get_ticks_usec()
			if mode>=0:probe.apply(game,mode,false)
			var cpu_ms:=(Time.get_ticks_usec()-begin)/1000.0
			await RenderingServer.frame_post_draw
			var draw_ms:=(Time.get_ticks_usec()-begin)/1000.0
			var worst:=0.0;var last:=Time.get_ticks_usec()
			for i in 12:
				await process_frame
				var now:=Time.get_ticks_usec();worst=maxf(worst,(now-last)/1000.0);last=now
			var counts:=pipelines()
			for key in counts:counts[key]-=counters[key]
			var row:={"map":game.current_map,"pipelines":counts,"pixels":pixels,"mode":mode,"cpu_ms":cpu_ms,"pixel_ms":probe.pixel_us/1000.0,"image_reads":probe.image_reads,"rebuilt_textures":probe.rebuilt,"changed_shaders":probe.shader_changes,"materials":probe.materials.size(),"to_draw_ms":draw_ms,"following_frame_max_ms":worst}
			records.append(row);print("FILTER_SWITCH_SAMPLE ",JSON.stringify(row))
			await create_timer(.2).timeout
	var args:=OS.get_cmdline_user_args();var index:=args.find("--profile-output")
	var output:=args[index+1].get_file() if index>=0 and index+1<args.size() else "filter-switch-optimised.json"
	print("FILTER_WARMUP_NODES ",game.find_children("FilterWarmup","Node3D",true,false).size())
	var file:=FileAccess.open("res://test-results/"+output,FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
	game.request_quit()
