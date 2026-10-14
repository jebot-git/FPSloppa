extends SceneTree
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/battery-tank"
var game
var map
var mounted:=false
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if map and game and game.camera:
		if mounted:game.battery_tanks.draw();map.update_view(game.world_view_camera())
		else:map.update_view(game.camera)
	return false
func capture(name:String) -> void:
	await create_timer(.8).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png");print("BATTERY_CAPTURE ",name)
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()>deadline:quit(1);return
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Battery preview",28804,100,10,false);game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED;game.hud.visible=false;game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,true);game.battle_map=map;map.lighting.phase_override=1;game.battery_tanks.configure();game.battery_tanks.draw()
	for key in game.battery_tanks.rows:
		var row:Dictionary=game.battery_tanks.rows[key];game.camera.position=row.position+(Vector3(-7,3,9) if key==0 else Vector3(7,3,-9));game.camera.look_at(row.position+Vector3.UP*1.5);game.camera.fov=60;await settle();await capture("relay-battery" if key==0 else "crossing-battery")
	var tanks=game.battery_tanks;var row:Dictionary=tanks.rows[0];game.classes.choose(1,"technician");game._spawn(1);game.players[1].team=0;game.players[1].input_blocked=false;game.fighters[1].position=row.position+Vector3(3.5,0,0);await physics_frame
	var boarded:bool=tanks.use(1);row.direction=Vector3(0,.12,1).normalized();game._add_player(2,"Scout");game.classes.states[2]["class"]="scout";game.designations[2]={"team":0,"position":row.position+Vector3(0,0,100),"until":game.clock+30};game.clock+=1;mounted=true;tanks.draw();await settle();await capture("technician-scope-feed")
	var replaced:bool=tanks.view.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and game.camera.cull_mask==tanks.PRIVATE_LAYER and game.world_view_camera()==tanks.view.sensor and (not is_instance_valid(game.viewmodel) or not game.viewmodel.visible)
	tanks.rows[0].left=0;tanks.rows[0].reload_at=game.clock+30;await capture("scope-reloading")
	var dismounted:bool=tanks.leave(1);mounted=false;tanks.view.update();game.camera.position=row.position+Vector3(-7,3,-9);game.camera.look_at(row.position+Vector3.UP*1.5);await capture("dismounted")
	var restored:bool=game.camera.cull_mask!=tanks.PRIVATE_LAYER and tanks.view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"model_triangles":953,"textures":[512,256,128],"boarded":boarded,"scope_replaces_view":replaced,"dismounted":dismounted,"camera_restored":restored},"\t"))
	print("BATTERY_PREVIEW_RESULT ",boarded and replaced and dismounted and restored);map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit(0 if boarded and replaced and dismounted and restored else 1)
