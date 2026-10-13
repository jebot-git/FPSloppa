extends "res://tools/voxel_battle/arena.gd"
## Standalone playable class prototype; historical rendering benchmarks keep their own arena.
var spotting=preload("res://deathmatch/conquest/classes/spotting.gd").new()
var classes=preload("res://deathmatch/conquest/classes/rules.gd").new()
func _ready() -> void:
	classes.setup(self);grenade_adapter.setup(self);grenades.setup(grenade_adapter)
	match_mode=preload("res://deathmatch/conquest/classes/match.gd").new()
	variant_combat=preload("res://deathmatch/conquest/classes/combat.gd").new()
	armory=preload("res://deathmatch/conquest/classes/armory.gd").new()
	map_catalog=[{"id":"voxel_jungle","title":"Jungle Frontier","modes":["tdm"],"sha256":map_identity(),"size":0,"path":"res://tools/voxel_battle/map.gd","source_name":"cq-frontier-procedural-v2"}]
	selected_map="voxel_jungle"
	super._ready()
	if hud:
		hud.host_mode.configure([{"id":"tdm","title":"CQ · CLASS PROTOTYPE"}],"MODE");hud.host_mode.choose("tdm")
		hud.menu_pages.titles.home="CQ"
		hud.menu_pages.navigate("home")
		var page=hud.menu_pages.pages.get("player")
		if page:
			for role in classes.CLASSES:hud.button(page,"CQ CLASS: "+role.to_upper(),func():request_class(role))
			for role in classes.CLASSES:
				for secondary in [false,true]:
					for row in (classes.progression.secondaries if secondary else classes.progression.tracks)[role]:
						var weapon:int=row.weapon
						var button:Button=hud.button(page,armory.data(weapon).name,func():request_equipment(role,weapon,secondary))
						equipment_buttons.append({"button":button,"role":role,"weapon":weapon,"secondary":secondary,"xp":row.xp})
func start_host(player_name:String,port:int,frags:int,minutes:int,training:bool,mode:String="tdm",weapon_rules:String="ut99") -> void:
	super.start_host(player_name,port,frags,minutes,training,mode,weapon_rules)
	votes.allowed_modes=["tdm"]
func maps_for_mode(_mode:String) -> Array:return ["voxel_jungle"]
func host_player_limit() -> int:return 32
func practice_bots_count() -> int:return 0
func network_player_limit() -> int:return 32
func _spawn(id:int) -> void:
	spotting.spotted.erase(id)
	classes.spawn(id)
	grenades.cancel(id);grenades.state(id).counts=[1 if classes.role(id)=="shocktroop" else 0,0,0];grenades.state(id).shoulder=0 if classes.role(id)=="shocktroop" else -1
	players[id].cq_class=classes.role(id);players[id].cq_id=id
	super._spawn(id)
	fighters[id].jetpack_attach_raise=.10
	fighters[id].configure_jetpack(jetpack_allowed_for(id))
func jetpack_allowed_for(id:int) -> bool:return classes.role(id)=="shocktroop" and not classes.downed.has(id)
func player_incapacitated(id:int) -> bool:return classes.downed.has(id)
func _update_crouch(id:int,pose:Dictionary,command:Dictionary={}) -> void:
	if classes.downed.has(id):fighters[id].update_height(.65,true);return
	super._update_crouch(id,pose,command)
func _accept_input(id:int,command:Dictionary) -> void:
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
	if not players.has(id) or player_incapacitated(id) or players[id].dead or lobby.active() or intermission>0:return
	if classes.role(id)=="scout":classes.cloak(id);return
	if classes.role(id) in ["medic","technician"] and players[id].weapon==6:deploy_class_box(id);return
	super._use_for(id)
func defer_lethal(victim:int,attacker:int,weapon:String,gibbed:bool,headshot:bool,bypass:bool) -> bool:
	if weapon=="BLEEDOUT":return false
	if classes.downed.has(victim) and not gibbed and not headshot:players[victim].hp=1;return true
	return classes.incapacitate(victim,attacker,weapon,gibbed,headshot,false)
func _server_tick(delta:float) -> void:
	if active and not lobby.active() and intermission<=0:
		tick_class_tools(delta)
		grenades.tick(delta)
		spotting.tick(self)
		variant_combat.vehicle_lock.tick(self,delta)
		variant_combat.vehicle_lock.guide(self,delta)
		for medic in players:
			if not classes.alive(medic) or classes.role(medic)!="medic":continue
			var s:Dictionary=players[medic]
			if s.weapon!=7 or not s.fire or clock-s.last_input>.35 or s.get("input_blocked",false):continue
			var tip:Vector3=_weapon_transform(medic)*Vector3(0,0,-.12)
			for victim in classes.downed.keys():
				var chest:Vector3=fighters[victim].position+Vector3.UP*.35
				if tip.distance_to(chest)>.25:continue
				if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tip,chest,1)).is_empty():continue
				classes.injection(medic,victim,delta);break
		for row in classes.tick(delta):
			players[row.id].armor=0;_damage(row.id,row.attacker,1,"BLEEDOUT",true)
	super._server_tick(delta)
func _end_round() -> void:
	if intermission<=0:classes.round_awards(-1 if match_mode.scores[0]==match_mode.scores[1] else 0 if match_mode.scores[0]>match_mode.scores[1] else 1)
	super._end_round()
func draw_class_players() -> void:
	if headless:return
	draw_class_tools();grenades.draw()
	var mine:int=multiplayer.get_unique_id()
	for id in fighters:
		var reload_view:Dictionary=variant_combat.magazines.states.get(id,{}).get("physical",{}).get(players[id].weapon,{})
		var models=preload("res://deathmatch/conquest/classes/models.gd")
		if is_instance_valid(fighters[id].avatar):models.animate_reload(fighters[id].avatar.get("gun"),reload_view)
		var carry_key:="carry"+str(id)
		var carry:MeshInstance3D=class_visuals.get(carry_key)
		if reload_view.get("carry",0)!=0 and not players[id].xr.is_empty() and is_instance_valid(fighters[id].avatar) and is_instance_valid(fighters[id].avatar.get("gun")):
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
			tag.text=spotting.ICONS[classes.role(id)]+" "+players[id].name
			tag.modulate=tint.lightened(.2)
			tag.no_depth_test=true
			tag.fixed_size=true
			tag.pixel_size=.0015
			tag.visible=spotting.visible(self,mine,id)
func request_class(role:String) -> void:
	if multiplayer.is_server():classes.choose(multiplayer.get_unique_id(),role)
	else:_cq_class.rpc_id(1,role)
@rpc("any_peer","call_remote","reliable",0)
func _cq_class(role:String) -> void:
	if multiplayer.is_server():classes.choose(multiplayer.get_remote_sender_id(),role)
var designations:Dictionary={}
var class_visuals:Dictionary={}
var beam_mesh:MeshInstance3D
var arc_mesh:MeshInstance3D
var helper_next:=0.0
var helper_points:=PackedVector3Array()
func _local_command() -> Dictionary:
	var command:=super._local_command()
	command.reload=bindings.vr_pressed(xr_rig,"reload") if is_vr() else bindings.pressed("reload")
	command.reload_grip=bindings.vr_pressed(xr_rig,"support") if is_vr() else false
	command.cq_drag=command.reload_grip if is_vr() else bindings.pressed("use")
	return command
func deploy_class_box(id:int) -> bool:
	if not classes.alive(id):return false
	var pose:=_weapon_transform(id)
	var start:Vector3=fighters[id].position+Vector3.UP*.6
	var at:Vector3=pose.origin-pose.basis.z*1.0
	if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,at,1)).is_empty():return false
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*2,1))
	if hit.is_empty() or hit.normal.dot(Vector3.UP)<.7 or hit.position.distance_to(start)>2.5:return false
	return classes.deploy(id,hit.position+Vector3.UP*.005)
func designate(id:int) -> void:
	if classes.role(id)!="scout" or not classes.alive(id):return
	var s:Dictionary=players[id]
	if s.cooldown>0:return
	s.cooldown=.1
	var solution:Dictionary=_shot_solution(id)
	if solution.blocked:designations.erase(id);return
	var start:Vector3=solution.origin;var hit:Dictionary=_trace(start,start-_weapon_transform(id).basis.z*200,id,_shot_rewind(id))
	if not hit.hit:designations.erase(id);return
	designations[id]={"team":s.team,"start":start,"position":hit.position,"target":hit.id,"until":clock+.45,"life":s.serial}
	if hit.id!=0 and not match_mode.same_team(id,hit.id) and clock>=float(classes.states[id].get("designation_xp_at",0)):
		classes.award(id,10);classes.states[id].designation_xp_at=clock+5
func tick_class_tools(delta:float) -> void:
	for key in class_visuals:
		if str(key).begins_with("box") and not classes.dispensers.has(str(key).trim_prefix("box").to_int()):class_visuals[key].visible=false
	for key in classes.dispensers:
		var box:Dictionary=classes.dispensers[key]
		box.credit+=delta*20.0;var amount:=int(box.credit);box.credit-=amount
		if amount<=0 or box.remaining<=0:continue
		for id in players:
			if not classes.alive(id) or players[id].team!=box.team:continue
			var chest:Vector3=fighters[id].position+Vector3.UP*.9
			if chest.distance_to(box.position)>4:continue
			if get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(box.position+Vector3.UP*.15,chest,1)).is_empty():classes.transfer(key,id,amount)
	for technician in players:
		var state:Dictionary=players[technician]
		if not classes.alive(technician) or classes.role(technician)!="technician" or state.weapon!=7 or not state.fire or state.get("input_blocked",false) or clock-state.last_input>.35:continue
		state.cq_repair_credit=float(state.get("cq_repair_credit",0))+delta*30
		var amount:int=int(state.cq_repair_credit);state.cq_repair_credit-=amount
		if amount<=0:continue
		var tip:Vector3=_weapon_transform(technician)*Vector3(0,0,-.15)
		for vehicle in get_tree().get_nodes_in_group("cq_repairable_vehicles"):
			var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tip,vehicle.global_position,1))
			if not hit.is_empty() and not vehicle.owns_collider(hit.collider):continue
			if tip.distance_to(hit.get("position",vehicle.global_position))>1.5:continue
			var restored:int=vehicle.repair(state.team,amount)
			state.cq_repair_xp=float(state.get("cq_repair_xp",0))+restored
			var xp:int=int(state.cq_repair_xp/10);state.cq_repair_xp-=xp*10;classes.award(technician,xp)
			break
	for medic in players:
		if not classes.alive(medic) or classes.role(medic)!="medic" or not players[medic].get("cq_drag",false) or clock-players[medic].last_input>.35:continue
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
	var ally:=PackedVector3Array();var enemy:=PackedVector3Array()
	for row in designations.values():
		if row.until<clock:continue
		if players.get(mine,{}).get("team",-1)==row.team:ally.append_array(PackedVector3Array([row.start,row.position]))
		else:enemy.append_array(preload("res://deathmatch/conquest/classes/beam.gd").clipped(row.start,row.position,eye))
	beam_mesh=line_visual(ally,Color(1,.15,.1,.85),beam_mesh)
	var faded:MeshInstance3D=class_visuals.get("enemy_beam")
	class_visuals.enemy_beam=line_visual(enemy,Color(1,.15,.1,.12),faded)
	for key in class_visuals:
		if str(key).begins_with("box") and not classes.dispensers.has(str(key).trim_prefix("box").to_int()):class_visuals[key].visible=false
	for key in classes.dispensers:
		var box:Dictionary=classes.dispensers[key];var name:="box"+str(key)
		if not class_visuals.has(name):
			var model:Node3D=load("res://deathmatch/weapons/cq/"+("health_box" if box.kind=="health" else "ammo_box")+".glb").instantiate();$Map.add_child(model);class_visuals[name]=model
		class_visuals[name].position=box.position;class_visuals[name].visible=box.remaining>0
	if clock<helper_next:
		arc_mesh=line_visual(helper_points,Color(.4,1,.8,.6),arc_mesh);return
	helper_next=clock+.1
	var points:=PackedVector3Array()
	if classes.role(mine)=="technician" and players.get(mine,{}).get("weapon",-1)==5 and classes.alive(mine):
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_G and active and not menu_open:
		if multiplayer.is_server():equip_he(multiplayer.get_unique_id())
		else:_cq_he_equip.rpc_id(1)
		return
	super._unhandled_input(event)
func equip_he(id:int) -> void:
	if not classes.alive(id) or classes.role(id)!="shocktroop":return
	grenades.equip_hand(id,-1 if grenades.selected(id)>=0 else 0)
@rpc("any_peer","call_remote","reliable",0)
func _cq_he_equip() -> void:
	if multiplayer.is_server():equip_he(multiplayer.get_remote_sender_id())
func class_throw(action:String,pose:Dictionary,_velocity:Vector3,seq:int) -> void:
	if multiplayer.is_server():accept_class_throw(multiplayer.get_unique_id(),action,pose,seq)
	else:_cq_throw.rpc_id(1,action,pose,seq)
@rpc("any_peer","call_remote","reliable",0)
func _cq_throw(action:String,pose:Dictionary,seq:int) -> void:
	if multiplayer.is_server():accept_class_throw(multiplayer.get_remote_sender_id(),action,pose,seq)
func accept_class_throw(id:int,action:String,pose:Dictionary,seq:int) -> void:
	if not classes.alive(id) or classes.role(id)!="shocktroop" or seq<=throw_sequence.get(id,-1) or action not in ["arm","throw","cancel"]:return
	throw_sequence[id]=seq
	var checked:Dictionary=VRPoses.validate(pose);var current:Dictionary=players[id].xr
	if checked.is_empty() or current.is_empty() or checked.left_handed!=current.left_handed:return
	for hand in ["left","right","head"]:
		if checked[hand].origin.distance_to(current[hand].origin)>.12:return
	grenades.physical_request(id,action,checked,players[id].get("cq_throw_velocity",Vector3.ZERO))
@rpc("authority","call_local","reliable",1)
func _de_grenade_fx(position:Vector3,_kind:int) -> void:
	if effects:effects.play("explosion",position,-3)
func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=preload("res://deathmatch/conquest/classes/visuals.gd").new();variant_visuals.name="CQWeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination)
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
	_play_shot_fx(id,weapon,false,alternate)
	if headless:return
	if id==multiplayer.get_unique_id():visual_cooldown=armory.data(weapon,alternate).cycle
	if weapon in [0,1]:
		var pose:Transform3D=_weapon_transform(id);var point:Vector3=pose*preload("res://deathmatch/conquest/classes/models.gd").muzzle(weapon,"cq_"+classes.role(id))
		_weapon_illumination(point,point,shot_emission(id,weapon),id)
		var flash:=Node3D.new();add_child(flash);flash.position=point;flash.basis=pose.basis
		Art.box(flash,Vector3(0,0,-.02),Vector3(.04,.04,.06),Art.material(shot_color(id,weapon),0,5));get_tree().create_timer(.045).timeout.connect(flash.queue_free)
	if weapon in [2,3,9]:
		var sound:=AudioStreamPlayer3D.new();sound.stream=load("res://deathmatch/audio/cq_weapons/"+("pistol_suppressed" if weapon==9 else "pistol")+".wav");sound.bus="ArenaEffects";sound.volume_db=-12 if weapon==9 else -4;sound.max_distance=18 if weapon==9 else 90;add_child(sound);sound.position=_weapon_transform(id).origin;sound.finished.connect(sound.queue_free);sound.play()
	elif weapon in [0,1,4,10]:spatial.play("ut99_weapon_7",_weapon_transform(id).origin,-5)
	elif weapon in [5,11]:spatial.play("weapon_8",_weapon_transform(id).origin,-6)
const CLASS_PROTOCOL:="fpsloppa-cq-frontier-3-pack-launchers"
func connection_protocol() -> String:return CLASS_PROTOCOL
func _collect(_id:int) -> void:pass # CQ resupplies through its class dispensers.
func on_player_died(id:int) -> void:
	classes.downed.erase(id);classes.injecting.erase(id);classes.weapon_used(id)
	grenades.on_death(id);variant_combat.cancel_player(id)

static func map_identity() -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for file in ["landscape","architecture","outer_architecture","hydrology","waterways","map","water_contents"]:
		digest.update(FileAccess.get_file_as_bytes("res://tools/voxel_battle/"+file+".gd"))
	return digest.finish().hex_encode()
func _load_map(map_id:String) -> bool:
	var loaded:bool=super._load_map(map_id)
	if loaded:map_sha=map_identity()
	return loaded
func _peer_left(id:int) -> void:
	super._peer_left(id)
	classes.states.erase(id);classes.downed.erase(id);classes.injecting.erase(id);designations.erase(id);throw_sequence.erase(id)
	variant_combat.magazines.states.erase(id);variant_combat.charges.erase(id);variant_combat.vehicle_lock.locks.erase(id);spotting.spotted.erase(id)

func _trace(start:Vector3,end:Vector3,exclude:int,rewind:float=0.0,radius:float=0.0,movement_start:Dictionary={},candidates:Variant=null) -> Dictionary:
	var hit:Dictionary=super._trace(start,end,exclude,rewind,radius,movement_start,candidates)
	if not hit.hit:return hit
	var contact:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,hit.position+(end-start).normalized()*.05,1))
	if not contact.is_empty():
		for vehicle in get_tree().get_nodes_in_group("cq_repairable_vehicles"):
			if vehicle.hp>0 and vehicle.owns_collider(contact.collider):hit["cq_vehicle"]=vehicle;break
	return hit
func _damage_map_hit(hit:Dictionary,id:int,amount:float) -> void:
	if multiplayer.is_server() and hit.has("cq_vehicle"):
		var vehicle=hit.cq_vehicle
		vehicle.damage(players.get(id,{}).get("team",-1),int(amount))
		if variant_combat.active_projectile>=0:vehicle.set_meta("cq_direct_projectile",variant_combat.active_projectile)
	super._damage_map_hit(hit,id,amount)
var equipment_buttons:Array=[]
func request_equipment(role_name:String,weapon:int,secondary:bool) -> void:
	if multiplayer.is_server():classes.choose_equipment(multiplayer.get_unique_id(),role_name,weapon,secondary)
	else:_cq_equipment.rpc_id(1,role_name,weapon,secondary)
@rpc("any_peer","call_remote","reliable",0)
func _cq_equipment(role_name:String,weapon:int,secondary:bool) -> void:
	if multiplayer.is_server():classes.choose_equipment(multiplayer.get_remote_sender_id(),role_name,weapon,secondary)
func equipment_menu() -> void:
	var state:Dictionary=classes.states.get(multiplayer.get_unique_id(),{})
	for row in equipment_buttons:
		var xp:int=state.get("xp",{}).get(row.role,0)
		row.button.disabled=state.is_empty() or xp<row.xp
		var choice:int=state.get("secondary_choices" if row.secondary else "primary_choices",{}).get(row.role,8 if row.role=="scout" else 2) if row.secondary else state.get("primary_choices",{}).get(row.role,classes.progression.STARTERS[row.role][0])
		row.button.text=("✓ " if choice==row.weapon else "")+row.role.to_upper()+" "+("SECONDARY: " if row.secondary else "PRIMARY: ")+armory.data(row.weapon).name+(" · %d / %d XP"%[xp,row.xp] if xp<row.xp else "")
func _process(delta:float) -> void:
	super._process(delta)
	if menu_open:equipment_menu()
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
