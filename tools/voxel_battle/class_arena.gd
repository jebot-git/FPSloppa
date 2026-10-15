extends "res://tools/voxel_battle/arena.gd"
## Standalone playable class prototype; historical rendering benchmarks keep their own arena.
var squads=preload("res://deathmatch/conquest/classes/squads.gd").new()
var resident=preload("res://deathmatch/native/cq_authority.gd").new()
var battery_tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd").new()
var grass_audio
var weather=preload("res://tools/voxel_battle/weather.gd").new()
var jungle_ambience
var equipment_audio
var reload_audio
var jetpack_audio
var field_audio
var remote_holsters
var turrets=preload("res://deathmatch/conquest/classes/turrets.gd").new()
var healing_field=preload("res://deathmatch/conquest/classes/healing_field.gd").new()
var airstrike=preload("res://deathmatch/conquest/classes/airstrike.gd").new()
var recon_drone=preload("res://deathmatch/conquest/classes/recon_drone.gd").new()
var night_vision=preload("res://deathmatch/conquest/classes/night_vision.gd").new()
var loadout_menu
var revival_timers=preload("res://deathmatch/conquest/classes/revival_timers.gd").new()
var spotting=preload("res://deathmatch/conquest/classes/spotting.gd").new()
var classes=preload("res://deathmatch/conquest/classes/rules.gd").new()
func _ready() -> void:
	add_child(squads);squads.setup(self)
	resident.name="ResidentCQ";add_child(resident);resident.setup(self)
	weather.name="Weather";add_child(weather);weather.setup(self)
	# Client prediction and authority must select the same backend at startup.
	var jolt_available:=false
	for property in ProjectSettings.get_property_list():
		if property.name=="physics/3d/physics_engine":jolt_available="Jolt Physics" in str(property.hint_string).split(",")
	if ProjectSettings.get_setting("physics/3d/physics_engine","")!="Jolt Physics" or not jolt_available:
		push_error("CQ requires a Godot build with Jolt Physics selected; restart after changing the physics backend.")
		get_tree().quit(2);return
	var startup:=OS.get_cmdline_user_args()
	if startup.has("--cq-worker") or startup.has("--cluster-worker") or startup.has("--cq-external-workers"):
		set_process(false);set_physics_process(false)
		push_error("Unified jungle CQ runs one authority; district worker arguments are unsupported.");get_tree().quit(2);return
	add_child(recon_drone);recon_drone.setup(self)
	add_child(airstrike);airstrike.setup(self)
	add_child(healing_field);healing_field.setup(self)
	add_child(turrets);turrets.setup(self)
	add_child(battery_tanks);battery_tanks.setup(self)
	night_vision.setup(self);classes.setup(self);grenade_adapter.setup(self);grenades.setup(grenade_adapter)
	# The inherited rules have not been set up yet; their unparented Node
	# service must be freed before replacing the RefCounted match instance.
	match_mode.fortress.free()
	match_mode=preload("res://deathmatch/conquest/classes/match.gd").new()
	variant_combat=preload("res://deathmatch/conquest/classes/combat.gd").new()
	armory=preload("res://deathmatch/conquest/classes/armory.gd").new()
	map_catalog=[{"id":"voxel_jungle","title":"Jungle Frontier","modes":["tdm"],"sha256":map_identity(),"size":0,"path":"res://tools/voxel_battle/map.gd","source_name":"cq-frontier-procedural-v2"}]
	selected_map="voxel_jungle"
	super._ready()
	if music:music.stop()
	if not headless:
		field_audio=preload("res://deathmatch/conquest/classes/field_audio.gd").new();add_child(field_audio);field_audio.setup(self)
		jetpack_audio=preload("res://deathmatch/conquest/classes/jetpack_audio.gd").new();add_child(jetpack_audio);jetpack_audio.setup(self)
		reload_audio=preload("res://deathmatch/conquest/classes/reload_audio.gd").new();add_child(reload_audio);reload_audio.setup(self)
		equipment_audio=preload("res://deathmatch/conquest/classes/equipment_audio.gd").new();add_child(equipment_audio);equipment_audio.setup(self)
		var visor=preload("res://deathmatch/conquest/classes/night_vision_view.gd").new();add_child(visor);visor.setup(self)
		grass_audio=preload("res://tools/voxel_battle/grass_audio.gd").new();add_child(grass_audio);grass_audio.setup(self)
		jungle_ambience=preload("res://tools/voxel_battle/ambience.gd").new();add_child(jungle_ambience);jungle_ambience.setup(self)
		remote_holsters=preload("res://deathmatch/conquest/classes/holster_visuals.gd").new();add_child(remote_holsters);remote_holsters.setup(self)
	if hud:
		hud.host_mode.configure([{"id":"tdm","title":"CQ · CLASS PROTOTYPE"}],"MODE");hud.host_mode.choose("tdm")
		hud.menu_pages.titles.home="CQ"
		hud.menu_pages.navigate("home")
		loadout_menu=preload("res://deathmatch/conquest/classes/loadout_menu.gd").new();add_child(loadout_menu);loadout_menu.setup(self,hud)
		preload("res://deathmatch/ui/cq/menu.gd").setup(hud)
		preload("res://deathmatch/ui/cq/hud.gd").setup(hud)
		squads.setup_ui(hud)
func start_host(player_name:String,port:int,frags:int,minutes:int,training:bool,mode:String="tdm",weapon_rules:String="ut99") -> void:
	super.start_host(player_name,port,frags,minutes,training,mode,weapon_rules)
	votes.allowed_modes=["tdm"]
func maps_for_mode(_mode:String) -> Array:return ["voxel_jungle"]
func host_player_limit() -> int:return 32
func practice_bots_count() -> int:return 0
func network_player_limit() -> int:return preload("res://deathmatch/server/config.gd").FRONTIER_MAX_CLIENTS

func capacity_policy() -> Dictionary:return preload("res://deathmatch/server/config.gd").frontier_capacity(max_clients)
func _spawn(id:int) -> void:
	if resident.serving() and resident.core and resident.epoch==map_epoch and resident.spawn_request(id):return
	battery_tanks.leave(id,true)
	spotting.spotted.erase(id);recon_drone.marks.erase(id);recon_drone.alerts.erase(id)
	airstrike.cancel(id)
	classes.spawn(id)
	grenades.cancel(id);grenades.state(id).counts=[1 if classes.grenade_kind(id)==0 else 0,0,0,3 if classes.healing_grenades(id) else 0];grenades.state(id).shoulder=classes.grenade_kind(id)
	players[id].cq_class=classes.role(id);players[id].cq_id=id
	super._spawn(id)
	if resident.serving() and resident.core and not resident.attach(id):push_error("Resident CQ actor admission failed")
	fighters[id].jetpack_attach_raise=.10
	fighters[id].configure_jetpack(jetpack_allowed_for(id))
func jetpack_allowed_for(id:int) -> bool:return classes.role(id)=="shocktroop" and not classes.downed.has(id)
func player_incapacitated(id:int) -> bool:return classes.downed.has(id)
func _update_crouch(id:int,pose:Dictionary,command:Dictionary={}) -> void:
	if classes.downed.has(id):fighters[id].update_height(.65,true);return
	super._update_crouch(id,pose,command)
func _accept_input(id:int,command:Dictionary) -> void:
	if resident.serving():resident.input(id,command);return
	var previous:int=players.get(id,{}).get("last_seq",-1)
	var old_pose:Dictionary=players.get(id,{}).get("xr",{}).duplicate()
	var old_stamp:float=players.get(id,{}).get("last_input",clock)
	super._accept_input(id,command)
	if not players.has(id) or players[id].last_seq==previous:return
	if not old_pose.is_empty() and not players[id].xr.is_empty() and clock-old_stamp>=.008 and clock-old_stamp<=.16:
		var pose:Dictionary=players[id].xr
		var hand:String="right" if pose.left_handed else "left"
		players[id].cq_throw_velocity=((pose[hand].origin-pose.head.origin)-(old_pose[hand].origin-old_pose.head.origin))/(clock-old_stamp)
		players[id].cq_throw_velocity=players[id].cq_throw_velocity.limit_length(12)
	players[id].reload=command.get("reload",false)==true
	players[id].reload_grip=command.get("reload_grip",false)==true
	players[id].cq_drag=command.get("cq_drag",false)==true
	if command.get("fire",false)==true or command.get("alt_fire",false)==true or command.get("offhand_fire",false)==true:classes.weapon_used(id)
	if classes.downed.has(id):
		var s:Dictionary=players[id];s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.fire=false;s.alt_fire=false;s.offhand_fire=false;s.jump=false;s.swim=Vector3.ZERO;s.melee=false;s.fire_pending=[];s.jump_pending=false;s.xr={}
func _use_for(id:int) -> void:
	if resident.serving():
		if not resident.native_peers.has(id) or multiplayer.get_remote_sender_id()==0:resident.action(id,0)
		return
	if not players.has(id) or player_incapacitated(id) or players[id].dead or lobby.active() or intermission>0:return
	if battery_tanks.use(id):return
	if battery_tanks.mounted(id):return
	if classes.role(id)=="scout":
		if classes.ensure(id).get("equipped_utility","recon")=="recon_drone":recon_drone.activate(id)
		else:classes.cloak(id)
		return
	if classes.role(id) in ["medic","technician"] and players[id].weapon==6:deploy_class_box(id);return
	super._use_for(id)
func defer_lethal(victim:int,attacker:int,weapon:String,gibbed:bool,headshot:bool,bypass:bool) -> bool:
	if weapon=="BATTERY RUNOVER":return classes.incapacitate(victim,attacker,weapon,false,false,false)
	if weapon in ["BLEEDOUT","VEHICLE DESTROYED","VEHICLE DROWNED"]:return false
	if classes.downed.has(victim) and not gibbed and not headshot:players[victim].hp=1;return true
	return classes.incapacitate(victim,attacker,weapon,gibbed,headshot,false)
@rpc("any_peer","call_remote","reliable",0)
func _suicide_request(epoch:int,life:int) -> void:
	if resident.serving():resident.suicide(multiplayer.get_remote_sender_id(),epoch,life);return
	super._suicide_request(epoch,life)
func _suicide_for(id:int) -> bool:
	if resident.serving():return resident.action(id,7)
	return super._suicide_for(id)
func _restart_round() -> void:
	if resident.serving() and resident.core:resident.core.request_restart();return
	super._restart_round()
func start_join(player_name:String,address:String,port:int,spectator:bool=false) -> void:
	weather.reset();resident.reset_client();super.start_join(player_name,address,port,spectator)
func disconnect_game(reason:String="Disconnected.") -> void:
	resident.reset();super.disconnect_game(reason)
func refresh_resident_roster() -> void:
	if resident.serving():resident.refresh_roster()
func _request_use() -> void:
	if resident.enabled and not multiplayer.is_server():resident.request(0);return
	super._request_use()
func _send_input(command:Dictionary) -> void:
	if resident.enabled and not multiplayer.is_server():resident.send_input(command);return
	super._send_input(command)
func _send_snapshot() -> void:
	if resident.serving():return
	super._send_snapshot()
func resident_navigation(from:Vector3,to:Vector3) -> PackedVector3Array:
	if not is_instance_valid(bots) or not bots.ready_to_walk:return PackedVector3Array()
	return bots.navigation.path(from,to)
func configure_resident_avatar(id:int) -> void:
	if resident.serving():resident.configure_avatar(id)
func _physics_process(delta:float) -> void:
	if resident.serving():resident.physics(delta);return
	super._physics_process(delta)
func _server_tick(delta:float) -> void:
	if active and not lobby.active() and intermission<=0:
		var service_scope_1:=Attribution.begin("simulation.battery_tanks_tick")
		battery_tanks.tick(delta)
		Attribution.end(service_scope_1)
		var service_scope_2:=Attribution.begin("simulation.tick_class_tools")
		tick_class_tools(delta)
		Attribution.end(service_scope_2)
		var service_scope_3:=Attribution.begin("simulation.grenades_tick")
		grenades.tick(delta)
		Attribution.end(service_scope_3)
		var service_scope_4:=Attribution.begin("simulation.healing_field_tick")
		healing_field.tick(delta)
		Attribution.end(service_scope_4)
		var service_scope_5:=Attribution.begin("simulation.night_vision_tick")
		night_vision.tick()
		Attribution.end(service_scope_5)
		var service_scope_6:=Attribution.begin("simulation.recon_drone_tick")
		recon_drone.tick()
		Attribution.end(service_scope_6)
		spotting.tick(self)
		var service_scope_7:=Attribution.begin("simulation.variant_combat_vehicle_lock_tick")
		variant_combat.vehicle_lock.tick(self,delta)
		Attribution.end(service_scope_7)
		var service_scope_8:=Attribution.begin("simulation.variant_combat_vehicle_lock_guide")
		variant_combat.vehicle_lock.guide(self,delta)
		Attribution.end(service_scope_8)
		for medic in players:
			if battery_tanks.mounted(medic) or not classes.alive(medic) or classes.role(medic)!="medic":continue
			var s:Dictionary=players[medic]
			if s.weapon!=7 or not s.fire or clock-s.last_input>.35 or s.get("input_blocked",false):continue
			var tip:Vector3=_weapon_transform(medic)*Vector3(0,0,-.12)
			for victim in classes.downed.keys():
				var chest:Vector3=fighters[victim].position+Vector3.UP*.35
				if tip.distance_to(chest)>.25:continue
				if not Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(tip,chest,1),"query.class_arena._server_tick.ray").is_empty():continue
				classes.injection(medic,victim,delta);break
		for row in classes.tick(delta):
			players[row.id].armor=0;_damage(row.id,row.attacker,1,"BLEEDOUT",true)
	super._server_tick(delta)
	if active and not lobby.active() and intermission<=0:
		var tools_scope:=Attribution.begin("simulation.airstrike_turrets")
		airstrike.tick();turrets.tick();Attribution.end(tools_scope)
func _end_round() -> void:
	if intermission<=0:classes.round_awards(-1 if match_mode.scores[0]==match_mode.scores[1] else 0 if match_mode.scores[0]>match_mode.scores[1] else 1)
	super._end_round()
func draw_class_players() -> void:
	if headless:return
	draw_class_tools();grenades.draw();revival_timers.draw(self)
	var mine:int=multiplayer.get_unique_id()
	for id in fighters:
		var reload_view:Dictionary=variant_combat.magazines.states.get(id,{}).get("physical",{}).get(players[id].weapon,{})
		var models=preload("res://deathmatch/conquest/classes/models.gd")
		if is_instance_valid(fighters[id].avatar):models.animate_reload(fighters[id].avatar.get("gun"),reload_view)
		var carry_key:="carry"+str(id)
		var carry:MeshInstance3D=class_visuals.get(carry_key)
		if not (id==mine and is_vr()) and reload_view.get("carry",0)!=0 and not players[id].xr.is_empty() and is_instance_valid(fighters[id].avatar) and is_instance_valid(fighters[id].avatar.get("gun")):
			if not is_instance_valid(carry):carry=models.ammunition(fighters[id].avatar.get("gun"),players[id].weapon);$Map.add_child(carry);class_visuals[carry_key]=carry
			var pose:Dictionary=players[id].xr;var hand:Transform3D=pose.right if pose.left_handed else pose.left
			carry.transform=Transform3D(Basis(Vector3.UP,players[id].yaw),fighters[id].position)*Transform3D(hand.basis.scaled(Vector3.ONE*.65),hand.origin);carry.visible=not classes.cloaked(id) or id==mine or match_mode.same_team(id,mine)
		elif is_instance_valid(carry):carry.visible=false
		if id==mine:
			models.animate_reload(viewmodel,reload_view)
			if is_vr():models.animate_reload(xr_rig.gun,reload_view)
		var friendly:bool=id==mine or match_mode.same_team(id,mine)
		var team:int=players[id].team
		var tint:Color=match_mode.COLORS[maxi(0,team)]
		fighters[id].set_class_badge("",tint)
		fighters[id].set_cloak_visual(classes.cloaked(id),friendly,tint,get_process_delta_time())
		# Full enemy invisibility includes the weapon, nameplate, badge and shadows.
		if classes.cloaked(id) and not friendly:
			fighters[id].cloak_visibility=0.0
			if fighters[id].cloak_material:fighters[id].cloak_material.set_shader_parameter("visibility",0.0)
		var tag:Label3D=fighters[id].label
		if tag:
			tag.font=spotting.font()
			tag.no_depth_test=true
			tag.fixed_size=true
			tag.pixel_size=.0015
			tag.set_meta("cq_prefix",spotting.ICONS[classes.role(id)]+" ")
			tag.set_player_name(str(tag.get_meta("cq_prefix"))+players[id].name,team,tint)
			tag.visible=spotting.visible(self,mine,id)
func request_class(role:String) -> void:
	if resident.serving():resident.action(multiplayer.get_unique_id(),5,resident.Presentation.ROLES.find(role))
	elif multiplayer.is_server():classes.choose(multiplayer.get_unique_id(),role)
	else:_cq_class.rpc_id(1,role)
@rpc("any_peer","call_remote","reliable",0)
func _cq_class(role:String) -> void:
	if resident.serving():resident.action(multiplayer.get_remote_sender_id(),5,resident.Presentation.ROLES.find(role))
	elif multiplayer.is_server():classes.choose(multiplayer.get_remote_sender_id(),role)
var designations:Dictionary={}
var class_visuals:Dictionary={}
var supply_budgets:Dictionary={}
var beam_mesh:MeshInstance3D
var arc_mesh:MeshInstance3D
var helper_next:=0.0
var helper_points:=PackedVector3Array()
func _local_command() -> Dictionary:
	var command:=super._local_command()
	night_vision.local_input(command)
	command.reload=bindings.vr_pressed(xr_rig,"reload") and xr_rig.cq_hands.holding if is_vr() else bindings.pressed("reload")
	command.reload_grip=bindings.vr_pressed(xr_rig,"support") and xr_rig.cq_hands.holding if is_vr() else false
	command.reload_trigger=bindings.vr_pressed(xr_rig,"offhand_fire") and xr_rig.cq_hands.holding if is_vr() else false
	command.cq_drag=command.reload_grip if is_vr() else bindings.pressed("use")
	if battery_tanks.mounted(multiplayer.get_unique_id()):
		var transport:bool=battery_tanks.rows[battery_tanks.key_for(multiplayer.get_unique_id())].kind=="transport"
		if is_vr():
			var stick:Vector2=bindings.axis(xr_rig,"move") if not command.input_blocked else Vector2.ZERO
			command.move=Vector2(stick.x,-stick.y).limit_length(1) if stick.length()>=.18 else Vector2.ZERO
			command.fire=bindings.vr_pressed(xr_rig,"fire") and not command.input_blocked and not xr_rig.wheel_open()
		command.reload=false;command.reload_grip=false;command.reload_trigger=false;command.cq_drag=false;command.physical=false;command.melee=false;command.offhand_fire=false;command.alt_fire=false;command.room=Vector3.ZERO
		if transport:command.fire=false
		else:command.jump=false

	if is_vr() and xr_rig.cq_utility:xr_rig.cq_utility.decorate(command)
	return command
func deploy_class_box(id:int) -> bool:
	if battery_tanks.mounted(id):return false
	if turrets.equipped(id):return turrets.deploy(id)
	if not classes.alive(id):return false
	var pose:=_weapon_transform(id)
	var start:Vector3=fighters[id].position+Vector3.UP*.6
	var at:Vector3=pose.origin-pose.basis.z*1.0
	if not Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(start,at,1),"query.class_arena.deploy_class_box.ray").is_empty():return false
	var hit:=Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*2,1),"query.class_arena.deploy_class_box.ray")
	if hit.is_empty() or hit.normal.dot(Vector3.UP)<.7 or hit.position.distance_to(start)>2.5:return false
	return classes.deploy(id,hit.position+Vector3.UP*.005)
func designate(id:int) -> void:
	if battery_tanks.mounted(id):return
	if not airstrike.targeting(id) or (classes.role(id)!="scout" and not airstrike.equipped(id)):airstrike.cancel(id);return
	var s:Dictionary=players[id]
	if s.cooldown>0:return
	s.cooldown=.1
	var solution:Dictionary=_shot_solution(id)
	if solution.blocked:airstrike.cancel(id);return
	var direction:Vector3=-_weapon_transform(id).basis.z
	var start:Vector3=solution.origin;var hit:Dictionary=_trace(start,start+direction*200,id,_shot_rewind(id))
	if not hit.hit:airstrike.cancel(id);return
	designations[id]={"team":s.team,"start":start,"position":hit.position,"target":hit.id,"until":clock+.45,"life":s.serial}
	if airstrike.equipped(id):airstrike.designate(id,hit,direction);return
	if hit.id!=0 and not match_mode.same_team(id,hit.id) and clock>=float(classes.states[id].get("designation_xp_at",0)):
		classes.award(id,10);classes.states[id].designation_xp_at=clock+5
func tick_class_tools(delta:float) -> void:
	var contacts:Dictionary={}
	for key in classes.dispensers.keys():
		var box:Dictionary=classes.dispensers[key]
		if box.remaining<=0:continue
		for id in players:
			if not classes.alive(id) or players[id].team!=box.team:continue
			var chest:Vector3=fighters[id].position+Vector3.UP*.9
			if chest.distance_to(box.position)>4 or not classes.needs_supply(key,id):continue
			if not Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(box.position+Vector3.UP*.15,chest,1),"query.class_arena.tick_class_tools.ray").is_empty():continue
			var contact:=Vector2i(key,id);contacts[contact]=true
			# Weighted items are atomic: retain contact credit until a full pack fits.
			supply_budgets[contact]=minf(300,float(supply_budgets.get(contact,0.0))+delta*20)
			var spent:int=classes.transfer(key,id,int(supply_budgets[contact]))
			supply_budgets[contact]-=spent
	for contact in supply_budgets.keys():
		if not contacts.has(contact):supply_budgets.erase(contact)
	for technician in players:
		var state:Dictionary=players[technician]
		if battery_tanks.mounted(technician) or not classes.alive(technician) or classes.role(technician)!="technician" or state.weapon!=7 or not state.fire or state.get("input_blocked",false) or clock-state.last_input>.35:continue
		state.cq_repair_credit=float(state.get("cq_repair_credit",0))+delta*30
		var amount:int=int(state.cq_repair_credit);state.cq_repair_credit-=amount
		if amount<=0:continue
		var tip:Vector3=_weapon_transform(technician)*Vector3(0,0,-.15)
		for vehicle in get_tree().get_nodes_in_group("cq_repairable_vehicles"):
			var hit:Dictionary=Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(tip,vehicle.global_position,1),"query.class_arena.tick_class_tools.ray")
			if not hit.is_empty() and not vehicle.owns_collider(hit.collider):continue
			if tip.distance_to(hit.get("position",vehicle.global_position))>1.5:continue
			var restored:int=vehicle.repair(state.team,amount)
			state.cq_repair_xp=float(state.get("cq_repair_xp",0))+restored
			var xp:int=int(state.cq_repair_xp/10);state.cq_repair_xp-=xp*10;classes.award(technician,xp)
			break
	for medic in players:
		if battery_tanks.mounted(medic) or not classes.alive(medic) or classes.role(medic)!="medic" or not players[medic].get("cq_drag",false) or clock-players[medic].last_input>.35:continue
		var s:Dictionary=players[medic];var pose:Transform3D=Transform3D(Basis(Vector3.UP,s.yaw),fighters[medic].position)
		var hand:Vector3=pose*(s.xr.right.origin if s.xr.left_handed else s.xr.left.origin) if not s.xr.is_empty() else pose*Vector3(0,.4,-.6)
		for victim in classes.downed:
			if not match_mode.same_team(medic,victim):continue
			var actor=fighters[victim]
			if hand.distance_to(actor.position+Vector3.UP*.35)>.6:continue
			var motion:Vector3=(hand-Vector3.UP*.35-actor.position).limit_length(delta*2)
			actor.move_and_collide(motion);break
	for id in designations.keys():
		var row:Dictionary=designations[id]
		if not classes.alive(id) or row.until<clock or players[id].serial!=row.life or players[id].weapon!=8 or not players[id].fire or players[id].get("input_blocked",false):designations.erase(id)
	for key in projectiles:
		var p:Dictionary=projectiles[key]
		if p.weapon!=5 or not p.has("velocity"):continue
		var best:Dictionary={};var alignment:=cos(deg_to_rad(12))
		for row in designations.values():
			if row.team!=p.extra.get("guided_team",-1):continue
			var direction:Vector3=(row.position-p.position).normalized();var score:float=p.velocity.normalized().dot(direction)
			if score>alignment:alignment=score;best=row
		if not best.is_empty():p.velocity=p.velocity.move_toward((best.position-p.position).normalized()*p.velocity.length(),p.velocity.length()*.08*delta)
func line_visual(points:PackedVector3Array,color:Color,existing:MeshInstance3D) -> MeshInstance3D:
	var node:=existing
	if not is_instance_valid(node):
		node=MeshInstance3D.new();$Map.add_child(node);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.mesh=ImmediateMesh.new()
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;node.material_override=material
	# The same mesh is reused when the wearer toggles NVG.
	node.material_override.albedo_color=color
	var mesh:ImmediateMesh=node.mesh;mesh.clear_surfaces()
	if not points.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for point in points:mesh.surface_add_vertex(point)
		mesh.surface_end()
	return node
func draw_class_tools() -> void:
	if headless:return
	var mine:int=multiplayer.get_unique_id()
	var eye:Vector3=xr_rig.head.global_position if is_vr() else camera.global_position if camera else Vector3.ZERO
	var nvg:bool=night_vision.enabled_for(mine)
	var ally:=PackedVector3Array();var enemy:=PackedVector3Array()
	for row in designations.values():
		if row.until<clock:continue
		if players.get(mine,{}).get("team",-1)==row.team:ally.append_array(PackedVector3Array([row.start,row.position]))
		else:enemy.append_array(preload("res://deathmatch/conquest/classes/beam.gd").visible_segment(row.start,row.position,eye,nvg))
	if is_vr() and not menu_open and xr_rig.cq_hands and xr_rig.cq_hands.holding and local_state().get("weapon",-1)==8 and not xr_rig.cq_utility.held and is_instance_valid(xr_rig.gun):
		var start:Vector3=xr_rig.gun.global_transform*preload("res://deathmatch/conquest/classes/models.gd").muzzle(8,"cq_scout")
		var end:Vector3=start-xr_rig.gun.global_basis.z.normalized()*5000.
		var hit:Dictionary=Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(start,end,1),"query.designator.local_beam")
		ally.append_array(PackedVector3Array([start,hit.position if not hit.is_empty() else end]))
	beam_mesh=line_visual(ally,Color(1,.15,.1,1.0 if nvg else .85),beam_mesh)
	var faded:MeshInstance3D=class_visuals.get("enemy_beam")
	class_visuals.enemy_beam=line_visual(enemy,Color(1,.15,.1,1.0 if nvg else .12),faded)
	for key in class_visuals.keys():
		if str(key).begins_with("box") and not classes.dispensers.has(str(key).trim_prefix("box").to_int()):
			if is_instance_valid(class_visuals[key]):class_visuals[key].queue_free()
			class_visuals.erase(key)
	for key in classes.dispensers:
		var box:Dictionary=classes.dispensers[key];var name:="box"+str(key)
		if not class_visuals.has(name):
			var model:Node3D=load("res://deathmatch/weapons/cq/"+("health_box" if box.kind=="health" else "ammo_box")+".glb").instantiate();$Map.add_child(model);preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(model);class_visuals[name]=model
		class_visuals[name].position=box.position;class_visuals[name].visible=box.remaining>0
	if clock<helper_next:
		arc_mesh=line_visual(helper_points,Color(.4,1,.8,.6),arc_mesh);return
	helper_next=clock+.1
	var points:=PackedVector3Array()
	if classes.role(mine)=="technician" and not battery_tanks.mounted(mine) and players.get(mine,{}).get("weapon",-1)==5 and classes.alive(mine):
		var shot:Dictionary=_shot_solution(mine)
		for row in designations.values():
			if row.until<clock or row.team!=players[mine].team:continue
			# Same low/high trajectory solution and world-clearance test as ST mortar.
			var ballistics=preload("res://deathmatch/conquest/classes/ballistics.gd")
			for high in [false,true]:
				var solution:Dictionary=ballistics.solve(shot.origin,row.position,25.0,12.0,Vector3.ZERO,high)
				if solution.is_empty() or not ballistics.clear(get_world_3d().direct_space_state,shot.origin,solution,12.0):continue
				var previous:Vector3=shot.origin
				for i in 25:
					var t:float=solution.time*(i+1)/25;var point:Vector3=shot.origin+solution.velocity*t-Vector3.UP*6*t*t
					points.append(previous);points.append(point);previous=point
				break
			break
	helper_points=points
	arc_mesh=line_visual(points,Color(.4,1,.8,.6),arc_mesh)
var grenade_adapter=preload("res://deathmatch/conquest/classes/grenade_adapter.gd").new()
var grenades=preload("res://deathmatch/conquest/classes/grenades.gd").new()
var throw_sequence:Dictionary={}
func _unhandled_input(event:InputEvent) -> void:
	if bindings.matches("next_weapon",event) or bindings.matches("previous_weapon",event):return
	if event is InputEventKey and event.physical_keycode>=KEY_0 and event.physical_keycode<=KEY_9:return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_N and active and not menu_open and not is_vr():
		night_vision.request();return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_G and active and not menu_open:
		if airstrike.equipped(multiplayer.get_unique_id()):desired_weapon=8
		if multiplayer.is_server():equip_he(multiplayer.get_unique_id())
		elif resident.enabled:resident.request(9)
		else:_cq_he_equip.rpc_id(1)
		return
	super._unhandled_input(event)
func equip_he(id:int) -> void:
	if resident.serving():resident.action(id,9);return
	if not classes.alive(id) or (not classes.has_grenade(id) and not airstrike.equipped(id)):return
	if airstrike.equipped(id):
		players[id].weapon=8;players[id].cooldown=maxf(players[id].cooldown,.28)
		if id==multiplayer.get_unique_id():desired_weapon=8
		return
	grenades.equip_hand(id,-1 if grenades.selected(id)>=0 else classes.grenade_kind(id))
@rpc("any_peer","call_remote","reliable",0)
func _cq_he_equip() -> void:
	if multiplayer.is_server():equip_he(multiplayer.get_remote_sender_id())
func class_throw(action:String,pose:Dictionary,_velocity:Vector3,seq:int) -> void:
	if resident.enabled and not multiplayer.is_server() and action in ["arm","throw","cancel"]:resident.request(2 if action=="arm" else 3 if action=="throw" else 4);return
	if multiplayer.is_server():accept_class_throw(multiplayer.get_unique_id(),action,pose,seq)
	else:_cq_throw.rpc_id(1,action,pose,seq)
@rpc("any_peer","call_remote","reliable",0)
func _cq_throw(action:String,pose:Dictionary,seq:int) -> void:
	if multiplayer.is_server():accept_class_throw(multiplayer.get_remote_sender_id(),action,pose,seq)
func accept_class_throw(id:int,action:String,pose:Dictionary,seq:int) -> void:
	if resident.serving():
		if not resident.native_peers.has(id) and action in ["arm","throw","cancel"]:resident.action(id,2 if action=="arm" else 3 if action=="throw" else 4)
		return
	if not classes.alive(id) or not classes.has_grenade(id) or seq<=throw_sequence.get(id,-1) or action not in ["arm","throw","cancel"]:return
	throw_sequence[id]=seq
	var checked:Dictionary=VRPoses.validate(pose);var current:Dictionary=players[id].xr
	if checked.is_empty() or current.is_empty() or checked.left_handed!=current.left_handed:return
	for hand in ["left","right","head"]:
		if checked[hand].origin.distance_to(current[hand].origin)>.12:return
	grenades.physical_request(id,action,checked,players[id].get("cq_throw_velocity",Vector3.ZERO))
@rpc("authority","call_local","reliable",1)
func _de_grenade_fx(position:Vector3,_kind:int) -> void:
	night_vision.flash(position,70,.65,2.5,1.2)
	if effects:effects.play("cq_field_ordnance_impact",position,-3)
func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=preload("res://deathmatch/conquest/classes/visuals.gd").new();variant_visuals.name="CQWeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination);variant_visuals.nvg_flash.connect(night_vision.flash)
	return variant_visuals
func shot_color(id:int,weapon:int) -> Color:
	if weapon in [0,1,4,5,10,11]:return Color("ff3c39") if players.get(id,{}).get("team",0)==0 else Color("3b8dff")
	return super.shot_color(id,weapon)
func shot_emission(id:int,weapon:int) -> Dictionary:
	var recipe:=super.shot_emission(id,weapon)
	if weapon in [0,1,4,5,10,11]:recipe.color=shot_color(id,weapon)
	if weapon==9:recipe.radius=.4;recipe.energy=.12
	return recipe
func _play_variant_shot_fx(id:int,weapon:int,alternate:bool) -> void:
	if id==multiplayer.get_unique_id() and is_vr():xr_rig.weapon_kick.shot(2 if weapon in [0,2,9,10] else 6,xr_rig.support_aim.engaged)
	if not resident.enabled and weapon not in [6,7,8] and players.has(id):
		var muzzle:Vector3=preload("res://deathmatch/conquest/classes/models.gd").muzzle(weapon,"cq_"+classes.role(id))*(.65 if not players[id].xr.is_empty() else 1.)
		night_vision.flash(_weapon_transform(id)*muzzle,18,.08 if weapon==9 else .14,.07 if weapon==9 else .12)
	_play_shot_fx(id,weapon,false,alternate)
	if headless:return
	if id==multiplayer.get_unique_id():visual_cooldown=armory.data(weapon,alternate).cycle
	if field_audio:field_audio.shot(weapon,_weapon_transform(id).origin)
const CLASS_PROTOCOL:="fpsloppa-cq-frontier-24-cover-ranges"
func connection_protocol() -> String:return CLASS_PROTOCOL
func _collect(_id:int) -> void:pass # CQ resupplies through its class dispensers.
func on_player_died(id:int) -> void:
	battery_tanks.leave(id,true)
	airstrike.cancel(id)
	classes.downed.erase(id);classes.injecting.erase(id);classes.weapon_used(id)
	grenades.on_death(id);variant_combat.cancel_player(id)

static func map_identity() -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for file in ["landscape","architecture","outer_architecture","hydrology","waterways","map","stair_ramps","water_contents","baked_lighting","jungle_sky","light_fixtures","weather_schedule","weather","grass_cover"]:
		digest.update(FileAccess.get_file_as_bytes("res://tools/voxel_battle/"+file+".gd"))
	for path in ["res://experimental-assets/jungle/lighting/bake.json","res://experimental-assets/jungle/lighting/irradiance.png","res://experimental-assets/jungle/lighting/dawn.png","res://experimental-assets/jungle/lighting/skybox.png","res://tools/voxel_battle/baked_lighting.gdshaderinc","res://tools/voxel_battle/jungle_sky.gdshader"]:
		digest.update(FileAccess.get_file_as_bytes(path))
	return digest.finish().hex_encode()
func _load_map(map_id:String) -> bool:
	if resident.serving() and resident.core:resident.reset_instance()
	recon_drone.reset();airstrike.reset();healing_field.reset();turrets.reset();battery_tanks.reset()
	var loaded:bool=super._load_map(map_id)
	if loaded:map_sha=map_identity();battery_tanks.configure()
	return loaded
func _peer_left(id:int) -> void:
	if resident.serving():resident.detach(id)
	battery_tanks.leave(id,true)
	var turret:int=turrets.owner_key(id)
	if turret>=0:turrets.remove(turret)
	super._peer_left(id)
	airstrike.cancel(id)
	night_vision.forget(id);recon_drone.alerts.erase(id);recon_drone.marks.erase(id);recon_drone.heard.erase(id)
	classes.states.erase(id);classes.downed.erase(id);classes.injecting.erase(id);designations.erase(id);throw_sequence.erase(id)
	variant_combat.magazines.states.erase(id);variant_combat.charges.erase(id);variant_combat.vehicle_lock.locks.erase(id);spotting.spotted.erase(id)

func _trace(start:Vector3,end:Vector3,exclude:int,rewind:float=0.0,radius:float=0.0,movement_start:Dictionary={},candidates:Variant=null) -> Dictionary:
	var filtered:Array=players.keys().filter(func(id):return not battery_tanks.mounted(id)) if candidates==null else candidates.filter(func(id):return not battery_tanks.mounted(id))
	var hit:Dictionary=super._trace(start,end,exclude,rewind,radius,movement_start,filtered)
	if not hit.hit:return hit
	var contact:Dictionary=Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(start,hit.position+(end-start).normalized()*.05,1),"query.class_arena._trace.ray")
	if not contact.is_empty():
		if contact.collider.has_meta("cq_turret"):hit["cq_turret"]=contact.collider.get_meta("cq_turret")
		for vehicle in get_tree().get_nodes_in_group("cq_repairable_vehicles"):
			if vehicle.hp>0 and vehicle.owns_collider(contact.collider):hit["cq_vehicle"]=vehicle;break
	return hit
func _damage_map_hit(hit:Dictionary,id:int,amount:float,kind:String="") -> void:
	if hit.has("cq_turret"):turrets.damage(hit.cq_turret,id,amount,variant_combat.active_projectile)
	if multiplayer.is_server() and hit.has("cq_vehicle"):
		var vehicle=hit.cq_vehicle
		if vehicle.get("service")==battery_tanks:
			var p:Dictionary=projectiles.get(variant_combat.active_projectile,{})
			battery_tanks.damage(vehicle.key,p.get("extra",{}).get("cq_team",players.get(id,{}).get("team",-1)),int(amount),kind if not kind.is_empty() else "ordnance" if not p.is_empty() and p.definition.get("cq_effect","")=="ordnance" else "infantry",id)
		else:vehicle.damage(players.get(id,{}).get("team",-1),int(amount))
		if variant_combat.active_projectile>=0:vehicle.set_meta("cq_direct_projectile",variant_combat.active_projectile)
	super._damage_map_hit(hit,id,amount)
func request_equipment(role_name:String,weapon:int,secondary:bool) -> void:
	if resident.serving():resident.action(multiplayer.get_unique_id(),6,resident.Presentation.ROLES.find(role_name),int(secondary),weapon)
	elif multiplayer.is_server():classes.choose_equipment(multiplayer.get_unique_id(),role_name,weapon,secondary)
	else:_cq_equipment.rpc_id(1,role_name,weapon,secondary)
@rpc("any_peer","call_remote","reliable",0)
func _cq_equipment(role_name:String,weapon:int,secondary:bool) -> void:
	if resident.serving():resident.action(multiplayer.get_remote_sender_id(),6,resident.Presentation.ROLES.find(role_name),int(secondary),weapon)
	elif multiplayer.is_server():classes.choose_equipment(multiplayer.get_remote_sender_id(),role_name,weapon,secondary)
func _process(delta:float) -> void:
	super._process(delta)
	if remote_holsters:remote_holsters.draw()
	if not headless and active:battery_tanks.draw()
	if menu_open and loadout_menu:loadout_menu.refresh()
	if headless or not active:return
	var state:Dictionary=local_state()
	if not is_vr() and not state.is_empty() and state.weapon in [1,9,10]:
		var base:float=float(presentation.get("fov",85.0));var steps:Array=[1.5] if state.weapon==1 else [2.0,4.0,8.0] if state.weapon==10 else [1.5,3.0,6.0]
		if desktop_optic_weapon!=state.weapon:desktop_optic_weapon=state.weapon;desktop_optic_index=0;desktop_optic_zoom=steps[0]
		if not menu_open and Input.is_action_just_pressed("ui_up"):desktop_optic_index=mini(steps.size()-1,desktop_optic_index+1)
		if not menu_open and Input.is_action_just_pressed("ui_down"):desktop_optic_index=maxi(0,desktop_optic_index-1)
		desktop_optic_zoom=lerpf(desktop_optic_zoom,steps[desktop_optic_index],1-exp(-delta*10))
		camera.fov=preload("res://deathmatch/vr/sniper_scope.gd").zoom_fov(base,desktop_optic_zoom) if bindings.pressed("alt_fire") and not menu_open else base
	var lock:Dictionary=variant_combat.vehicle_lock.locks.get(multiplayer.get_unique_id(),{})
	var model:Node3D=xr_rig.gun if is_vr() else viewmodel
	if is_instance_valid(model):
		var screen:=model.find_child("GuidanceMonitor",true,false) as Label3D
		if screen and state.get("weapon",-1)==5:
			var charge:Dictionary=variant_combat.charges.get(multiplayer.get_unique_id(),{})
			screen.text="%d%%"%clampi(int((1-(charge.at-clock)/armory.data(5).charge_time)*100),0,100) if not charge.is_empty() else "SALVO"
		elif screen:
			var mag:Dictionary=variant_combat.magazines.states.get(multiplayer.get_unique_id(),{})
			screen.text="RELOAD" if mag.get("cycling",-1)==11 else "PACK" if mag.get("clips",{}).get(11,1)==0 else "LOCK" if lock.get("ready",false) else "%d%%"%int(lock.get("elapsed",0.0)/1.5*100) if not lock.is_empty() else "SEARCH"
var desktop_optic_weapon:=-1
var desktop_optic_index:=0
var desktop_optic_zoom:=1.5

@rpc("authority","call_local","unreliable",1)
func _cq_beam_impacts(start:Vector3,ends:PackedVector3Array,weapon:int,team:int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_cq_beam_impacts",[start,ends,weapon,team])
	demos.event("_cq_beam_impacts",[start,ends,weapon,team])
	if headless:return
	var definition:Dictionary=armory.data(weapon).duplicate();definition.color=Color("ff3c39") if team==0 else Color("3b8dff")
	_weapon_visuals().impacts("ut99",start,ends,weapon,definition)
	if field_audio and not ends.is_empty():field_audio.play_cue("energy_impact",ends[0],-18,35)

func request_utility(role_name:String,utility:String) -> void:
	if resident.serving():resident.utility(multiplayer.get_unique_id(),role_name,utility)
	elif multiplayer.is_server():classes.choose_utility(multiplayer.get_unique_id(),role_name,utility)
	else:_cq_utility.rpc_id(1,role_name,utility)
@rpc("any_peer","call_remote","reliable",0)
func _cq_utility(role_name:String,utility:String) -> void:
	if resident.serving():resident.utility(multiplayer.get_remote_sender_id(),role_name,utility)
	elif multiplayer.is_server():classes.choose_utility(multiplayer.get_remote_sender_id(),role_name,utility)

@rpc("any_peer","call_remote","reliable",0)
func _cq_nvg(serial:int,epoch:int,seq:int,pose:Dictionary) -> void:
	if resident.serving():resident.nvg(multiplayer.get_remote_sender_id(),serial,epoch,seq)
	elif multiplayer.is_server():night_vision.toggle(multiplayer.get_remote_sender_id(),serial,epoch,seq,pose)

@rpc("authority","call_local","reliable",1)
func _cq_airstrike_fx(where:Vector3) -> void:
	if headless:return
	if effects:effects.play("cq_field_ordnance_impact",where,-3)
	_weapon_visuals().burst("ut99",where,5,"rocket",{"cq_effect":"ordnance","color":Color("ffba62")})
const RADIUS_AIRSTRIKE:=18.75

@rpc("authority","call_local","reliable",1)
func _cq_turret_shot(where:Vector3,direction:Vector3,team:int) -> void:
	if headless:return
	if field_audio:field_audio.shot(11,where)
	_weapon_visuals().burst("ut99",where,11,"energy",{"cq_effect":"energy","color":Color("ff3c39") if team==0 else Color("3b8dff")})

func handle_vehicle_player(id:int,_delta:float) -> bool:return battery_tanks.mounted(id)
func _damage(victim:int,attacker:int,amount:int,weapon_name:String,bypass:bool=false,impact:Vector3=Vector3.INF,direction:Vector3=Vector3.ZERO,blast:bool=false,hull_contact:bool=false,heavy_automatic:bool=false,headshot:bool=false) -> void:
	if battery_tanks.mounted(victim) and not bypass:return
	super._damage(victim,attacker,amount,weapon_name,bypass,impact,direction,blast,hull_contact,heavy_automatic,headshot)
@rpc("authority","call_local","reliable",0)
func _projectile_spawn(id:int,owner_id:int,weapon:int,pos:Vector3,direction:Vector3,yaw:float,pitch:float,extra:Dictionary={}) -> void:
	super._projectile_spawn(id,owner_id,weapon,pos,direction,yaw,pitch,extra)
	if extra.has("launch_velocity") and projectiles.has(id):projectiles[id].velocity=extra.launch_velocity

func world_view_camera() -> Camera3D:
	if battery_tanks.mounted(multiplayer.get_unique_id()) and battery_tanks.view and battery_tanks.view.key>=0 and battery_tanks.view.viewport and not menu_open:return battery_tanks.view.sensor
	return super.world_view_camera()

func time_limit_enabled() -> bool:return false
func _create_fighter(id:int) -> void:
	super._create_fighter(id)
	fighters[id].quake_movement=false;fighters[id].configure_cs16(true)

func configure_cq_authority(settings:Dictionary,args:PackedStringArray) -> void:
	resident.configure_server(settings,args)

func _start_dedicated(args:PackedStringArray) -> void:
	super._start_dedicated(args)
	if active:print("CQ_FRONTIER_SERVER_READY backend=monolithic players=",max_clients," unsupported_capacity=",capacity_policy().unsupported," physics_hz=",Engine.physics_ticks_per_second," movement=cs points=200")

func _exit_tree() -> void:
	resident.reset_instance()

func request_cq_use() -> void:
	if resident.enabled:resident.request(0)
	elif multiplayer.is_server():_use_for(multiplayer.get_unique_id())
	else:_use_request.rpc_id(1)

func _weapon_transform(id:int,offhand:bool=false) -> Transform3D:
	if players.has(id) and not players[id].xr.is_empty():
		if id==multiplayer.get_unique_id() and is_vr():
			var pose:Dictionary=xr_rig.sample_pose()
			return xr_rig.global_transform*pose.get("offhand_weapon" if offhand else "weapon",Transform3D.IDENTITY)
		return Transform3D(Basis(Vector3.UP,players[id].yaw),fighters[id].position)*players[id].xr.get("offhand_weapon" if offhand else "weapon",Transform3D.IDENTITY)
	return super._weapon_transform(id,offhand)

func projectile_sound(explosive:bool,weapon:int)->String:
	if weapon==3 and not explosive:return "impact"
	return "cq_field_ordnance_impact" if explosive else "cq_field_energy_impact"

func grass_cover_at(point:Vector3)->bool:
	return preload("res://tools/voxel_battle/grass_cover.gd").contains(point)
