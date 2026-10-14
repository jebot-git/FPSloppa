extends SceneTree
const Test=preload("res://deathmatch/tests/cq_recon_drone.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/recon-drone"
var game
var map
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if map and game and game.camera:map.update_view(game.camera)
	return false
func capture(label:String) -> void:
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png");print("RECON_CAPTURE ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Recon preview",0,100,10,false);game.hud.visible=false;game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,false);game.battle_map=map;map.lighting.phase_override=1
	game.classes.choose(1,"scout");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"scout","recon_drone");game._spawn(1);game.players[1].input_blocked=false
	game.players[1].yaw=0;game.players[1].pitch=0;game.players[1].xr={};game.fighters[1].position=Map.Landscape.CENTERS[4]
	assert(game.recon_drone.activate(1));var flight:Dictionary=game.recon_drone.flights.values()[0]
	game.clock=flight.at+flight.length/(2*game.recon_drone.SPEED);game.recon_drone.draw()
	var plane:Vector3=game.recon_drone.position(flight,game.clock)
	game.camera.position=Map.Landscape.CENTERS[4]+Vector3(0,1.7,48);game.camera.look_at(plane);game.camera.fov=65
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()>deadline:quit(1);return
	await capture("ground-observer")
	game.camera.position=plane+Vector3(13,-6,19);game.camera.look_at(plane);game.camera.fov=45
	await capture("fighter-flyby")
	game.recon_drone.alerts[1]={"seq":1,"life":game.players[1].serial,"until":game.clock+10};game.recon_drone.notify_local()
	assert(game.recon_drone.warning.playing and game.recon_drone.warning_count==1)
	game.recon_drone.notify_local();assert(game.recon_drone.warning_count==1)
	game.hud.visible=true;game.menu_open=true;game.hud.show_menu(true);game.loadout_menu.choose_class("scout")
	await capture("scout-t2-loadout")
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"flight":flight,"model":"surt CC0 low-spec fighter","warning_played":true,"warning_count":game.recon_drone.warning_count,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit()
