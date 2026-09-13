extends "res://deathmatch/bots.gd"
## Test adapter: reuse planning but emit ordinary network-client inputs only.
class ClientTeamplay extends "res://deathmatch/bot_ai/teamplay.gd":
	func say(_id: int,_message: String) -> void:pass
var next_use:=0.0
func setup(arena: Node) -> void:
	teamplay=ClientTeamplay.new()
	super.setup(arena)
func controlled(id: int) -> bool:
	# This harness owns every non-spectator peer; production bots only own negative IDs.
	return game.players.has(id) and not game.players[id].spectator
func team_rank(id: int) -> int:
	var members: Array=game.players.keys().filter(func(other):return not game.players[other].spectator and game.match_mode.same_team(id,other))
	members.sort();return maxi(0,members.find(id))
func class_action(_id: int,brain: Dictionary) -> void:
	if game.clock<next_use:return
	if brain.enemy!=0 or brain.goal_kind in ["heal","repair","defend"]:
		game._use_request.rpc_id(1);next_use=game.clock+1
func input_for(id: int,delta: float) -> void:
	if not ready_to_walk or not navigation.ready():return
	navigation.install_links();navigation.update_jump_links()
	for other in brains.keys():
		if other!=id:brains.erase(other)
	if not brains.has(id) or brains[id].serial!=game.players[id].serial:brains[id]=new_brain(id)
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or game.match_mode.special.blocked(id):
		s.move=Vector2.ZERO;s.fire=false;s.alt_fire=false;s.jump=false;s.swim=Vector3.ZERO;s.input_blocked=true;return
	s.input_blocked=false
	var brain: Dictionary=brains[id]
	# Respawn timestamps are authority-only; clients must not camp a stale zero.
	for pickup in game.pickups:
		if not pickup.available:pickup.respawn=INF
	teamplay.tick()
	if game.clock>=brain.next:
		brain.next=game.clock+.2;perceive(id,brain)
		if game.clock>=brain.plan_at:plan(id,brain);brain.plan_at=game.clock+.8
	combat(id,brain,delta);steer(id,brain,delta)
