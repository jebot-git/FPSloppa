extends "res://deathmatch/bots.gd"
## Normal AI, except an explicitly commanded gate-crossing test actor.
var crossing: Dictionary={}
func tick(delta: float) -> void:
	super.tick(delta)
	for id in crossing.keys():
		if not game.players.has(id):crossing.erase(id);continue
		var s: Dictionary=game.players[id];var point: Vector3=game.fighters[id].position
		var target: Vector3=crossing[id]
		var move: Vector3=(target-point);move.y=0;move=move.normalized()
		s.yaw=0;s.move=Vector2(move.x,move.z);s.fire=false;s.jump=false;s.last_input=game.clock
		if point.distance_to(target)<.4:crossing.erase(id);s.move=Vector2.ZERO
