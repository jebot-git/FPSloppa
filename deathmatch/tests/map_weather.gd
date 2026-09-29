extends SceneTree
const Weather=preload("res://deathmatch/maps/weather.gd")
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var world:=Node3D.new();root.add_child(world)
	var roof:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,1,100);collision.shape=box;roof.add_child(collision);world.add_child(roof);roof.position.y=8
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,3,10);camera.make_current()
	await physics_frame;await physics_frame
	for map in ["ctf_katabatic","ctf_raindance"]:
		var weather:=Weather.new();world.add_child(weather);weather.configure(map);weather.set_physics_process(false)
		weather.update_roofs(camera.position)
		check(weather.field.multimesh.instance_count==512 and weather.field.multimesh.mesh.get_surface_count()==1,"One bounded instanced precipitation draw: "+map)
		check(weather.roof_cache.size()==64 and weather.roof_cache.values().all(func(h):return absf(h-8.65)<.01),"Rain/snow clip at overhead roof, not interior floor: "+map)
		var before:=weather.sample_count;weather.update_roofs(camera.position)
		check(weather.sample_count==before,"Stationary view reuses roof survey: "+map)
		weather.update_roofs(camera.position+Vector3(4,0,0))
		check(weather.sample_count-before==8 and weather.roof_cache.size()==64,"Moving one cell samples only new edge: "+map)
		weather.update_roofs(Vector3(10000,3,10000))
		check(weather.roof_cache.size()==64 and weather.roof_cache.values().all(func(h):return h < -100),"Teleport replaces old roof mask: "+map)
		var env:=Environment.new();Atmosphere.distance_fog(env,map)
		check(env.fog_enabled and env.fog_mode==Environment.FOG_MODE_DEPTH and not env.volumetric_fog_enabled and env.fog_density<.281 and env.fog_depth_begin>=300,"Distant-only bounded depth haze: "+map)
		weather.update_roofs(camera.position);weather.material.set_shader_parameter("focus",camera.position)
		for i in 3:await process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		weather.free()
	var env:=Environment.new();Atmosphere.distance_fog(env,"ctf_stonehenge")
	check(env.fog_enabled and env.fog_depth_begin==240 and env.fog_depth_end==950 and not env.volumetric_fog_enabled,"Stonehenge uses shorter-range distance haze")
	var untouched:=Environment.new();Atmosphere.distance_fog(untouched,"external-map")
	check(not untouched.fog_enabled,"Other maps retain their existing atmosphere")
	var game:=Node.new();root.add_child(game);var world_env:=WorldEnvironment.new();world_env.name="Environment";world_env.environment=Environment.new();game.add_child(world_env)
	for map in ["ctf_stonehenge","ctf_raindance","ctf_katabatic","tf_pressureworks","external-map"]:
		Atmosphere.apply(game,map)
		check(world_env.environment.fog_enabled==Atmosphere.DISTANCE_FOG.has(map),"Map rotation applies and resets depth haze: "+map)
	game.free()
	print("MAP_WEATHER ",JSON.stringify({"checks":checks,"failures":failures}));world.free();quit(0 if failures.is_empty() else 1)
