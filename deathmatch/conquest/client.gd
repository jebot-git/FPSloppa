extends RefCounted
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
const Events=preload("res://deathmatch/server/districts/events.gd")
var game
var enabled:=false
var frozen:=false
var generation:=0
var zone:=-1
var handoffs:=0
var rejected:=0
var visible: Array=[]
var events_received:=0
func _init(arena):game=arena
func reset() -> void:enabled=false;frozen=false;generation=0;zone=-1;visible.clear()
func transition(epoch: int,next: int,district: int) -> void:
	if not game.cq_profile or epoch!=game.map_epoch or next<=generation:return
	enabled=true;frozen=true;generation=next;zone=district;visible.clear()
	game.replication.reset();game.remote_interpolation.reset();game.remote_view_time=-1;game.snapshot_view_time=-1
	game.fire_delivery.pending=[];game.input_delivery.pending=0
	game.variant_combat.predictions.clear()
	for actor in game.fighters.values():actor.prediction.clear();actor.reset_view()
	for id in game.projectiles.keys():
		if is_instance_valid(game.projectiles[id].node):game.projectiles[id].node.queue_free()
	game.projectiles.clear();game.ended_projectiles.clear();game.projectile_watermark=-1
	game._cq_ready.rpc_id(1,epoch,generation)
func baseline(epoch: int,gen: int,bytes: PackedByteArray) -> void:
	if epoch!=game.map_epoch or gen!=generation or not frozen:rejected+=1;return
	var snapshot=Codec.unpack(bytes)
	if not snapshot is Array or snapshot.size()!=14 or snapshot[9]!=epoch:return
	var mine: int=game.multiplayer.get_unique_id()
	if not game.fighters.has(mine) or not snapshot[0].any(func(row):return row[0]==mine):return
	game.replication.reset()
	for row in snapshot[0]:
		if row[0]==mine:
			game.fighters[mine].position=row[1];game.fighters[mine].velocity=row[2];game.fighters[mine].prediction.clear()
	var seed_stream=preload("res://deathmatch/network/replication.gd").new()
	var seed_packets: Dictionary=seed_stream.packets(snapshot)
	for packet in seed_packets.normal+seed_packets.large:game.replication.receive(packet,epoch)
	game.replication.flush()
	game.callv("_snapshot",snapshot)
	game.fighters[mine].prediction.clear();game.fighters[mine].reset_physics_interpolation()
	var loco: Dictionary=snapshot[10].get("locomotion",{}).get(mine,{})
	game.input_delivery.event=maxi(game.input_delivery.event,int(loco.get("jump_ack",0)))
	game.fire_delivery.event=maxi(game.fire_delivery.event,int(loco.get("fire_ack",0)))
	frozen=false;handoffs+=1
	print("CQ_BASELINE zone=",zone," generation=",generation)
func packet(epoch: int,gen: int,bytes: PackedByteArray) -> void:
	if not enabled or frozen or epoch!=game.map_epoch or gen!=generation:rejected+=1;return
	game._state_packet(bytes)
func event(epoch: int,gen: int,method: String,args: Array) -> void:
	if not enabled or frozen or epoch!=game.map_epoch or gen!=generation:rejected+=1;return
	if method in Events.ALLOWED:events_received+=1;game.callv(method,args)
func membership(rows: Array) -> void:
	if not enabled:return
	visible=rows.map(func(row):return row[0])
	var mine: int=game.multiplayer.get_unique_id()
	if game.players.has(mine) and mine not in visible:visible.append(mine)
	for id in game.fighters:
		game.fighters[id].visible=id in visible
		if id not in visible:game.fighters[id].collision_layer=0;game.remote_interpolation.tracks.erase(id)
