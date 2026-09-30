extends RefCounted
## A jump edge is repeated until consumed, with a short expiry and life/epoch guard.
static var native_packer=preload("res://deathmatch/network/codec.gd").native_codec
static var native_packing_enabled=not OS.get_cmdline_user_args().has("--gdscript-network-packing")
var life := -1
var held := false
var event := 0
var pending := 0
var jump_sequence:=-1
var expires := 0.0
var guards: Dictionary = {}
var jet_event:=0
var jet_pending:=0
var jet_expires:=0.0
var last_press:=-100.0
var jet_held:=false
var jet_triggered:=false
func reset() -> void:
	life = -1; held = false; event = 0; pending = 0; expires = 0; guards.clear();jet_event=0;jet_pending=0;jet_expires=0;last_press=-100.0
	jet_held=false;jet_triggered=false
func sample(command: Dictionary, serial: int, now: float) -> void:
	if life != serial:
		life = serial; held = false; event = 0; pending = 0;jet_event=0;jet_pending=0;last_press=-100.0
		jet_held=false
	jet_triggered=false
	var jet_button: bool=command.get("jetpack",false)==true
	if jet_button and not jet_held and not command.get("input_blocked",false):
		jet_event+=1;jet_pending=jet_event;jet_expires=now+.5;jet_triggered=true
	jet_held=jet_button or command.get("input_blocked",false)
	var pressed: bool = command.get("jump",false) and not command.get("input_blocked",false)
	if pressed and not held:
		event += 1; pending = event; expires = now + .25;jump_sequence=int(command.get("seq",-1))
		if now-last_press<=.30:jet_event+=1;jet_pending=jet_event;jet_expires=now+.5;last_press=-100.0
		else:last_press=now
	held = pressed
	if command.get("input_blocked",false) or now > expires: pending = 0
	if command.get("input_blocked",false):last_press=-100.0;jet_pending=0
	if now>jet_expires:jet_pending=0
func annotate(command: Dictionary, now: float) -> void:
	command.input_life = life
	command.jump_event = pending if now <= expires else 0
	command.jump_seq=jump_sequence
	command.jetpack_event=jet_pending if now<=jet_expires else 0
func acknowledge(serial: int, value: int, jet_value: int=0) -> void:
	if serial == life and value >= pending: pending = 0
	if serial==life and jet_value>=jet_pending:jet_pending=0
func allow(peer: int, now: float) -> bool:
	var row: Dictionary = guards.get(peer,{"tokens":12.0,"time":now})
	row.tokens = minf(12.0,row.tokens + maxf(0,now-row.time)*60.0); row.time = now
	guards[peer] = row
	if row.tokens < 1: return false
	row.tokens -= 1; return true
static func accept(state: Dictionary, command: Dictionary) -> void:
	sync_life(state)
	var jet=command.get("jetpack_event",0)
	if jet is int and jet>state.get("jetpack_ack",0) and jet<=2147483647 and jet-int(state.get("jetpack_ack",0))<=32 and command.get("input_life",-1)==state.serial:
		state.jetpack_ack=jet
		if not state.dead and not state.spectator and not command.get("input_blocked",false):state.jetpack_pending=true
	var value = command.get("jump_event",0)
	if not value is int or value <= 0 or value > 2147483647 or command.get("input_life",-1) != state.serial: return
	if value <= state.get("jump_received",0): return
	if value - int(state.get("jump_received",0)) > 32: return
	state.jump_received = value
	# Consume blocked/dead actions without replaying them after thawing or respawn.
	if state.dead or state.spectator or command.get("input_blocked",false): state.jump_ack = value; return
	state.jump_pending = true
	var sequence=command.get("jump_seq",-1)
	state.jump_pending_seq=sequence if sequence is int and sequence>=0 and sequence<=command.get("seq",-1) else -1
static func sync_life(state: Dictionary) -> void:
	if state.get("jump_event_life",-1) != state.serial:
		state.jump_event_life = state.serial; state.jump_received = 0; state.jump_ack = 0; state.jump_pending = false;state.jetpack_ack=0;state.jetpack_pending=false
static func consume(state: Dictionary, actor,ready_sequence:int=-1) -> bool:
	actor.jetpack_requested=state.get("jetpack_pending",false) and not state.get("input_blocked",false)
	state.jetpack_pending=false
	var edge: bool = state.get("jump_pending",false)
	if ready_sequence>=0 and state.get("jump_pending_seq",-1)>ready_sequence:edge=false
	if edge:state.jump_pending = false
	if edge:
		state.jump_ack = state.get("jump_received",0)
		# A newer press also implies a release, even if the release packet was lost.
		actor.jump_held = false
	return edge or state.jump

static func pack(command:Dictionary) -> PackedByteArray:
	if native_packing_enabled and native_packer and native_packer.has_method("pack_input"):return native_packer.pack_input(command)
	return pack_reference(command)

static func pack_reference(command:Dictionary) -> PackedByteArray:
	# Redundancy is optional; never let tracker/history growth make the server
	# discard the entire input datagram. Keep the oldest unacknowledged trigger.
	var codec=preload("res://deathmatch/network/codec.gd")
	var bytes:PackedByteArray=codec.pack(command)
	if bytes.size()<=1100:return bytes
	var wire:=command.duplicate(true)
	while bytes.size()>1100:
		if wire.get("move_commands",[]).size()>2:wire.move_commands.pop_front()
		elif wire.get("xr",{}).has("face"):wire.xr.erase("face")
		elif wire.get("xr",{}).get("body",{}).size()>1:wire.xr=preload("res://deathmatch/vr/poses.gd").gameplay(wire.xr)
		elif wire.get("fire_events",[]).size()>1:wire.fire_events.pop_back()
		elif wire.get("move_commands",[]).size()>1:wire.move_commands.pop_front()
		else:return PackedByteArray()
		bytes=codec.pack(wire)
	return bytes
