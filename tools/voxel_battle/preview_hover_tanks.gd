extends "res://tools/voxel_battle/preview_battery_tank.gd"
var revival_timers=preload("res://deathmatch/conquest/classes/revival_timers.gd").new() # Legacy timer asset preview only.
const HOVER_OUTPUT:="res://test-results/hover-tanks"
func _process(delta:float) -> bool:
	super._process(delta)
	if game:revival_timers.draw(game)
	return false
func shot(name:String) -> void:
	await create_timer(.8).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(HOVER_OUTPUT+"/"+name+".png");print("HOVER_CAPTURE ",name)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(HOVER_OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Hover preview",28808,100,10,false);game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED;game.hud.hide();game.camera.set_process(false)
	map=Map.new();game.get_node("Map").add_child(map);map.build(true,true);game.battle_map=map;map.lighting.phase_override=1;game.battery_tanks.configure();game.battery_tanks.draw()
	var tanks=game.battery_tanks;var ok:=true
	for key in [2,6,7,4,5]:
		var row:Dictionary=tanks.rows[key];game.camera.position=row.position+(Vector3(7,2.6,8) if key==6 else Vector3(-6,2.6,-7));game.camera.look_at(row.position+Vector3.UP*.7);game.camera.fov=60;await settle();await shot("spawn-%d-%s"%[key,row.kind])
	for key in [2,6]:
		var row:Dictionary=tanks.rows[key];game.classes.choose(1,"technician");game._spawn(1);game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].use_at=0;game.fighters[1].position=row.position+Vector3(3.5,0,0);await physics_frame
		ok=tanks.use(1) and ok;game.players[1].pitch=1.2;game.players[1].yaw=0;row.direction=tanks.direction(1);mounted=true;tanks.draw();await settle();await shot(row.kind+"-scope-elevation-limit")
		ok=tanks.view.sensor==game.world_view_camera() and game.camera.cull_mask==tanks.PRIVATE_LAYER and ok
		row.rounds=0;row.reload_at=game.clock+tanks.profile(row).reload;await shot(row.kind+"-reload")
		ok=tanks.leave(1) and ok;mounted=false;tanks.view.update()
	game.classes.choose(1,"medic");game._spawn(1);game.players[1].team=0;game.players[1].input_blocked=false;game._add_player(2,"Revive me");game.players[2].team=0;game.players[2].invulnerable=0
	var point:Vector3=tanks.rows[4].position+Vector3(4,0,0);game.fighters[1].position=point+Vector3(0,0,-3);game.fighters[2].position=point;game.classes.incapacitate(2,1,"TEST",false,false,false);game.fighters[2].update_height(.65)
	game.camera.position=point+Vector3(0,1.6,-3);game.camera.look_at(point+Vector3.UP*.5);game.camera.fov=65;await settle()
	for fraction in [1.0,.5,.15]:
		game.classes.downed[2].remaining=10*fraction;revival_timers.draw(game);await shot("medic-revival-"+str(int(fraction*100)))
	ok=revival_timers.nodes.has(2) and revival_timers.nodes[2].visible and ok
	game.classes.downed.erase(2);revival_timers.draw(game);await process_frame;ok=not revival_timers.nodes.has(2) and ok
	FileAccess.open(HOVER_OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"light_triangles":702,"heavy_triangles":2229,"light_count":4,"heavy_count":2,"scope_and_medic_timer":ok},"\t"))
	print("HOVER_PREVIEW_RESULT ",ok);map.terrain.shutdown();game.battle_map=null;game.disconnect_game();game.free();quit(0 if ok else 1)
