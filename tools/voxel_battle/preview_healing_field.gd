extends SceneTree
const Test=preload("res://deathmatch/tests/cq_recon_drone.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/healing-field"
var game
var map
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
	if map and game and game.camera:map.update_view(game.camera)
	return false
func capture(label:String) -> void:
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png");print("HEALING_CAPTURE ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Healing field preview",0,100,10,false);game.hud.visible=false;game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,false);game.battle_map=map;map.lighting.phase_override=1
	game.classes.choose(1,"medic");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"medic","healing_grenade");game._spawn(1);game.players[1].input_blocked=false
	var site:Vector3=Map.Landscape.CENTERS[4]+Vector3(12,0,32);site.y=Map.Landscape.surface(site.x,site.z).x+.065
	game.fighters[1].position=site+Vector3(0,0,20);game.healing_field.activate(1,site,0);game.healing_field.draw()
	assert(game.healing_field.visual.multimesh.instance_count==1)
	game.camera.position=site+Vector3(9,2,12);game.camera.look_at(site+Vector3.UP*1.7);game.camera.fov=65
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()>deadline:quit(1);return
	await capture("active-field")
	game.healing_field.fields.values()[0].health=0;game.healing_field.draw();await capture("healing-depleted-shield-active")
	var grenade:Node3D=preload("res://deathmatch/conquest/classes/grenade_visuals.gd").model(3);game.get_node("Map").add_child(grenade);grenade.position=site+Vector3.UP*1.6
	game.camera.position=grenade.position+Vector3(.18,.09,.30);game.camera.look_at(grenade.position);game.camera.fov=45;await capture("medical-grenade")
	game.hud.visible=true;game.menu_open=true;game.hud.show_menu(true);game.loadout_menu.choose_class("medic");await capture("medic-t2-loadout")
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"radius":5,"shield":500,"health":500,"seconds":10,"grenade_triangles":1000,"field_draws":1},"\t"))
	map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit()
