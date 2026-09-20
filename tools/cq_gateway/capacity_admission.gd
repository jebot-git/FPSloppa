extends SceneTree
const State=preload("res://deathmatch/server/districts/state.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Capacity=preload("res://deathmatch/conquest/capacity.gd")
class Gateway extends "res://deathmatch/server/districts/gateway.gd":
	var sent: Array=[]
	func send(zone: int,message: Dictionary):sent.append({"zone":zone,"message":message.duplicate(true)})
	func need(_zone: int) -> bool:return true
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func _initialize():run.call_deferred()
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.cq_profile=true;game.match_mode.conquest.install();game.match_mode.configure({"sv_gametype":"cq"});game.dedicated=true;game.selected_map=game.match_mode.conquest.MAP_ID
	game.start_host("Admission fixture",0,100,30,true)
	for id in game.players.keys():State.remove(game,id)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	var gateway=Gateway.new();gateway.game=game;game.add_child(gateway);gateway.set_process(false)
	for i in 16:
		var id: int=-100-i;game.pending_teams[id]=0;game._add_player(id,"Resident")
		game.fighters[id].position=Rules.center(1)
		gateway.owners[id]={"zone":1,"generation":1,"phase":"active","ack":true,"last_seq":-1,"baseline":false}
	game.district_gateway=gateway
	game.match_mode.conquest.rules.owners.fill(1);game.match_mode.conquest.rules.owners[1]=0
	gateway.workers[1]={"ready":false,"wire":null,"pid":0,"external":true}
	game.pending_teams[-999]=0;game._add_player(-999,"Waiting join")
	check(game.players[-999].dead and gateway.owners[-999].phase=="spawn_wait","New join waits when every friendly district is full")
	check(Capacity.counts(gateway.owners)[1]==16 and not gateway.closing,"Waiting join neither overfills nor stops the master")
	gateway.progress(-999)
	check(gateway.owners[-999].phase=="spawn_wait","No premature admission while friendly district remains full")
	game._peer_left(-100);gateway.progress(-999)
	check(not game.players[-999].dead and gateway.owners[-999].zone==1 and gateway.owners[-999].phase=="waiting","Freed slot deploys waiting join in friendly territory")
	check(Capacity.counts(gateway.owners)[1]==16,"Waiting join reserves exactly one slot")
	var group: int=game.players[-999].cq_group_zone
	gateway.owners[-999].phase="active";game.fighters[-999].position=Rules.center(0);gateway.owners[-999].zone=0
	# Fill the vacated friendly slot; the dead actor is now in hostile territory.
	game.pending_teams[-998]=0;game._add_player(-998,"Last friendly slot")
	game.players[-999].dead=true;game.players[-999].hp=0;game.players[-999].frags=7
	gateway.owners[-999].respawn_pending=true;gateway.respawn(-999)
	check(gateway.owners[-999].phase=="spawn_wait" and Capacity.counts(gateway.owners)[0]==0,"Defeated player leaves hostile simulation when friendly districts are full")
	check(game.players[-999].team==0 and game.players[-999].frags==7,"Waiting preserves team and score")
	gateway.progress(-999)
	check(gateway.owners[-999].phase=="spawn_wait","Dead reinforcement remains unavailable while every friendly slot is taken")
	game._peer_left(-101);gateway.progress(-999)
	check(gateway.owners[-999].zone==1 and not game.players[-999].dead and Capacity.counts(gateway.owners)[1]==16,"Waiting reinforcement automatically deploys to a freed friendly slot")
	check(gateway.owners[-999].baseline,"Returning reinforcement always requests a fresh client baseline")
	check(game.players[-999].cq_group_zone==group and not game.players[-999].has("cq_spawn_zone"),"Temporary deployment preserves original round-start group")
	gateway.owners[-999].phase="active";game.players[-999].dead=true;game.players[-999].hp=0
	game.match_mode.conquest.rules.owners.fill(1);gateway.owners[-999].respawn_pending=true;gateway.respawn(-999);gateway.progress(-999)
	check(gateway.owners[-999].phase=="spawn_wait","Team with no controlled district cannot deploy")
	game.match_mode.conquest.rules.owners[4]=0;gateway.progress(-999)
	check(gateway.owners[-999].zone==4 and not game.players[-999].dead,"Newly captured friendly territory releases a waiting reinforcement")
	game._restart_round()
	check(not gateway.closing and not gateway.resetting and Capacity.counts(gateway.owners).all(func(n):return n<=16),"Round reset clears stale reservations and keeps each district within cap")
	game.disconnect_game();game.queue_free();await process_frame
	print("CQ_CAPACITY_ADMISSION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
