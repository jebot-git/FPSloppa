extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var walkers
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func step(seconds: float) -> void:
	for i in roundi(seconds*60):game.clock+=1./60.;walkers.tick(1./60.)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.selected_map="qsrc_dm1";game.mode_maplists.tb=["qsrc_dm1"];game.start_host("TB balance",0,100,10,true,"tb")
	game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
	walkers=game.match_mode.fortress.walkers;walkers.configure([{"id":"test","team":0,"points":[Fixture.point(),Fixture.point(0,100)]}])
	for id in game.players:
		game.players[id].dead=false;game.players[id].spectator=false;game.players[id].invulnerable=0;game.players[id].tf_class="soldier";game.players[id].team=0 if id==1 else 1
		game.fighters[id].position=Fixture.point(15,15)
	var pilot: Dictionary=game.players[1];var row: Dictionary=walkers.robots.test
	game.fighters[1].position=Fixture.point();await physics_frame;await physics_frame
	check(walkers.try_board(1,"test") and row.exit_lock==10.,"Boarding starts ten-second exit lock")
	check(walkers.snapshot()[0].exit_lock==10.,"Exit lock replicates")
	step(9.983333);check(not walkers.leave(1),"Voluntary exit rejected just before ten seconds")
	step(1./60.);check(row.exit_lock==0.,"Exit unlocks at ten seconds")
	for amount in [8,12,40,100,120,121]:
		pilot.hp=200
		game._damage(1,-1,amount,"ROCKET LAUNCHER",false,Vector3.INF,Vector3.ZERO,false,true)
		check(pilot.hp==200-(amount-amount/2) and pilot.armor==200,"Hull armour absorbs half of "+str(amount)+" damage and remains permanent")
	pilot.hp=200;game._damage(1,-1,100,"ROCKET LAUNCHER",false)
	check(pilot.hp==200,"Unverified cockpit hits cannot bypass hull contact")
	game._damage(1,-1,100,"SHOTGUN",false,Vector3.INF,Vector3.ZERO,false,true)
	check(pilot.hp==200,"Light weapons remain blocked by hull policy")
	game.match_mode.titanball.preparation_left=0
	step(2.5);check(row.speed>0 and row.speed<walkers.SPEED,"Titan is still accelerating after the old two-second window")
	step(2.5);check(is_equal_approx(row.speed,walkers.SPEED),"Titan reaches full speed after five seconds")
	check(walkers.leave(1),"Unlocked pilot can leave")
	step(4.983333);check(row.speed>0 and not walkers.ladder_visible(row),"Five-second braking phase blocks replacement boarding")
	step(1./60.);check(row.speed==0 and not walkers.ladder_visible(row),"Full stop begins separate ladder redeployment delay")
	step(2.983333);check(not walkers.ladder_visible(row),"Ladder stays unavailable before three stationary seconds")
	step(2./60.);check(walkers.ladder_visible(row),"Ladder deploys after three stationary seconds")
	game.fighters[1].position=walkers.transform(row)*walkers.LADDER
	check(walkers.try_board(1,"test"),"Replacement can board after braking and deployment")
	game._damage(1,1,10000,"TEST",true)
	check(pilot.dead and not walkers.mounted(1),"Death ejects immediately during the ten-second lock")
	check(not walkers.ladder_visible(row) and walkers.snapshot()[0].boarding_wait>0,"Death also starts the replicated boarding delay")
	game.free();print("TB_BALANCE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
