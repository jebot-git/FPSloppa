extends SceneTree
const Test=preload("res://deathmatch/tests/cq_healing_field.gd")
var failures:Array=[]
var game
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test:Callable,seconds:float=15) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game)
	if role=="server":
		game.start_host("Healing server",28797,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Ally joins authority")
		game.set_process(false);game.set_physics_process(false)
		if game.players.size()==2:
			var ally:int=game.players.keys().filter(func(id):return id!=1)[0]
			game.classes.choose(1,"medic");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"medic","healing_grenade");game._spawn(1);game.players[1].team=0;game.players[ally].team=0;game.players[ally].hp=50;game.fighters[1].position=Vector3.ZERO;game.fighters[ally].position=Vector3(2,0,0);game.players[1].input_blocked=false;game.players[1].last_input=game.clock
			game._send_snapshot();await create_timer(.5).timeout
			check(game.grenades.equip_hand(1,3) and game.grenades.throw_grenade(1,Vector3.ZERO),"Authority throws healing grenade with existing ballistic simulation")
			for i in 100:
				game.clock+=.05;game.grenades.tick(.05);game.healing_field.tick(.05)
				if i==70 and not game.healing_field.fields.is_empty():
					var at:Vector3=game.healing_field.fields.values()[0].position;game.healing_field.intercept(1,at-Vector3.RIGHT*10,at+Vector3.RIGHT*10,55,true)
				game._send_snapshot();await create_timer(.05).timeout
			check(game.players[ally].hp>=75 and game.healing_field.fields.values()[0].health<500 and game.healing_field.fields.values()[0].energy==445,"Authority independently regenerates ally and absorbs beam")
			game.healing_field.reset();game._send_snapshot();await create_timer(.5).timeout
	else:
		game.clock=500;game.start_join("Healing ally","127.0.0.1",28797)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with a different clock")
		check(await wait_for(func():return game.grenades.state(1).counts[3]==3),"Three-grenade T2 inventory replicates")
		check(await wait_for(func():return game.grenades.flying.values().any(func(p):return p.kind==3)),"Thrown healing grenade trajectory replicates")
		check(await wait_for(func():return not game.healing_field.fields.is_empty()),"Activated five-metre field replicates")
		if not game.healing_field.fields.is_empty():
			var field:Dictionary=game.healing_field.fields.values()[0];var remaining:float=field.until-game.clock
			check(remaining>9 and remaining<=10,"Field ten-second lifetime preserves relative deadline across client clocks")
		check(await wait_for(func():return game.local_state().get("hp",0)>=75 and game.healing_field.fields.values().any(func(row):return row.energy==445 and row.health<500)),"Client sees authoritative healing and independent shield depletion")
		check(game.grenades.state(1).counts[3]==2 and 6 not in game.players[1].owned and game.classes.states[1].equipped_utility=="healing_grenade","Client sees replaced box loadout and consumed grenade")
		check(await wait_for(func():return game.healing_field.fields.is_empty()),"Field removal replicates")
	print("CQ_HEALING_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
