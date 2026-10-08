extends RefCounted
## Server authority; movement owns the energy pool, so shooting and jets compete.
const A=preload("res://deathmatch/tribes/arsenal.gd")
var rules
var game
var spins: Dictionary={}
var fractions: Dictionary={}
var held: Dictionary={}
# In launch order, including airborne mines for blast chains. Trace filters stuck
# state live, so a same-tick landing/removal is immediately visible.
var mines:Dictionary={}
var indexed_mines:=not OS.get_cmdline_user_args().has("--reference-mine-scan")
func setup(value):rules=value;game=rules.game
func reset():spins.clear();fractions.clear();held.clear();mines.clear()
func cancel(id: int):
	spins.erase(id);held.erase(id)
	for key in fractions.keys():
		var fields: PackedStringArray=key.split(":")
		if int(fields[1])==id or int(fields[2])==id:fractions.erase(key)
func tick(delta: float):
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.dead or s.spectator:cancel(id);continue
		if held.has(id) and held[id].until<game.clock:held.erase(id)
		var firing: bool=s.weapon==2 and s.fire and not s.get("input_blocked",false) and game.clock-s.last_input<=.35
		spins[id]=clampf(float(spins.get(id,0.0))+delta*(2.0 if firing else -1.0/3.0),0,1)
func tick_input(id: int,_delta: float):
	var s: Dictionary=game.players[id]
	s.weapon_zoom=s.get("alt_fire",false) and not s.get("input_blocked",false)
	if s.fire:fire(id)
func fire(id: int) -> bool:
	if not game.multiplayer.is_server() or not rules.enabled() or not game.players.has(id):return false
	var pads=rules.stations()
	if rules.vehicles.weapon_operator(id) or pads and pads.defences.operated(id)>=0:return false
	var s: Dictionary=game.players[id];var w: int=s.weapon
	if not game.armory.valid(w) or w not in s.owned or s.dead or s.spectator or s.cooldown>0 or s.get("input_blocked",false) or game.intermission>0 or game.match_mode.special.blocked(id):return false
	if w==2 and spins.get(id,0.0)<1:return false
	if w<8 and not A.allowed(s.tribes_class,w,s.tribes_pack) or w==8 and s.tribes_pack!="repair":return false
	if not rules.usable(id,w):return false
	var solution: Dictionary=game._shot_solution(id)
	if solution.blocked:return false
	if w not in [5,6,8,11] and game.projectiles.size()>=game.variant_combat.MAX_PROJECTILES:return false
	var d: Dictionary=game.armory.data(w).duplicate();var m: Dictionary=game.fighters[id].tribes_state
	var spent: float=minf(m.energy,float(d.get("energy",0)))
	m.energy=maxf(0,m.energy-spent)
	if rules.amount(id,w)>=0:s.tribes_ammo[w]-=1
	s.cooldown=d.cycle;s.invulnerable=0;s.shots+=1
	game._variant_shot_fx.rpc(id,w,false)
	var start: Vector3=solution.origin;var basis: Basis=game._weapon_transform(id).basis
	var direction: Vector3=-basis.z
	if w in [5,6,8,11]:
		beam(id,w,start,direction,spent);return true
	if w==2:direction=(direction+basis.x*randf_range(-.005,.005)+basis.y*randf_range(-.005,.005)).normalized()
	var velocity: Vector3=direction*d.speed+game.fighters[id].velocity*d.inherit
	if w in [9,10]:velocity+=Vector3.UP*3
	game.variant_combat.launch(id,w,start,direction,{"launch_velocity":velocity})
	return true
func fractional(owner_id: int,target: int,raw: float,channel: String) -> int:
	var key: String="%s:%d:%d"%[channel,owner_id,target]
	var value: float=fractions.get(key,0.0)+raw*A.UNIT
	var amount:=floori(value);fractions[key]=value-amount;return amount
func beam(id: int,w: int,start: Vector3,direction: Vector3,spent: float):
	var d: Dictionary=game.armory.data(w)
	var hit: Dictionary=game._trace(start,start+direction*d.range,id,game._shot_rewind(id))
	if w==6:
		var nearest: float=d.range
		for target in game.players:
			if target==id or game.players[target].dead or game.players[target].spectator or game.match_mode.same_team(id,target) and not game.match_mode.friendly_fire:continue
			var pos: Vector3=game.fighters[target].position+Vector3.UP*game.fighters[target].torso_height()
			var offset: Vector3=pos-start
			if offset.length()>nearest or direction.dot(offset.normalized())<cos(deg_to_rad(35)):continue
			var trace: Dictionary=game._trace(start,pos,id)
			if trace.id==target:hit=trace;nearest=offset.length()
		if hit.id!=0 and (not game.match_mode.same_team(id,hit.id) or game.match_mode.friendly_fire):
			var target_energy: Dictionary=game.fighters[hit.id].tribes_state
			target_energy.energy=maxf(0,target_energy.energy-6.0)
			var damage: int=fractional(id,hit.id,.006,"elf")
			if damage>0:game._damage(hit.id,id,damage,d.name,false,hit.position,direction)
	elif w==8:
		if hit.has("scout"):
			rules.vehicles.repair(hit.scout,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array(),-1,id);return
		if hit.has("beacon"):
			rules.targeting.repair(hit.beacon,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array(),-1,id);return
		if hit.has("fixed_turret"):
			var pads=rules.stations()
			if pads:pads.defences.repair(hit.fixed_turret,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array(),-1,id);return
		if hit.has("base_asset"):
			var pads=rules.stations()
			if pads:pads.assets.repair(hit.base_asset,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array(),-1,id);return
		if hit.has("deployable"):
			rules.deployables.repair(hit.deployable,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array(),-1,id);return
		if hit.has("generator"):
			var pads=rules.stations()
			if pads:
				if hit.has("power_source"):pads.restore_source(hit.power_source,id,.01*A.UNIT)
				else:pads.restore(hit.generator,id,.01*A.UNIT)
			game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array([hit.get("surface_normal",Vector3.ZERO)]),-1,id);return
		var target: int=hit.id if hit.id!=0 and game.match_mode.same_team(id,hit.id) else id
		var amount: int=fractional(id,target,.005 if target==id else .01,"repair")
		game.players[target].hp=mini(rules.definition(target).hp,game.players[target].hp+amount)
		hit.position=game.fighters[target].position+Vector3.UP
	elif w==11:rules.targeting.designate(id,hit)
	elif w==5:
		var damage:=roundi(spent*.007*A.UNIT*(1.3 if hit.get("headshot",false) else 1.0))
		game._damage_map_hit(hit,id,damage,"Laser")
		if hit.id!=0:game._damage(hit.id,id,damage,d.name,false,hit.position,direction)
		if hit.has("building"):game.match_mode.fortress.damage_building(hit.building,id,damage)
	game._impacts.rpc(start,PackedVector3Array([hit.position]),w,PackedVector3Array([hit.get("surface_normal",Vector3.ZERO)]),-1,id)
func tick_projectile(id: int,delta: float,movement_start: Dictionary,targets):
	if not game.projectiles.has(id):return
	var p: Dictionary=game.projectiles[id];var d: Dictionary=p.definition;var w: int=p.weapon
	p.life-=delta
	if w==10:p.life=30.0
	if p.life<=0:
		if w in [0,1,2]:game._projectile_end.rpc(id,p.position,w)
		else:explode(id,p.position)
		return
	var age: float=float(d.fuse)-p.life
	if p.stuck:
		if w in [4,7] and age>=float(d.arm):explode(id,p.position);return
		if w==10:
			p["mine_wait"]=float(p.get("mine_wait",0.0))+delta
			if p.mine_wait<3:return
			for target in game.players:
				if game.players[target].dead or game.players[target].spectator:continue
				var point: Vector3=game.fighters[target].position+Vector3.UP*.5
				if point.distance_to(p.position)<2.5 and game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.position+Vector3.UP*.1,point,1)).is_empty():explode(id,p.position);return
		return
	if d.get("fixed_turret","")=="missile":
		var target: int=d.get("seek",0)
		var pads=rules.stations()
		if pads and pads.defences.warm(target) and game.players.has(target) and not game.players[target].dead:
			var point: Vector3=game.fighters[target].position+Vector3.UP*game.fighters[target].torso_height()
			if rules.deployables.ray(p.position,point).is_empty():p.velocity=p.velocity.normalized().slerp((point-p.position).normalized(),minf(1,72.0/9.0*delta)).normalized()*72
	if w==3 and not d.has("fixed_turret"):
		# Accelerate along the launch axis while preserving inherited sideways speed.
		var axis: Vector3=p.direction
		var along: float=p.velocity.dot(axis)
		if along<80:p.velocity+=axis*minf(5*delta,80-along)
	var gravity: float=d.get("gravity",0)
	var end: Vector3=p.position+p.velocity*delta-Vector3.UP*gravity*delta*delta*.5
	p.velocity.y-=gravity*delta
	var owner_grace: int=p.owner if w not in [4,7,9,10] or age<.25 else 0
	var hit: Dictionary=game._trace(p.position,end,owner_grace,0,d.radius,{} if p.fresh else movement_start,targets.candidates(p.position,end,d.radius))
	p.fresh=false
	if not hit.hit:p.position=end;return
	preload("res://deathmatch/effects/surface_marks.gd").contact(game,hit,p.position,end,d)
	if w in [0,2]:
		var friendly_map: bool=d.has("turret_team") and (rules.vehicles.rows.get(hit.get("scout",-1),{}).get("team",-1)==d.turret_team or hit.get("generator",-1)==d.turret_team or rules.deployables.rows.get(hit.get("deployable",-1),{}).get("team",-1)==d.turret_team or rules.targeting.beacons.get(hit.get("beacon",-1),{}).get("team",-1)==d.turret_team)
		if d.has("turret_team") and hit.has("fixed_turret"):
			var pads=rules.stations()
			friendly_map=friendly_map or pads and pads.defences.rows[hit.fixed_turret].team==d.turret_team
		if d.has("turret_team") and hit.has("base_asset"):
			var pads=rules.stations()
			friendly_map=friendly_map or pads and pads.assets.rows[hit.base_asset].team==d.turret_team
		if not friendly_map or rules.mode.friendly_fire:game._damage_map_hit(hit,p.owner,d.damage,"Turret" if d.has("turret_team") else A.TYPES[w])
		if hit.id!=0 and (not d.has("turret_team") or game.players[hit.id].team!=d.turret_team or rules.mode.friendly_fire):game._damage(hit.id,p.owner,d.damage,d.name,false,hit.position,p.velocity.normalized())
		if hit.has("building"):game.match_mode.fortress.damage_building(hit.building,p.owner,d.damage)
		game._projectile_end.rpc(id,hit.position,w);return
	if w in [1,3] or w in [4,7] and age>=float(d.arm):explode(id,hit.position);return
	var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.position,end+p.velocity.normalized()*(d.radius+.2),1))
	var normal: Vector3=ray.get("normal",-p.velocity.normalized())
	p.position=hit.position+normal*(d.radius+.015);p.velocity=p.velocity.bounce(normal)*d.bounce
	if p.velocity.length()<1.0:p.stuck=true;p.velocity=Vector3.ZERO
	game._variant_bounce_fx.rpc(p.position,w)
func explode(id: int,where: Vector3):
	if not game.projectiles.has(id):return
	var p: Dictionary=game.projectiles[id];var d: Dictionary=p.definition
	# Remove first, so chain reactions cannot recurse into an exploding mine.
	game._projectile_end.rpc(id,where,p.weapon)
	blast(where,p.owner,d)
func blast(where: Vector3,owner_id: int,d: Dictionary):
	if not game.multiplayer.is_server() or not rules.enabled():return
	preload("res://deathmatch/effects/surface_marks.gd").blast(game,where,d)
	game.match_mode.fortress.blast(where,owner_id,d.splash,d.blast_radius)
	var pads=rules.stations()
	if pads:pads.blast(where,owner_id,d.splash,d.blast_radius,int(d.get("turret_team",-1)),"Mortar" if "MORTAR" in d.name else "Grenade" if "GRENADE" in d.name else "")
	rules.vehicles.blast(where,owner_id,d.splash,d.blast_radius,int(d.get("turret_team",-1)))
	rules.deployables.blast(where,owner_id,d.splash,d.blast_radius,int(d.get("turret_team",-1)))
	rules.targeting.blast(where,owner_id,d.splash,d.blast_radius,int(d.get("turret_team",-1)))
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime:runtime.triggers.blast(where,owner_id,d.splash,d.blast_radius)
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.team==d.get("turret_team",-2) and not rules.mode.friendly_fire:continue
		if s.dead or s.spectator or s.invulnerable>game.clock or id!=owner_id and game.match_mode.same_team(id,owner_id) and not game.match_mode.friendly_fire:continue
		var target: Vector3=game.fighters[id].position+Vector3.UP*minf(.8,game.fighters[id].collision_height*.5)
		var distance: float=maxf(0,where.distance_to(target)-.3)
		if distance>=d.blast_radius:continue
		var direction: Vector3=(target-where).normalized()
		if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where+direction*.06,target,1)).is_empty():continue
		var falloff: float=1-distance/d.blast_radius
		game.fighters[id].apply_blast(direction*(float(d.get("kick",0))/9.0)*falloff)
		game._damage(id,owner_id,maxi(1,roundi(d.splash*falloff)),d.name,false,target,direction,true)
	for other in (mines.keys() if indexed_mines else game.projectiles.keys()):
		# A previous chain explosion may already have removed another candidate.
		if not game.projectiles.has(other):continue
		var mine: Dictionary=game.projectiles[other]
		if mine.weapon!=10 or mine.position.distance_to(where)>=d.blast_radius:continue
		var direction: Vector3=(mine.position-where).normalized()
		if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where+direction*.06,mine.position,1)).is_empty():continue
		var fraction: float=1-mine.position.distance_to(where)/d.blast_radius
		damage_mine(other,float(d.damage)*fraction*(.25 if d.name=="LAND MINE" else 1.0))
func trace_mines(start: Vector3,end: Vector3,hit: Dictionary,radius: float) -> Dictionary:
	var reach: float=start.distance_to(hit.position)
	for id in (mines if indexed_mines else game.projectiles):
		if not game.projectiles.has(id):continue
		var p: Dictionary=game.projectiles[id]
		if p.weapon!=10 or not p.stuck:continue
		var near:=Geometry3D.get_closest_point_to_segment(p.position,start,end)
		if near.distance_to(p.position)<=.16+radius and start.distance_to(near)<reach:
			reach=start.distance_to(near);hit={"id":0,"position":near,"hit":true,"mine":id}
	return hit
func damage_mine(id: int,points: float):
	if not game.projectiles.has(id):return
	var p: Dictionary=game.projectiles[id]
	p["mine_damage"]=p.get("mine_damage",0.0)+points
	if p.mine_damage>.5/1.5*A.UNIT:explode(id,p.position)
func physical_request(id: int,kind: String,pose: Dictionary,velocity: Vector3) -> bool:
	if kind=="cancel":held.erase(id);return true
	var pads=rules.stations()
	if rules.vehicles.weapon_operator(id) or pads and pads.defences.operated(id)>=0:held.erase(id);return false
	if pose.is_empty() or not velocity.is_finite() or velocity.length()>30 or not game.players[id].get("physical",false) or game.players[id].get("input_blocked",false):held.erase(id);return false
	var s: Dictionary=game.players[id];var w: int=s.get("tribes_grenade",9)
	var hand: String="right" if pose.left_handed else "left"
	var body:=Transform3D(Basis(Vector3.UP,s.yaw),game.fighters[id].position)
	var point: Vector3=body*pose[hand].origin
	var chest: Vector3=body.origin+Vector3.UP*game.fighters[id].torso_height()
	if kind.begins_with("hold_"):
		var equipment=preload("res://deathmatch/tribes/equipment.gd")
		var item: String=kind.trim_prefix("hold_")
		if held.has(id):return false
		if item=="ammo":
			if not equipment.Hip.recovery_contains(pose,pose[hand].origin) or rules.amount(id,s.weapon)<=0:return false
		elif equipment.target(pose,s,rules.mode.st.carried(id)>=0)!=item:return false
		if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(chest,point,1)).is_empty():return false
		held[id]={"item":item,"until":game.clock+10,"left":pose.left_handed,"used":false};return true
	if kind=="transfer":
		var item: Dictionary=held.get(id,{})
		if item.is_empty() or item.until<game.clock or item.left!=pose.left_handed or item.get("used",false) or item.get("item","") not in ["pack","ammo"]:return false
		held.erase(id)
		var solution:=preload("res://deathmatch/vr/weapon_clearance.gd").solve(game.get_world_3d().direct_space_state,chest,point,point,.12)
		if solution.blocked:return false
		return rules.recovery.drop(id,item.item,solution.origin,body.basis*velocity*2+game.fighters[id].velocity)
	if kind=="activate":
		var item: Dictionary=held.get(id,{})
		if item.is_empty() or item.until<game.clock or item.left!=pose.left_handed or item.get("used",false):return false
		if item.get("item","")=="kit":
			item.used=rules.kit(id);return item.used
		if item.get("item","")=="pack":
			if rules.deployables.Data.is_pack(s.tribes_pack):
				var frame: Transform3D=body*preload("res://deathmatch/tribes/equipment.gd").hand_frame(pose)
				var deployed: bool=rules.deployables.deploy(id,frame.origin,-frame.basis.z)
				item.used=deployed
				rules.deployment_notice(id,deployed);return deployed
			if s.tribes_pack in ["repair","shield","jammer"]:item.used=true;rules.pack_action(id);return true
		return false
	if kind=="arm":
		if rules.amount(id,w)<=0 or held.has(id) or game.clock<s.get("tribes_throw_at",0.0):return false
		var relative: Vector3=pose.head.affine_inverse()*pose[hand].origin
		if relative.y<-.30 or relative.z<-.20 or absf(relative.x)<.12:return false
		held[id]={"w":w,"until":game.clock+10,"left":pose.left_handed};return true
	if kind=="throw":
		var item: Dictionary=held.get(id,{});held.erase(id)
		if item.is_empty() or item.until<game.clock or item.left!=pose.left_handed:return false
		var solution:=preload("res://deathmatch/vr/weapon_clearance.gd").solve(game.get_world_3d().direct_space_state,chest,point,point,.12)
		if solution.blocked:return false
		if item.get("item","")=="flag":return rules.mode.st.drop(id,solution.origin,body.basis*(velocity*2).limit_length(20))
		if not item.has("w") or rules.amount(id,item.w)<=0 or game.projectiles.size()>=256:return false
		var throw_velocity: Vector3=body.basis*preload("res://deathmatch/vr/throw_ballistics.gd").guided(pose,velocity)+game.fighters[id].velocity
		s.tribes_ammo[item.w]-=1;s.tribes_throw_at=game.clock+.5
		game.variant_combat.launch(id,item.w,solution.origin,throw_velocity.normalized() if throw_velocity.length()>.01 else Vector3.DOWN,{"launch_velocity":throw_velocity})
		return true
	return false
