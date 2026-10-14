extends Node
var driver
var ready_player:=false
var epoch:=0
var life:=0
var packets:=0
var bytes_received:=0
var rejected:=""
var replication=preload("res://deathmatch/network/replication.gd").new()
@rpc("any_peer","call_remote","reliable",0)
func _hello(player_name: String,version: String,spectator: bool=false) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _map_ready(checksum: String) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String) -> void:
	rejected=reason;print("LOAD_CLIENT_REJECTED ",reason)
@rpc("authority","call_local","reliable",0)
func _roster(data: Array) -> void:
	for row in data:
		if row[0]==multiplayer.get_unique_id():ready_player=true
@rpc("any_peer","call_remote","reliable",0)
func _suicide_request(epoch: int,life: int) -> void:
	pass
@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_command(command: Dictionary) -> void:
	pass
@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_packet(bytes: PackedByteArray) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _power_spawn(where: Vector3) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _pickup_event(id: int,kind: String,item: int,weapon: int) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _projectile_spawn(id:int,owner_id:int,weapon:int,pos:Vector3,direction:Vector3,yaw:float,pitch:float,extra:Dictionary={}) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _round_end_gong(epoch: int) -> void:
	pass
@rpc("authority","call_remote","unreliable",1)
func _state_packet(bytes: PackedByteArray) -> void:
	packets+=1;bytes_received+=bytes.size()
	if packets%120==0:
		replication.receive(bytes,epoch)
		var row:Array=replication.player_rows.get(multiplayer.get_unique_id(),[])
		if not row.is_empty():life=row[14]
@rpc("authority","call_remote","reliable",7)
func _state_large(bytes: PackedByteArray) -> void:
	packets+=1;bytes_received+=bytes.size()
	if packets%120==0:
		replication.receive(bytes,epoch)
		var row:Array=replication.player_rows.get(multiplayer.get_unique_id(),[])
		if not row.is_empty():life=row[14]
@rpc("authority","call_remote","unreliable_ordered",1)
func _snapshot_packet(bytes: PackedByteArray,size: int) -> void:
	pass
@rpc("authority","call_local","unreliable_ordered",1)
func _snapshot(data: Array,items: PackedByteArray,remaining: float,pause: float,message: String,limit: int,duration: float,shots: Array,gate_states: Array,epoch: int=0,mode_state: Dictionary={},vote_state: Dictionary={},server_time: float=-1.0,shot_watermark: int=-1) -> void:
	pass
@rpc("any_peer","call_remote","unreliable",3)
func _ping(stamp: int) -> void:
	pass
@rpc("authority","call_remote","unreliable",3)
func _pong(stamp: int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _use_request() -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _gate_state(index: int,opened: bool) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _chat_request(message: String,team_only: bool=false) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _announcement(message: String,is_chat: bool=false) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _hit_confirm(id: int) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _melee_fx(id: int,offhand: bool=false) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _shot_fx(id: int,weapon: int,offhand: bool=false) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _ability_fx(kind: String,start: Vector3,end: Vector3,team: int) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _projectile_end(id: int,pos: Vector3,weapon: int) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _hurt_fx(id: int,pos: Vector3,direction: Vector3,amount: int,dead: bool,gibbed: bool,seed_value: int,screen_only: bool=false,weapon_name: String="",blast: bool=false) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _teleport_fx(pos: Vector3) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _map_input_pause(epoch: int, paused: bool) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func _capture_feedback(team: int,scorer: String,score: int) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _saw_contact(pos: Vector3,normal: Vector3,id: int,other: int=0) -> void:
	pass
@rpc("authority","call_local","reliable",3)
func _movement_sound(epoch: int,id: int,serial: int,kind: String,where: Vector3) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _variant_shot_fx(id: int,weapon: int,alternate: bool) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _variant_bounce_fx(pos: Vector3,weapon: int) -> void:
	pass
@rpc("authority","call_local","unreliable",3)
func _variant_combo_fx(pos: Vector3) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _cq_transition(epoch: int,generation: int,zone: int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_ready(epoch: int,generation: int) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _cq_baseline(epoch: int,generation: int,bytes: PackedByteArray) -> void:
	pass
@rpc("authority","call_remote","unreliable",1)
func _cq_state(epoch: int,generation: int,bytes: PackedByteArray) -> void:
	pass
@rpc("authority","call_remote","reliable",7)
func _cq_large(epoch: int,generation: int,bytes: PackedByteArray) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _cq_event(epoch: int,generation: int,method: String,args: Array) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func _cq_capacity(epoch: int,counts: Array,revision: int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_class(role:String) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_he_equip() -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_throw(action:String,pose:Dictionary,seq:int) -> void:
	pass
@rpc("authority","call_local","reliable",1)
func _de_grenade_fx(position:Vector3,_kind:int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_equipment(role_name:String,weapon:int,secondary:bool) -> void:
	pass
@rpc("authority","call_local","unreliable",1)
func _cq_beam_impacts(start:Vector3,ends:PackedVector3Array,weapon:int,team:int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_utility(role_name:String,utility:String) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func _cq_nvg(serial:int,epoch:int,seq:int,pose:Dictionary) -> void:
	pass
@rpc("authority","call_local","reliable",1)
func _cq_airstrike_fx(where:Vector3) -> void:
	pass
@rpc("authority","call_local","reliable",1)
func _cq_turret_shot(where:Vector3,direction:Vector3,team:int) -> void:
	pass
