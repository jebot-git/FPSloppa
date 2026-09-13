extends "res://tools/ai_study/baseline/bots.gd"
## Test adapter: reuse planning but emit ordinary network-client inputs only.
class ClientTeamplay extends "res://tools/ai_study/baseline/teamplay.gd":
	func say(_id: int,_message: String) -> void:pass
var next_use:=0.0
func setup(arena: Node) -> void:
	teamplay=ClientTeamplay.new()
	super.setup(arena)
func team_rank(id: int) -> int:
	var members: Array=game.players.keys().filter(func(other):return alive(other) and game.match_mode.same_team(id,other))
	members.sort();return maxi(0,members.find(id))
func class_action(_id: int,brain: Dictionary) -> void:
	if game.clock<next_use:return
	if brain.enemy!=0 or brain.goal_kind in ["heal","repair","defend"]:
		game._use_request.rpc_id(1);next_use=game.clock+1
func input_for(id: int,delta: float) -> void:
	if not ready_to_walk or not navigation.ready():return
	navigation.install_links();navigation.update_jump_links()
	for other in game.players:
		if not game.fighters.has(other):continue
		if not brains.has(other) or brains[other].serial!=game.players[other].serial:brains[other]=new_brain(other)
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or game.match_mode.special.blocked(id):return
	var brain: Dictionary=brains[id]
	# Respawn timestamps are authority-only; clients must not camp a stale zero.
	for pickup in game.pickups:
		if not pickup.available:pickup.respawn=INF
	teamplay.tick()
	if game.clock>=brain.next:
		brain.next=game.clock+.2;perceive(id,brain)
		if game.clock>=brain.plan_at:plan(id,brain);brain.plan_at=game.clock+.8
	combat(id,brain,delta);steer(id,brain,delta)
