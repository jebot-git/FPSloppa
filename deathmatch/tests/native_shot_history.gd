extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Arena extends "res://deathmatch/arena.gd":
	var history_reads:=0
	func _history_positions() -> Dictionary:
		history_reads+=1;return super._history_positions()
	func _shot_rewind(_id: int) -> float:return .1
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate()
	game.match_mode.fortress.free();game.set_script(Arena);root.add_child(game);Fixture.setup(game)
	game.start_host("Shot history",0,100,60,true);game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
	for id in game.players:
		game.players[id].invulnerable=0;game.players[id].hp=10000;game.fighters[id].position=Fixture.point(0,-5 if id==-1 else 10)
	game.fighters[1].position=Fixture.point();await physics_frame
	for sample in 20:game.clock+=1./60;game._record_history()
	for rules in ["cs16","doom"]:
		game.armory.select(rules);game.variant_combat.reset()
		for weapon in [3,4]:
			var s: Dictionary=game.players[1]
			s.weapon=weapon;s.owned=range(12);s.ammo=[300,300,300,300];s.cooldown=0;s.held=false;s.dead=false;s.spectator=false;s.last_input=game.clock;s.yaw=0;s.pitch=0
			var before: int=s.shots
			game.history_reads=0
			if rules=="cs16":check(game.variant_combat.cs.shoot(1),"CS shotgun shot accepted")
			else:game._fire(1)
			check(s.shots==before+1,"One authoritative shot "+rules+str(weapon))
			check(game.history_reads==1,"All pellets share one history extraction "+rules+str(weapon))
	game.disconnect_game();game.free();await process_frame
	print("NATIVE_SHOT_HISTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
