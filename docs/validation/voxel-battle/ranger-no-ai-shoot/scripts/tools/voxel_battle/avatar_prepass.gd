extends RefCounted
## Scenario-local preparation pass. Original VRM files and normal game caches stay
## intact; every player sharing a hash reuses the prepared surface/index buffers.
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const IndexCache=preload("res://tools/meshoptimizer/index_cache.gd")
const Secondary=preload("res://addons/vrm/vrm_secondary.gd")
var report:={"enabled":true,"surface_compile":true,"index_cache":true,"springs_enabled":false,"prepared_models":[],"avatars":0,"inactive_spring_systems":0,"preparation_ms":0.0}
func prepare(game) -> bool:
	Secondary.springs_enabled=false;Loader.compile_surfaces=true
	if game.headless:report.rendering_skipped=true;return true
	var before:=Time.get_ticks_usec()
	game.avatars.set_process(false);game.avatars.load_queue.clear()
	var library=game.avatars.library
	var hashes: Dictionary={}
	for choice in game.avatars.choices.values():hashes[choice.hash]=true
	for hash in hashes:
		if not Loader.prepare_avatar(library,hash,true):push_error(library.last_error);return false
		var model=library.scenes[hash].instantiate()
		var row:=IndexCache.model(model);row.hash=hash
		row.surface_compile=model.get_meta("arena_surface_compile",{})
		var packed:=PackedScene.new();var error:=packed.pack(model);model.free()
		if error!=OK:push_error("VRM preparation pack failed");return false
		library.remember_scene(hash,packed);report.prepared_models.append(row)
	for id in game.players:
		var hash: String=game.avatars.choices[id].hash
		var rig=library.create_avatar(hash)
		if rig==null:push_error(library.last_error);return false
		rig.secondary_motion_enabled=false;rig.animation_optimized=true
		game.fighters[id].set_avatar(rig,hash);rig.enable_distance_lod()
		for secondary in rig.secondary_nodes:
			secondary.animation_suspended=true;secondary.update_native_state()
			if is_instance_valid(secondary.native_simulator) and secondary.native_simulator.active:push_error("Spring simulation must be disabled");return false
			report.inactive_spring_systems+=1
		report.avatars+=1
	report.preparation_ms=(Time.get_ticks_usec()-before)/1000.0
	return true
