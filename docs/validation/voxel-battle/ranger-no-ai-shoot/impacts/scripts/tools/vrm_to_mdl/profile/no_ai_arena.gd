extends "res://tools/vrm_to_mdl/profile/arena.gd"
func create_bot_controller() -> Node:return preload("res://tools/vrm_to_mdl/no_ai_slots.gd").new()
func _server_tick(delta: float) -> void:
	var server_scope:=Trace.begin()
	votes.tick()
	for id in pending_joins.keys():
		if clock>pending_joins[id]:
			server_log.record("join_timeout",{"peer":id,"last_stage":server_log.join_stages.get(id,{}),"transport":server_log.transport(id),"players":players.size(),"capacity":max_clients})
			multiplayer.multiplayer_peer.disconnect_peer(id)
			pending_joins.erase(id)
			pending_names.erase(id)
			loading.pending.erase(id)
			pending_spectators.erase(id)
			map_network.outgoing.erase(id)
	if map_loading:
		# Admission is per peer. Once someone is ready, their client predicts
		# movement, so the authority must simulate it too. A slow asset transfer
		# must not freeze admitted players, lobby voting or the round timer.
		if players.is_empty() and not pending_names.is_empty(): return
		map_loading=false
		_announcement.rpc("New map · "+map_title)
	bot_population.maintain()
	if is_instance_valid(district_gateway):district_gateway.advance(delta);return
	# Keep the match fresh while the dedicated server has no ready clients.
	# Pending downloads and connection timeouts still run above this gate.
	if dedicated and players.is_empty():return
	if lobby.active():
		lobby.tick(delta)
		return
	if intermission>0:
		intermission -= delta
		if intermission<=0:
			if match_mode.kind=="as" and match_mode.assault.switching:match_mode.assault.next_leg()
			elif lobby.enabled and not practice:lobby.begin()
			elif not practice and not lobby.offered.is_empty():lobby.launch()
			else:_restart_round()
		return
	var match_delta: float=match_mode.titanball.advance_time(delta) if match_mode.kind=="tb" else delta
	round_left = maxf(0,round_left-match_delta)
	if round_left<=0:
		if match_mode.kind=="as":match_mode.assault.timeout()
		elif match_mode.kind=="tb":match_mode.titanball.timeout()
		else:_end_round()
		return
	if is_instance_valid(bots) and (not is_instance_valid(district_worker) or players.keys().any(func(id):return id<0)): bots.tick(delta)
	var movement_start: Dictionary = {}
	for id in fighters:
		movement_start[id]={"position":fighters[id].position,"serial":players[id].serial,"height":fighters[id].collision_height,"yaw":fighters[id].damage_yaw()}
	for id in players:
		var s: Dictionary = players[id]
		if is_instance_valid(district_worker) and s.get("cq_wait_input",false):continue
		if s.spectator:
			if clock-s.last_input>.35:s.move=Vector2.ZERO;s.fly=0.0
			_move_spectator(id,s.move,s.fly,s.yaw,s.slow,delta)
			continue
		if match_mode.special.blocked(id):
			if match_mode.special.frozen.has(id):match_mode.special.fall(id,delta)
			continue
		if s.dead:
			if clock>=s.respawn_at and (s.want_respawn or s.get("suicide_respawn",false) or clock>s.respawn_at+3 or id<0): _spawn(id)
			continue
		if clock-s.last_input>.35:
			s.move = Vector2.ZERO
			s.room=Vector3.ZERO;s.swim=Vector3.ZERO
			s.jump=false
			s.fire = false
			s.offhand_fire=false;s.alt_fire=false;s.input_blocked=true
			s.melee = false
		var jump: bool=input_delivery.consume(s,fighters[id])
		if match_mode.fortress.walkers.handle_player(id,jump):continue
		_update_crouch(id,s.xr)
		fighters[id].speed_multiplier=match_mode.fortress.speed(id)
		fighters[id].configure_jetpack(jetpack_allowed(),s.get("input_blocked",false))
		var movement_scope:=Trace.begin()
		fighters[id].simulate(s.move*(1.0-minf(s.room.length()*30/((5.2 if s.slow else 9.4)*fighters[id].speed_multiplier),1.0)),s.yaw,s.slow,delta,jump,s.get("swim",Vector3.ZERO))
		Trace.end("avatar_movement_collision",movement_scope)
		if not s.xr.is_empty():
			var shift:=RoomScale.move_capsule(fighters[id],s.room,s.yaw,delta)
			s.room-=shift
			RoomScale.rebase_pose(s.xr,shift)
			if id==multiplayer.get_unique_id() and is_vr(): xr_rig.compensate_room_move(shift)
		if fighters[id].position.y < fall_limit:
			_damage(id,id,1000,"fell out of the arena",true)
			continue
		s.cooldown = maxf(0,s.cooldown-delta)
		s.offhand_cooldown=maxf(0,s.offhand_cooldown-delta)
		if s.charge>0:
			s.charge -= delta
			if s.charge<=0: _launch(id,8)
		_update_melee(id)
		var trigger_state: Array=fire_delivery.begin_attempt(s,clock,s.weapon==6 and armory.kind in ["doom","quake"])
		if armory.experimental():variant_combat.tick_input(id,delta)
		else:
			if s.fire and s.cooldown<=0: _fire(id)
			if s.weapon==2 and s.offhand_fire and s.offhand_cooldown<=0: _fire(id,true)
		if not s.offhand_fire: s.offhand_held=false
		if not s.fire: s.held = false
		fire_delivery.end_attempt(s,trigger_state)
		_collect(id)
	_update_projectiles(delta,movement_start)
	match_mode.tick(delta)
	_respawn_pickups()
	for gate in gates:
		if gate.open and clock>gate.until:
			var clear := true
			for actor in fighters.values():
				if gate.get("elevator",false) or gate.get("bsp",false):break # Authored movers return with passengers.
				if actor.spectator:continue
				var offset: Vector3 = actor.position-gate.get("center",gate.node.position)
				offset.y = 0
				if offset.length()<1.3: clear = false
			if clear:
				_gate_state.rpc(gates.find(gate),false)

	Trace.end("server_tick",server_scope)
func _trace(start: Vector3,end: Vector3,exclude: int,rewind: float=0.0,radius: float=0.0,movement_start: Dictionary={},candidates: Variant=null) -> Dictionary:
	var stamp:=Trace.begin()
	var result:=super._trace(start,end,exclude,rewind,radius,movement_start,candidates)
	Trace.end("hit_trace",stamp)
	return result
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	var stamp:=Trace.begin()
	super._impacts(start,ends,weapon)
	Trace.end("impact_effects",stamp)
func _variant_shot_fx(id: int,weapon: int,alternate: bool) -> void:
	var stamp:=Trace.begin()
	super._variant_shot_fx(id,weapon,alternate)
	Trace.end("shot_effects",stamp)
func _shot_solution(id: int,offhand: bool=false) -> Dictionary:
	var stamp:=Trace.begin()
	var result:=super._shot_solution(id,offhand)
	Trace.end("shot_solution",stamp)
	return result
