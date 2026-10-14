extends SceneTree
const Test=preload("res://deathmatch/tests/cq_recon_drone.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/airstrike"
var game
var map
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if map and game and game.camera:map.update_view(game.camera)
	return false
func capture(label:String) -> void:
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png");print("AIRSTRIKE_CAPTURE ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Airstrike preview",0,100,10,false);game.hud.visible=false;game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,false);game.battle_map=map;map.lighting.phase_override=1
	game.classes.choose(1,"shocktroop");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"shocktroop","airstrike");game._spawn(1);game.players[1].input_blocked=false
	game.players[1].yaw=0;game.players[1].pitch=0;game.players[1].xr={};game.fighters[1].position=Map.Landscape.CENTERS[4]
	game.players[1].weapon=8;game.players[1].fire=true;game.players[1].last_input=game.clock;game.fighters[1].velocity=Vector3.ZERO
	var site:Vector3=Map.Landscape.CENTERS[4]+Vector3(0,0,-100)
	assert(game.airstrike.launch(1,site,Vector3.FORWARD));var flight:Dictionary=game.airstrike.flights.values()[0]
	game.clock=flight.impact_at-1;game.airstrike.draw()
	var plane:Vector3=game.airstrike.position(flight,game.clock)
	game.camera.position=Map.Landscape.CENTERS[4]+Vector3(0,1.7,48);game.camera.look_at(plane);game.camera.fov=65
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()>deadline:quit(1);return
	await capture("ground-observer")
	game.camera.position=plane+Vector3(13,-6,19);game.camera.look_at(plane);game.camera.fov=45
	await capture("bomber-flyby")
	game._cq_airstrike_fx(site)
	await capture("payload-and-explosion")
	game.hud.visible=true;game.menu_open=true;game.hud.show_menu(true);game.loadout_menu.choose_class("shocktroop")
	await capture("shocktroop-t2-loadout")
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"flight":flight,"model":"Karmabub CC0 X-001 optimized bomber","triangles":1438,"payloads_visible":game.airstrike.payloads.size(),"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit()
