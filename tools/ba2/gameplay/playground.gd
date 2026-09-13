extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var game
func _initialize():call_deferred("run")
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.mode_maplists["tb"]=["tb_ashfall"];game.selected_map="tb_ashfall"
	game.start_host("BA-2 Pilot",0,100,60,true,"tb")
	if not game.active:push_error("Could not start BA-2 playground");quit(1);return
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	for id in game.players.keys():if id<0:game._peer_left(id)
	await physics_frame
	game.fighters[1].position=Vector3(0,.05,2.0);game.fighters[1].reset_view();game.local_yaw=0.;game.players[1].yaw=0.;game.players[1].invulnerable=0.
	game.status("TB — RED ATTACKS: jump at the belly ladder to pilot to BLUE BASE. Wait for preparation gate opening; checkpoints advance respawns. Jump again or Use/E to exit.")
	print("BA2_PLAYGROUND_READY")
