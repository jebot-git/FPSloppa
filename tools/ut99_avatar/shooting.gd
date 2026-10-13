extends "res://tools/voxel_battle/run.gd"
## Production movement, CS fire/impacts and pooled FX. Lifecycle slots only, no AI.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var actor_ids:Array=[]
var rng:=RandomNumberGenerator.new()
var direction_at:Dictionary={}
var input_times:Array=[]
var arm_times:Array=[]
var visible_counts:Array=[]
var poses_valid:=0
var tracked_arms:=true
var tracked_counts:Array=[]
var eye_viewports:Array[SubViewport]=[]
var eye_cameras:Array[Camera3D]=[]
var began_usec:=0
var wall_seconds:=120.0
var warming:=true
var formation:Array=[]
var assignment:Array=[]
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/ut99_avatar/benchmark_arena.gd") if avatar_count==64 else preload("res://tools/vrm_to_mdl/no_ai_arena.gd"));return scene
func prepare_avatars() -> bool:
	game.voice.set_mode(0);game.voice.set_process(false)
	if not super.prepare_avatars():return false
	actor_ids=game.players.keys();actor_ids.sort();rng.seed=1977
	game.frag_limit=100000
	var point:Vector3=Landscape.FUTURE_SITES[3].position
	for i in actor_ids.size():
		var id:int=actor_ids[i];var actor=game.fighters[id]
		var x:float=point.x+(i%8-3.5)*2;var z:float=point.z-int(i/8)*2.5
		actor.position=Vector3(x,Landscape.surface(x,z).x+.05,z);actor.reset_physics_interpolation()
		formation.append([x,actor.position.y,z]);assignment.append({"id":id,"hash":actor.avatar_hash,"title":game.avatars.library.entries[actor.avatar_hash].title})
		actor.avatar.tracked_arms_enabled=tracked_arms
		actor.xr_pose=Poses.neutral();game.players[id].xr=actor.xr_pose;game.players[id].vr_device=true;actor.avatar.target_xr_pose=actor.xr_pose
		game.players[id].hp=1000000;game.players[id].cs_reserve=[999999,999999,999999,0]
		direction_at[id]=-1.0
	camera.position=Vector3(point.x,point.y+1.7,point.z+10);camera.rotation=Vector3.ZERO;camera.fov=90;camera.near=.08;camera.far=1400
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.disable_3d=true
	var layer:=CanvasLayer.new();root.add_child(layer)
	for i in 2:
		var eye:=SubViewport.new();root.add_child(eye);eye.size=Vector2i(2160,2376);eye.world_3d=root.world_3d;eye.render_target_update_mode=SubViewport.UPDATE_ALWAYS;eye.msaa_3d=Viewport.MSAA_DISABLED
		var eye_camera:=Camera3D.new();eye.add_child(eye_camera);eye_camera.global_transform=camera.global_transform;eye_camera.position+=Vector3((i-.5)*.064,0,0);eye_camera.fov=90;eye_camera.near=.08;eye_camera.far=1400;eye_camera.current=true;eye_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		eye_viewports.append(eye);eye_cameras.append(eye_camera);probe.measured_viewports.append(eye.get_viewport_rid())
		var image:=TextureRect.new();layer.add_child(image);image.texture=eye.get_texture();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.position=Vector2(i*720,0);image.size=Vector2(720,900)
	view_label="UT99 %d shooting · controller arms %s · AI 0"%[avatar_count,"ON" if tracked_arms else "OFF"]
	game._weapon_visuals()
	return true
func run() -> void:
	var args:=OS.get_cmdline_user_args();var at:=args.find("--seconds")
	if at>=0:wall_seconds=maxf(1,float(args[at+1]))
	tracked_arms=not args.has("--no-controller-arms")
	await super.run()
	started=false
	for frame in 180:await process_frame
	probe.series.clear();probe.views.clear();probe.samples=0
	probe.csv.close();probe.setup(output,root.get_viewport_rid())
	game.variant_visuals.reset_pool_stats()
	ticks.clear();elapsed=0;began_usec=Time.get_ticks_usec();warming=false;started=true
	print("UT99_SHOOTING_READY count=",actor_ids.size()," controller_arms=",tracked_arms," views=2160x2376 seed=1977")
func _input(_event:InputEvent) -> void:pass
func _physics_process(delta:float) -> bool:
	if started and not finished:
		if not warming and (Time.get_ticks_usec()-began_usec)/1e6>=wall_seconds:
			finished=true;finish.call_deferred();return false
		var before:=Time.get_ticks_usec()
		for i in actor_ids.size():
			var id:int=actor_ids[i];var state:Dictionary=game.players[id]
			if game.clock>=direction_at[id]:
				state.yaw=rng.randf_range(-PI,PI);state.pitch=rng.randf_range(-.35,.35);direction_at[id]=game.clock+rng.randf_range(.8,2)
			state.move=Vector2.ZERO;state.fire=true;state.alt_fire=false;state.offhand_fire=false;state.jump=false;state.input_blocked=false;state.last_input=game.clock;state.hp=1000000
			var t:float=game.clock+i*.31
			var pose:=Poses.neutral()
			pose.head=Transform3D(Basis(Vector3.UP,sin(t*.55)*.18),Vector3(sin(t*.8)*.025,1.65+sin(t)*.02,0))
			pose.left=Transform3D(Basis(Vector3.RIGHT,state.pitch),Vector3(-.25+sin(t)*.08,1.24+cos(t*.7)*.09,-.35+cos(t)*.09))
			pose.right=Transform3D(Basis(Vector3.UP,sin(t*.8)*.2)*Basis(Vector3.RIGHT,state.pitch),Vector3(.24+sin(t*.9)*.07,1.25+sin(t*.7)*.08,-.34+sin(t)*.09))
			pose.weapon=pose.right;pose.height=1.65
			state.xr=Poses.validate(pose);state.vr_device=true
			if not state.xr.is_empty():poses_valid+=1
		input_times.append((Time.get_ticks_usec()-before)/1000.0)
	return super._physics_process(delta)
func _process(delta:float) -> bool:
	var prior:=camera.transform if camera!=null else Transform3D.IDENTITY
	var result:=super._process(delta)
	if camera!=null:camera.transform=prior
	if started and not finished:
		var visible:=0;var active:=0;var arm_ms:=0.0
		for i in actor_ids.size():
			var id:int=actor_ids[i];var actor=game.fighters[id]
			var cycle:int=(int(elapsed/4)+i)%3
			actor.rotation.y=game.players[id].yaw;actor.visual_pitch=game.players[id].pitch;actor.visual_velocity=actor.basis*Vector3(0,0,-[0.,2.,6.][cycle]);actor.visual_grounded=true
			# Authoritative stationary physics plus visual idle/walk/run as in prior test.
			actor.avatar.speed=[0.,2.,6.][cycle];actor.avatar.preview_mode=cycle
			actor.avatar.target_xr_pose=game.players[id].xr
			if actor.avatar.tracked_arms_active:active+=1
			arm_ms+=actor.avatar.arm_update_ms
			if eye_cameras[0].is_position_in_frustum(actor.position+Vector3.UP*.85) and eye_cameras[1].is_position_in_frustum(actor.position+Vector3.UP*.85):visible+=1
		visible_counts.append(visible);tracked_counts.append(active);arm_times.append(arm_ms)
	return result
func finish() -> void:
	var shots:=0;var deaths:=0;var by_actor:Dictionary={}
	for id in actor_ids:shots+=game.players[id].shots;deaths+=game.players[id].deaths;by_actor[str(id)]=game.players[id].shots
	var valid:bool=shots>0 and deaths==0 and game.bots.ai_work_calls==0 and game.bots.tick_ms.is_empty() and game.bots.region.navigation_mesh.get_polygon_count()==0 and not visible_counts.is_empty() and visible_counts.min()==avatar_count and (not tracked_arms or tracked_counts.min()==avatar_count)
	var report:={"valid":valid,"avatars":avatar_count,"controller_arms":tracked_arms,"tracked_arm_count":Probe.summary(tracked_counts),"valid_head_controller_poses":poses_valid,"ai_work_calls":game.bots.ai_work_calls,"navigation_polygons":0,"shots":shots,"shots_by_actor":by_actor,"deaths":deaths,"reloads":game.variant_combat.reloads,"wall_seconds":(Time.get_ticks_usec()-began_usec)/1e6,"simulation_seconds":elapsed,"both_eye_visible":Probe.summary(visible_counts),"physics_ms":Probe.summary(ticks),"controller_pose_generation_ms":Probe.summary(input_times),"arm_pose_updates_ms_per_frame":Probe.summary(arm_times),"performance":probe.result(),"pool":game.variant_visuals.shape_pool_report(),"formation":formation,"assignments":assignment,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"per_eye_size":[2160,2376],"ipd_m":.064,"fov":90,"seed":1977,"map":"Jungle Frontier 8km2, canopy outpost future pad","limits":"Two desktop stereo passes; no native XR pacing/encoding. Actual CS fire, reloads, traces, collision and production pooled FX; stationary slots, no AI/navmesh. All seven UT99 World Leaders skins. Previous ranger/MDL receipts used a different terrain/map and source avatar set."}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await RenderingServer.frame_post_draw
	for i in 2:eye_viewports[i].get_texture().get_image().save_png(output+("/left.png" if i==0 else "/right.png"))
	root.get_texture().get_image().save_png(output+"/preview.png")
	print("UT99_SHOOTING_RESULT ",JSON.stringify(report))
	game.disconnect_game();quit(0 if valid else 1)
