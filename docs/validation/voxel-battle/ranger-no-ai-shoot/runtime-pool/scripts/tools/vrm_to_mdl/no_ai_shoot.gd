extends "res://tools/vrm_to_mdl/ranger_match.gd"
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var actor_ids: Array=[]
var rng:=RandomNumberGenerator.new()
var direction_at: Dictionary={}
var input_times: Array=[]
var animation_counts: Dictionary={"idle":0,"walk":0,"run":0}
var visible_counts: Array=[]
var formation: Array=[]
var last_shots: Dictionary={}
var shot_windows: Dictionary={}
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/vrm_to_mdl/no_ai_arena.gd"));return scene
func prepare_avatars() -> bool:
	if not super.prepare_avatars():return false
	actor_ids=game.players.keys();actor_ids.sort();rng.seed=1977
	var point:=Vector3(37.4246215820312,20,2.02122497558594)
	for i in actor_ids.size():
		var id: int=actor_ids[i];var actor=game.fighters[id]
		var x: float=point.x+(i%8-3.5)*2.0;var z: float=point.z-int(i/8)*2.5
		actor.position=Vector3(x,Landscape.surface(x,z).x+.05,z)
		actor.reset_physics_interpolation();formation.append([x,actor.position.y,z])
		game.players[id].hp=1000000;game.players[id].cs_reserve=[999999,999999,999999,0]
		direction_at[id]=-1.0
	camera.position=Vector3(point.x,Landscape.surface(point.x,point.z+10).x+1.7,point.z+10);camera.rotation=Vector3.ZERO
	for i in eye_cameras.size():
		eye_cameras[i].global_transform=camera.global_transform;eye_cameras[i].position+=camera.basis.x*((i-.5)*.064)
	view_label="32 animated ranger VRMs, scripted random fire, no AI"
	return true
func _physics_process(delta: float) -> bool:
	if started and not finished:
		var before:=Time.get_ticks_usec()
		for id in actor_ids:
			var state: Dictionary=game.players[id]
			if game.clock>=direction_at[id]:
				state.yaw=rng.randf_range(-PI,PI);state.pitch=rng.randf_range(-.35,.35);direction_at[id]=game.clock+rng.randf_range(.8,2.0)
			state.move=Vector2.ZERO;state.fire=true;state.alt_fire=false;state.offhand_fire=false;state.jump=false;state.input_blocked=false;state.last_input=game.clock
			state.hp=1000000 # Keep all 32 rigs active despite incidental hits.
		input_times.append((Time.get_ticks_usec()-before)/1000.0)
	var result:=super._physics_process(delta)
	if started and not finished:
		var window:=str(int(elapsed/30.0))
		for id in actor_ids:
			var count: int=game.players[id].shots
			shot_windows[window]=shot_windows.get(window,0)+count-last_shots.get(id,0)
			last_shots[id]=count
	return result
func _process(delta: float) -> bool:
	var result:=super._process(delta)
	if started and not finished:
		var visible:=0
		for i in actor_ids.size():
			var id: int=actor_ids[i];var actor=game.fighters[id]
			var cycle: int=(int(elapsed/4.0)+i)%3
			var speed: float=[0.0,2.0,6.0][cycle]
			actor.rotation.y=game.players[id].yaw;actor.visual_pitch=game.players[id].pitch;actor.visual_velocity=actor.basis*Vector3(0,0,-speed);actor.visual_grounded=true
			animation_counts[["idle","walk","run"][cycle]]+=1
			if eye_cameras[0].is_position_in_frustum(actor.position+Vector3.UP*.85) and eye_cameras[1].is_position_in_frustum(actor.position+Vector3.UP*.85):visible+=1
		visible_counts.append(visible)
	return result
func finish() -> void:
	var shots:=0;var deaths:=0
	var by_actor: Dictionary={}
	for id in actor_ids:
		shots+=game.players[id].shots;deaths+=game.players[id].deaths;by_actor[str(id)]=game.players[id].shots
	var report:={"avatars":actor_ids.size(),"ai_work_calls":game.bots.ai_work_calls,"ai_tick_samples":game.bots.tick_ms.size(),"navigation_polygons":game.bots.region.navigation_mesh.get_polygon_count(),"shots":shots,"shots_by_actor":by_actor,"shots_per_30_sim_seconds":shot_windows,"deaths":deaths,"reloads":game.variant_combat.reloads,"animation_frame_observations":animation_counts,"both_eye_visible_avatars":Probe.summary(visible_counts),"scripted_input_ms_per_tick":Probe.summary(input_times),"formation":formation,"directions":"Seed 1977, uniform yaw +/-pi and pitch +/-0.35 rad, changed every 0.8–2.0 s per actor","animation":"Staggered idle/walk/run every 4 s, in-place visual locomotion; normal VRM rig and CS recoil","limits":"Close 8x4 crowd, not the distant match overview. Positions remain stationary; actual firing, traces, impacts, reloads and collisions run. HP replenished to preserve all 32 avatars. No AI or navmesh bake. Test does not isolate every remaining CPU cost."}
	for count in by_actor.values():assert(count>30, "Every avatar must shoot beyond its first rifle magazine")
	assert(shots>0 and deaths==0 and report.navigation_polygons==0 and report.ai_work_calls==0 and report.ai_tick_samples==0 and report.both_eye_visible_avatars.p50==32)
	FileAccess.open(output+"/no-ai.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NO_AI_SHOOTING_RESULT ",JSON.stringify(report))
	await super.finish()
