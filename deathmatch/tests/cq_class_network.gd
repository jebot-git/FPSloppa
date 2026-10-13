extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Base:
	func _load_map(_id:String)->bool:
		spawn_points=[Vector3(0,1,0),Vector3(8,1,0)];spawn_yaws=[0,PI];current_map="voxel_jungle";map_sha=map_identity()
		var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,1,40);shape.shape=box;ground.add_child(shape);$Map.add_child(ground);return true
var failures:Array=[]
var game
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test:Callable,seconds:float=15)->bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	return false
func run()->void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game)
	if role=="server":
		game.dedicated=true;game.match_mode.configure({});game.start_host("CQ network",28779,100,10,false)
		check(await wait_for(func():return game.players.size()==1 and game.classes.states.values().any(func(s):return s.next=="scout")),"Authenticated client chooses scout")
		if game.players.size()==1:
			var id:int=game.players.keys()[0];game._spawn(id);game.players[id].fire=false;game.players[id].alt_fire=false
			check(game.classes.cloak(id),"Authority activates cloak")
			game._send_snapshot()
			await create_timer(5).timeout
			game.classes.weapon_used(id)
			await create_timer(3).timeout
	else:
		game.clock=500 # Deliberately different clocks exercise relative deadline replication.
		game.start_join("Scout network","127.0.0.1",28779)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins packaged procedural CQ map")
		if game.active:
			game.request_class("scout")
			await create_timer(1).timeout
			var id:int=game.multiplayer.get_unique_id()
			check(await wait_for(func():return game.classes.role(id)=="scout" and game.classes.cloaked(id)),"Class and cloak replicate despite clock offset")
			check(game.classes.states.get(id,{}).get("cloak_ready",0.0)-game.clock>20,"Client receives relative cloak cooldown")
			check(game.local_state().ammo[0]==42,"Class pouch ammunition replicates")
			check(await wait_for(func():return game.classes.role(id)=="scout" and not game.classes.cloaked(id)),"Weapon reveal replicates")
	print("CQ_CLASS_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
