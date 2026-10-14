extends SceneTree
const Test=preload("res://deathmatch/tests/cq_recon_drone.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/turret"
var game
var map
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if map and game and game.camera:map.update_view(game.camera)
	return false
func capture(label:String) -> void:
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png");print("TURRET_CAPTURE ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Turret preview",28801,100,10,false);game.hud.visible=false;game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,false);game.battle_map=map;map.lighting.phase_override=1
	game.classes.choose(1,"technician");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"technician","turret");game._spawn(1);game.players[1].input_blocked=false
	var site:Vector3=Map.Landscape.CENTERS[4]+Vector3(24,0,40);site.y=Map.Landscape.surface(site.x,site.z).x+.03
	game.turrets.rows[1]={"owner":1,"team":0,"position":site,"direction":Vector3.FORWARD,"hp":200,"ammo":12,"fire_at":0.0,"shot_at":-100.0,"target":""};game.turrets.body(1).position=site;game.turrets.draw()
	game.camera.position=site+Vector3(3,1.7,4);game.camera.look_at(site+Vector3.UP*.7);game.camera.fov=50
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()>deadline:quit(1);return
	await capture("optimized-turret")
	game.turrets.rows[1].direction=Vector3(1,.3,0).normalized();game.turrets.draw();game._cq_turret_shot(game.turrets.muzzle(game.turrets.rows[1]),game.turrets.rows[1].direction,0);await capture("autonomous-aim")
	game.hud.visible=true;game.menu_open=true;game.hud.show_menu(true);game.loadout_menu.choose_class("technician");await capture("technician-t2-loadout")
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"triangles":1440,"atlas":512,"hp":200,"ammo":12,"range":100,"cooldown":120,"fire_interval":1.5},"\t"))
	map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit()
