extends "res://tools/ut99_avatar/shooting.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
var map_times:Array=[]
var tree_refresh:Array=[]
var grass_refresh:Array=[]
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/ut99_avatar/profile/arena.gd"));return scene
func prepare_avatars() -> bool:
	game.avatars.library.visual_loader=preload("res://tools/ut99_avatar/profile/loader.gd")
	var leaders:Array=[]
	for hash in game.avatars.library.entries:
		if str(game.avatars.library.entries[hash].title).begins_with("World Leaders"):leaders.append(hash)
	assert(leaders.size()==7)
	for id in game.players:
		var hash:String=leaders[posmod(id,leaders.size())]
		game.avatars.choices[id]={"hash":hash,"size":game.avatars.library.entries[hash].size}
	game.variant_combat=preload("res://tools/ut99_avatar/profile/combat.gd").new();game.variant_combat.setup(game)
	return super.prepare_avatars()
func run() -> void:
	await super.run()
	Meter.reset(output);RenderingServer.frame_post_draw.connect(capture_categories)
func _physics_process(delta:float) -> bool:
	var stamp:=Meter.begin("benchmark_tick");var result:=super._physics_process(delta);Meter.end("benchmark_tick",stamp);return result
func _process(delta:float) -> bool:
	if not Meter.enabled:return super._process(delta)
	var refreshes:int=game.battle_map.grass.refreshes
	var foliage=game.battle_map.environment
	var tree_will_refresh:bool=foliage.dirty or camera.global_position!=foliage.last_position or camera.global_rotation!=foliage.last_rotation
	var before:=Time.get_ticks_usec();game.battle_map.update_view(camera)
	map_times.append((Time.get_ticks_usec()-before)/1000.0)
	if game.battle_map.grass.refreshes>refreshes:grass_refresh.append(game.battle_map.grass.update_ms)
	if tree_will_refresh:tree_refresh.append(foliage.update_ms)
	return super._process(delta)
func capture_categories() -> void:
	if Meter.enabled and started and not finished:Meter.commit(elapsed)
func finish() -> void:
	var report:=Meter.result();Meter.enabled=false
	report.simulation_seconds=elapsed;report.wall_seconds=(Time.get_ticks_usec()-began_usec)/1e6
	report.map_update_ms=Probe.summary(map_times);report.grass_actual_refresh_ms=Probe.summary(grass_refresh);report.tree_actual_refresh_ms=Probe.summary(tree_refresh)
	report.roster="Same seven World Leaders skins as historical 64 test, rebuilt with accepted constrained IK."
	report.terrain={"settled":game.battle_map.terrain.settled(),"resident":game.battle_map.terrain.resident.size(),"capacity":game.battle_map.terrain.CAPACITY,"grass_instances":game.battle_map.grass.visible_tufts,"grass_draws":game.battle_map.grass.draw_calls,"grass_distance_m":game.battle_map.grass.view_distance}
	FileAccess.open(output+"/categories.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await super.finish()
