extends RefCounted
## A jump edge is repeated until consumed, with a short expiry and life/epoch guard.
var life := -1
var held := false
var event := 0
var pending := 0
var expires := 0.0
var guards: Dictionary = {}
func reset() -> void:
	life = -1; held = false; event = 0; pending = 0; expires = 0; guards.clear()
func sample(command: Dictionary, serial: int, now: float) -> void:
	if life != serial:
		life = serial; held = false; event = 0; pending = 0
	var pressed: bool = command.get("jump",false) and not command.get("input_blocked",false)
	if pressed and not held:
		event += 1; pending = event; expires = now + .25
	held = pressed
	if command.get("input_blocked",false) or now > expires: pending = 0
func annotate(command: Dictionary, now: float) -> void:
	command.input_life = life
	command.jump_event = pending if now <= expires else 0
func acknowledge(serial: int, value: int) -> void:
	if serial == life and value >= pending: pending = 0
func allow(peer: int, now: float) -> bool:
	var row: Dictionary = guards.get(peer,{"tokens":12.0,"time":now})
	row.tokens = minf(12.0,row.tokens + maxf(0,now-row.time)*60.0); row.time = now
	guards[peer] = row
	if row.tokens < 1: return false
	row.tokens -= 1; return true
static func accept(state: Dictionary, command: Dictionary) -> void:
	sync_life(state)
	var value = command.get("jump_event",0)
	if not value is int or value <= 0 or value > 2147483647 or command.get("input_life",-1) != state.serial: return
	if value <= state.get("jump_received",0): return
	if value - int(state.get("jump_received",0)) > 32: return
	state.jump_received = value
	# Consume blocked/dead actions without replaying them after thawing or respawn.
	if state.dead or state.spectator or command.get("input_blocked",false): state.jump_ack = value; return
	state.jump_pending = true
static func sync_life(state: Dictionary) -> void:
	if state.get("jump_event_life",-1) != state.serial:
		state.jump_event_life = state.serial; state.jump_received = 0; state.jump_ack = 0; state.jump_pending = false
static func consume(state: Dictionary, actor) -> bool:
	var edge: bool = state.get("jump_pending",false)
	state.jump_pending = false
	if edge:
		state.jump_ack = state.get("jump_received",0)
		# A newer press also implies a release, even if the release packet was lost.
		actor.jump_held = false
	return edge or state.jump
