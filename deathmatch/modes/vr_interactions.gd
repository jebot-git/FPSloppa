extends Node
## Reliable discrete actions plus fresh-pose hand contacts, all validated by the server.
const Poses=preload("res://deathmatch/vr/poses.gd")
const Clearance=preload("res://deathmatch/vr/weapon_clearance.gd")
var owner_ref: WeakRef
var tf:
	get:return owner_ref.get_ref()
var game:
	get:return tf.game
var history: Dictionary={}
var armed: Dictionary={}
var sequences: Dictionary={}
var next_arm: Dictionary={}
func setup(value) -> void:owner_ref=weakref(value)
func reset() -> void:history.clear();armed.clear();sequences.clear();next_arm.clear()
func departed(id: int) -> void:history.erase(id);armed.erase(id);sequences.erase(id);next_arm.erase(id)
func eligible(id: int) -> bool:
	return multiplayer.is_server() and game.active and not game.map_loading and not game.lobby.active() and game.intermission<=0 and tf.mode.kind in ["tf","as"] and game.players.has(id) and not game.players[id].dead and not game.players[id].spectator and not tf.mode.special.blocked(id)
func clear_path(start: Vector3,end: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(start,end,1);query.hit_from_inside=true
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func body_transform(id: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,game.players[id].yaw),game.fighters[id].position)
func sample(id: int) -> void:
	if not eligible(id) or not game.players[id].get("physical",false) or game.players[id].xr.is_empty():history.erase(id);armed.erase(id);return
	var pose: Dictionary=game.players[id].xr
	if armed.has(id) and (armed[id].until<game.clock or armed[id].role!=game.players[id].get("tf_class","") or armed[id].left_handed!=pose.left_handed):armed.erase(id)
	# Only contact abilities need per-pose sweeps. Throw validation runs at release.
	if tf.mode.kind=="tf" and not game.players[id].get("tf_class","") in ["engineer","medic"]:history.erase(id);return
	var previous: Dictionary=history.get(id,{})
	var elapsed: float=game.clock-previous.get("time",game.clock)
	var fresh: bool=elapsed>=.005 and elapsed<=.2 and previous.get("left_handed",pose.left_handed)==pose.left_handed
	var body:=body_transform(id)
	var chest: Vector3=body.origin+Vector3.UP*game.fighters[id].torso_height()
	var current: Dictionary={"time":game.clock,"left_handed":pose.left_handed,"contacts":{}}
	for hand in ["left","right"]:
		# Head-relative displacement ignores locomotion, room-scale rebasing and snap turns.
		var relative: Vector3=pose[hand].origin-pose.head.origin
		var displacement: Vector3=relative-previous.get(hand,relative)
		var valid: bool=fresh and displacement.length()<=.65
		var speed: float=minf(12,displacement.length()/elapsed) if valid else 0.0
		current[hand]=relative
		var end: Vector3=body*pose[hand].origin
		var start: Vector3=end-body.basis*displacement if valid else end
		if not clear_path(chest,end) or not clear_path(start,end):continue
		var contacts: Dictionary=previous.get("contacts",{})
		if tf.mode.kind=="as":
			var rules=tf.mode.assault
			if rules.stage<rules.objectives.size():
				var center: Vector3=rules.button_position(rules.stage)
				if touch(hand+":button:"+str(rules.stage),start,end,center,.22,speed,.15,contacts,current.contacts) and clear_path(end,center):
					if rules.activate(id):feedback(id,hand=="left")
		else:
			var role: String=game.players[id].get("tf_class","")
			if role=="engineer":
				for key in tf.buildings:
					var center: Vector3=tf.buildings[key].position+Vector3.UP*.8
					if touch(hand+":building:"+str(key),start,end,center,.55,speed,.7,contacts,current.contacts) and clear_path(end,center):
						if tf.repair_building(id,key,end):feedback(id,hand=="left")
			elif role=="medic":
				for other in game.players:
					if other==id:continue
					var center: Vector3=game.fighters[other].position+Vector3.UP*minf(1.15,game.fighters[other].collision_height-.30)
					if touch(hand+":heal:"+str(other),start,end,center,.38,speed,.4,contacts,current.contacts) and clear_path(end,center):
						if tf.heal(id,other,end):feedback(id,hand=="left")
	history[id]=current
static func touch(key: String,start: Vector3,end: Vector3,center: Vector3,radius: float,speed: float,minimum: float,previous: Dictionary,current: Dictionary) -> bool:
	var contact:=Geometry3D.get_closest_point_to_segment(center,start,end).distance_to(center)<=radius
	# Leaving a target releases it immediately; a fast pass-through still latches once.
	if end.distance_to(center)<=radius or contact and start.distance_to(center)>radius:current[key]=true
	return contact and not previous.has(key) and speed>=minimum
func submit(kind: String,pose: Dictionary,velocity: Vector3,seq: int) -> void:
	var life: int=game.local_state().get("serial",-1)
	if multiplayer.is_server():request_for(multiplayer.get_unique_id(),game.map_epoch,life,seq,kind,pose,velocity)
	else:request.rpc_id(1,game.map_epoch,life,seq,kind,pose,velocity)
@rpc("any_peer","call_remote","reliable",0)
func request(epoch: int,life: int,seq: int,kind: String,pose: Dictionary,velocity: Vector3) -> void:
	if multiplayer.is_server():request_for(multiplayer.get_remote_sender_id(),epoch,life,seq,kind,pose,velocity)
func request_for(id: int,epoch: int,life: int,seq: int,kind: String,raw_pose: Dictionary,velocity: Vector3) -> bool:
	if not eligible(id) or epoch!=game.map_epoch or life!=game.players[id].serial or seq<=sequences.get(id,-1) or not kind in ["arm","throw","ability","cancel"]:return false
	sequences[id]=seq
	if kind=="cancel":armed.erase(id);return true
	var pose:=Poses.validate(raw_pose)
	var accepted:=false
	if not pose.is_empty() and velocity.is_finite():
		var hand: String="right" if pose.left_handed else "left"
		var body:=body_transform(id)
		var position: Vector3=body*pose[hand].origin
		var chest: Vector3=body.origin+Vector3.UP*game.fighters[id].torso_height()
		if clear_path(chest,position):
			var role: String=game.players[id].get("tf_class","")
			match kind:
				"ability":
					armed.erase(id);accepted=tf.action(id)
				"arm":
					var s: Dictionary=game.players[id]
					if tf.can_act(id) and role in ["soldier","demoman","pyro"] and not tf.charges.has(id) and game.clock>=next_arm.get(id,0) and s.ammo[3 if role=="pyro" else 2]>=(20 if role=="pyro" else 1):
						armed[id]={"until":game.clock+10,"role":role,"left_handed":pose.left_handed};next_arm[id]=game.clock+.25;accepted=true
				"throw":
					var held: Dictionary=armed.get(id,{})
					armed.erase(id)
					if held.get("until",0)>game.clock and held.get("role","")==role and held.get("left_handed",false)==pose.left_handed:
						var solution:=Clearance.solve(game.get_world_3d().direct_space_state,chest,position,position,.12)
						if not solution.blocked:
							# Controller speed is bounded like the replicated poses. No fixed forward launch.
							accepted=tf.throw_charge(id,solution.origin,body.basis*velocity.limit_length(12))
	if kind in ["arm","throw"] and not accepted:armed.erase(id)
	if id==multiplayer.get_unique_id():reply(epoch,life,seq,kind,accepted)
	else:reply.rpc_id(id,epoch,life,seq,kind,accepted)
	return accepted
@rpc("authority","call_remote","reliable",0)
func reply(epoch: int,life: int,seq: int,kind: String,accepted: bool) -> void:
	if epoch!=game.map_epoch or life!=game.local_state().get("serial",-1) or not is_instance_valid(game.xr_rig):return
	game.xr_rig.physical_actions.reply(seq,kind,accepted)
func feedback(id: int,left: bool) -> void:
	if id<1:return
	if id==multiplayer.get_unique_id():contact_feedback(game.map_epoch,game.players[id].serial,left)
	else:contact_feedback.rpc_id(id,game.map_epoch,game.players[id].serial,left)
@rpc("authority","call_remote","unreliable",0)
func contact_feedback(epoch: int,life: int,left: bool) -> void:
	if epoch!=game.map_epoch or life!=game.local_state().get("serial",-1) or not is_instance_valid(game.xr_rig):return
	game.xr_rig.feedback(.45,.09,left!=game.xr_rig.left_handed)
