extends SceneTree
var game
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="qsrc_dm6";game.start_host("Balance regressions",0,100000,60,true,"if","doom")
	game.set_process(false);game.set_physics_process(false);game.dedicated=true
	game.players[1].spectator=true;game._spawn(1)
	for id in [-4,-5,-6,-7,-8]:game._add_player(id,"Bot")
	while not game.bots.navigation.ready():await physics_frame
	for cycle in 6:
		game.match_mode.special.reset()
		for id in game.players:game._spawn(id)
		for frame in 120:await physics_frame;game._physics_process(1.0/60)
	var bounded:=true
	for id in game.players:
		if id<0 and game.fighters[id].position.y>25:bounded=false
	check(bounded,"Repeated simultaneous eight-player spawns never create rising capsule stacks")
	game.match_mode.kind="ctf";game.armory.select("ut99")
	var s:Dictionary=game.players[-1];s.owned=[0,2,11];s.ammo=[50,0,0,0]
	check(game.bots.needs_equipment(-1),"Starting translocator is not combat equipment")
	check(game.bots.combat_upgrade(-1,1) and not game.bots.combat_upgrade(-1,11),"Bio Rifle is a ranged upgrade; translocator is utility")
	check(game.bots.item_value(-1,{"kind":"weapon","item":1})==55,"Unowned Bio Rifle receives ranged-weapon pickup value")
	s.owned.append(6);s.ammo[2]=0
	check(game.bots.needs_equipment(-1),"An empty rocket launcher does not suppress resupply")
	s.ammo[2]=5;check(not game.bots.needs_equipment(-1),"An armed bot stops prioritizing equipment preparation")
	game.armory.select("doom");s.owned=[0,1,2];s.ammo=[50,0,0,0]
	check(not game.bots.combat_upgrade(-1,1) and game.bots.needs_equipment(-1),"Doom chainsaw does not count as ranged preparation")
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("BOT_BALANCE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
