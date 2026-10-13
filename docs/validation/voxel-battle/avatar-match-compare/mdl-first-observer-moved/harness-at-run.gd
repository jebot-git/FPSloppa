extends "res://tools/voxel_battle/run.gd"
const ACCEPTED=["sample_d_darkness","sample_e","sample_f","sample_g","hairsample_female","hairsample_male"]
var representation:="vrm"
var assignments: Array=[]
var eyes: Array[SubViewport]=[]
var eye_cameras: Array[Camera3D]=[]
var began_usec:=0
var wall_seconds:=120.0
func prepare_avatars() -> bool:
	game.avatars.set_process(false);game.avatars.load_queue.clear()
	var library=game.avatars.library
	var ids: Array=game.players.keys();ids.sort()
	var assets: Dictionary={}
	for name in ACCEPTED:
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experimental-assets/mdl/"+name+".json"))
		var hash: String=metadata.source.hash
		var path: String="/home/blux/Documents/FPSloppa/vrm/"+name+".vrm"
		assert(FileAccess.get_sha256(path)==hash)
		library.entries[hash]={"path":path,"hash":hash,"title":metadata.source.title};library.pinned.append(hash)
		if representation=="mdl":assets[name]=preload("res://tools/vrm_to_mdl/model.gd").load_model("res://experimental-assets/mdl/"+name+".mdl")
	for i in ids.size():
		var id: int=ids[i];var name: String=ACCEPTED[i%ACCEPTED.size()]
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experimental-assets/mdl/"+name+".json"))
		game.avatars.choices[id]={"hash":metadata.source.hash}
		assignments.append({"id":id,"team":game.players[id].team,"model":name,"source_hash":metadata.source.hash})
		if representation=="mdl":
			var rig:=preload("res://tools/vrm_to_mdl/match_rig.gd").new();rig.setup(assets[name],metadata);game.fighters[id].set_avatar(rig,metadata.source.hash)
	if representation=="vrm" and not prepass.prepare(game):return false
	if representation=="mdl":prepass.report={"enabled":false,"avatars":32,"springs_enabled":false,"runtime_skeletons":0,"animation":"GPU vertex frames"}
	game.frag_limit=100000 # Duration is bounded by the harness, not score.
	root.disable_3d=true
	camera.position=Vector3(0,260,170);camera.look_at(Vector3(0,15,0));camera.fov=90;camera.far=1400
	var layer:=CanvasLayer.new();root.add_child(layer)
	for index in 2:
		var eye:=SubViewport.new();root.add_child(eye);eye.size=Vector2i(2160,2376);eye.world_3d=root.world_3d;eye.render_target_update_mode=SubViewport.UPDATE_ALWAYS;eye.msaa_3d=Viewport.MSAA_DISABLED
		var eye_camera:=Camera3D.new();eye.add_child(eye_camera);eye_camera.global_transform=camera.global_transform;eye_camera.position+=camera.basis.x*((index-.5)*.064);eye_camera.fov=90;eye_camera.far=1400;eye_camera.near=.08;eye_camera.current=true
		eyes.append(eye);eye_cameras.append(eye_camera);probe.measured_viewports.append(eye.get_viewport_rid())
		var view:=TextureRect.new();layer.add_child(view);view.texture=eye.get_texture();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.position=Vector2(index*720,0);view.size=Vector2(720,900)
	view_label="fixed stereo overview"
	return true
func run() -> void:
	var args:=OS.get_cmdline_user_args();var at:=args.find("--representation")
	if at>=0:representation=args[at+1]
	assert(representation in ["vrm","mdl"])
	at=args.find("--seconds");if at>=0:wall_seconds=float(args[at+1])
	await super.run()
	seed(1977);began_usec=Time.get_ticks_usec()
	print("COMPARISON_READY ",representation," teams=",teams," assignments=",JSON.stringify(assignments))
func _physics_process(delta: float) -> bool:
	if started and not finished and (Time.get_ticks_usec()-began_usec)/1000000.0>=wall_seconds:
		finished=true;finish.call_deferred();return false
	return super._physics_process(delta)
func finish() -> void:
	var performance:=probe.result()
	var report:={"representation":representation,"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"seed":1977,"teams":teams,"assignments":assignments,"mode":"tdm","loadout":"cs","jetpacks":true,"wall_seconds":(Time.get_ticks_usec()-began_usec)/1000000.0,"simulation_seconds":elapsed,"scores":game.match_mode.scores,"events":metrics.counts,"damage":metrics.damage,"physics_ms":Probe.summary(ticks),"bot_ai_ms":Probe.summary(game.bots.tick_ms),"performance":performance,"avatar_prepass":prepass.report,"springs":false,"stereo":"two desktop viewports, identical fixed cameras","per_eye_size":[2160,2376],"ipd_m":.064,"camera_position":str(camera.position),"fov":90,"limits":"One seeded match per representation. Same source avatars and gameplay settings, but low-poly MDL geometry/materials/pose system versus optimized VRM. Combat divergence is recorded, not suppressed."}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await RenderingServer.frame_post_draw
	for i in 2:eyes[i].get_texture().get_image().save_png(output+("/left.png" if i==0 else "/right.png"))
	root.get_texture().get_image().save_png(output+"/preview.png")
	print("COMPARISON_RESULT ",JSON.stringify(report))
	game.disconnect_game();quit()
