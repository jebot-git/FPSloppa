extends RefCounted
## Server-authoritative experimental firing, using existing traces, damage and RPCs.
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var game
var charging: Dictionary={}
var discs: Dictionary={}
var predictions: Array=[]
var charge_view: Dictionary={}
const MAX_PROJECTILES:=256
func setup(arena: Node) -> void:game=arena
func reset() -> void:charging.clear();discs.clear();predictions.clear();charge_view.clear()
func tick_input(id: int,delta: float) -> void:
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or game.lobby.active() or game.intermission>0:
		charging.erase(id);return
	var alt: bool=s.get("alt_fire",false)
	var primary: bool=s.fire
	var weapon: int=s.weapon
	var d: Dictionary=game.match_mode.fortress.weapon_data(id,weapon)
	if game.armory.kind=="ut99" and weapon==9:
		s["weapon_zoom"]=alt
		if primary:fire(id,false)
		return
	var held_charge: bool=game.armory.kind=="ut99" and (weapon==6 or (weapon==0 and not alt) or (weapon==1 and alt))
	if charging.has(id):
		var charge: Dictionary=charging[id]
		if s.get("input_blocked",false) or charge.weapon!=weapon:charging.erase(id);return
		var held: bool=alt if charge.alt else primary
		if held and game.clock-s.last_input<=.35:
			charge.time=minf(charge.time+delta,charge.maximum)
			# Keep the hammer armed for a deliberate release/jump, even at full charge.
			# Nearby opponents can trip the charged piston; world contact cannot.
			if weapon==0 and game.armory.kind=="ut99":
				if charge.time<charge.maximum*2.0/3.0 or not hammer_contact(id,d):return
			if charge.time<charge.maximum and weapon!=0:return
		charging.erase(id)
		# A timed-out connection or menu pause cancels an armed charge.
		if game.clock-s.last_input>.35:return
		fire(id,charge.alt,charge.time)
		return
	if held_charge and (primary or alt) and s.cooldown<=0:
		charging[id]={"weapon":weapon,"alt":alt,"time":delta,"maximum":float(d.get("charge_max",2.0))};return
	if (primary or alt) and s.cooldown<=0:fire(id,alt)
func fire(id: int,alternate: bool=false,charge: float=0.0) -> bool:
	if not game.multiplayer.is_server() or not game.players.has(id):return false
	var s: Dictionary=game.players[id];var w: int=s.weapon
	if s.vr_device and game.armory.vr_physical_only(w):return false
	if s.get("input_blocked",false) or not game.armory.valid(w) or s.dead or s.spectator or s.cooldown>0 or game.intermission>0 or game.lobby.active():return false
	if game.match_mode.special.blocked(id) or game.match_mode.fortress.walkers.mounted(id):return false
	var d: Dictionary=game.match_mode.fortress.weapon_data(id,w).duplicate()
	if alternate and game.armory.kind=="ut99":d.merge(d.get("alt",{}),true)
	if d.get("zoom",false):return false
	if w==11 and alternate:return translocate(id)
	var count:=1;var scale:=1.0
	if game.armory.kind=="ut99":
		if w==6:count=clampi(1+int(charge/.5),1,6)
		if w==1 and alternate:count=clampi(1+int(charge/.25),1,8);scale=float(count)
		if w==0 and not alternate:d.damage=roundi(60+90*clampf(charge/1.5,0,1))
	if game.armory.kind=="quake" and w==3 and s.ammo[1]==1:d=game.armory.data(2).duplicate()
	if d.ammo>=0:
		if s.ammo[d.ammo]<d.cost:return false
		count=mini(count,int(s.ammo[d.ammo]/maxi(1,d.cost)))
		if w==1 and alternate:scale=float(count)
	var solution: Dictionary=game._shot_solution(id)
	if solution.blocked:return false
	var kind: String=d.get("kind","hitscan")
	if not kind in ["hitscan","sniper","beam","shock_beam","hammer"] and game.projectiles.size()+count*int(d.pellets)>MAX_PROJECTILES:return false
	if d.ammo>=0:s.ammo[d.ammo]-=d.cost*count
	s.cooldown=d.cycle;s.invulnerable=0;s.shots+=1
	if d.ammo>=0:game.match_mode.fortress.revealed(id)
	game._variant_shot_fx.rpc(id,w,alternate)
	var start: Vector3=solution.origin;var forward: Vector3=-game._weapon_transform(id).basis.z
	if game.armory.kind=="quake" and w==8 and game.fighters[id].in_water:
		var cells: int=1+s.ammo[3];s.ammo[3]=0
		blast(start,id,cells*35,20.0,d.name,0,false)
		return true
	if kind in ["hitscan","sniper","beam","shock_beam","hammer"]:
		if kind=="shock_beam" and shock_combo(id,start,start+forward*d.range):return true
		for pellet in int(d.pellets):
			var basis: Basis=game._weapon_transform(id).basis
			var accuracy: float=game.fighters[id].accuracy_scale()
			var direction: Vector3=(forward+basis.x*randf_range(-1,1)*tan(deg_to_rad(d.spread*accuracy))+basis.y*randf_range(-1,1)*tan(deg_to_rad(d.vertical*accuracy))).normalized()
			var reach: float=d.get("surface_range",d.range) if kind=="hammer" else d.range
			var hit: Dictionary=game._trace(start,start+direction*reach,id,game._shot_rewind(id),float(d.get("beam_radius",0.0)))
			var melee_reaches: bool=kind!="hammer" or start.distance_to(hit.position)<=float(d.range)
			var damage: int=d.damage
			if kind=="sniper" and hit.id!=0 and not hit.get("vehicle",false) and headshot(hit.id,hit.position):damage=int(d.get("head_damage",100))
			if hit.id!=0 and melee_reaches:
				game._damage(hit.id,id,damage,d.name,false,hit.position,direction,false,hit.get("vehicle",false) and d.range>3 and d.name!="FLAMETHROWER")
				if d.name=="FLAMETHROWER":game.match_mode.fortress.ignite(hit.id,id)
			if hit.has("building") and melee_reaches:game.match_mode.fortress.damage_building(hit.building,id,damage)
			if kind=="hammer" and hit.hit and hit.id==0 and not hit.has("building"):
				hammer_surface(id,d,alternate,charge,start,hit.position,direction)
			if d.name=="FLAMETHROWER":game._ability_fx.rpc("flame",start,hit.position,s.team)
			else:game._impacts.rpc(start,PackedVector3Array([hit.position]),w)
		return true
	for shot in (1 if kind=="bio" else count):
		for pellet in int(d.pellets):
			var dir:=forward
			if count>1 and kind!="bio":dir=dir.rotated(Vector3.UP,deg_to_rad((shot-(count-1)*.5)*3.0))
			if d.pellets>1:dir=(dir+Vector3(randf_range(-.13,.13),randf_range(-.10,.10),randf_range(-.13,.13))).normalized()
			launch(id,w,start,dir,{"alternate":alternate,"scale":scale})
	return true
func hammer_contact(id: int,d: Dictionary) -> bool:
	var solution: Dictionary=game._shot_solution(id)
	if solution.blocked:return false
	var direction: Vector3=-game._weapon_transform(id).basis.z
	var hit: Dictionary=game._trace(solution.origin,solution.origin+direction*minf(.8,float(d.range)),id,game._shot_rewind(id))
	return hit.id!=0 and not hit.get("vehicle",false)
func hammer_surface(id: int,d: Dictionary,alternate: bool,charge: float,start: Vector3,point: Vector3,direction: Vector3) -> void:
	# UT99 uses a fixed primary surface damage cost and charge-scaled recoil.
	# Speeds are adapted to FPSloppa's metre scale and shared movement limits.
	var scale:=clampf(charge/float(d.charge_max),0.0,1.0)
	var impulse: Vector3=-direction*lerpf(8.0,12.0,scale)
	var damage:=36
	if alternate:
		scale=clampf(start.distance_to(point)/float(d.surface_range),0.0,1.0)
		impulse=-direction*7.0*scale;damage=maxi(1,int(24.0*scale))
	var actor=game.fighters[id]
	if actor.is_supported() and actor.velocity.y<=0:
		impulse.y=maxf(impulse.y,impulse.length()*.4)
	actor.apply_blast(impulse)
	game._damage(id,id,damage,d.name,false,point,-direction,true)
func launch(owner_id: int,weapon: int,position: Vector3,direction: Vector3,extra: Dictionary={}) -> int:
	if game.projectiles.size()>=MAX_PROJECTILES:return -1
	game.projectile_id+=1
	game._projectile_spawn.rpc(game.projectile_id,owner_id,weapon,position,direction,atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1,1)),extra)
	if weapon==11:
		if discs.has(owner_id) and game.projectiles.has(discs[owner_id]):game._projectile_end.rpc(discs[owner_id],position,11)
		discs[owner_id]=game.projectile_id
	return game.projectile_id
func definition(owner_id: int,weapon: int,extra: Dictionary) -> Dictionary:
	var d: Dictionary=game.match_mode.fortress.weapon_data(owner_id,weapon).duplicate()
	if extra.get("alternate",false):d.merge(d.get("alt",{}),true)
	if extra.get("fragment",false):d=game.armory.data(4).duplicate();d.pellets=1;d.fuse=.65
	var scale: float=clampf(float(extra.get("scale",1)),1,8)
	if d.get("kind","")=="bio":d.damage*=scale;d.splash*=scale;d.blast_radius=minf(4,1.8+scale*.2);d.radius*=sqrt(scale)
	return d
func tick_projectile(id: int,delta: float,movement_start: Dictionary,targets) -> void:
	if not game.projectiles.has(id):return
	var p: Dictionary=game.projectiles[id];var d: Dictionary=p.definition
	p.life-=delta
	if p.life<=0:explode(id,p.position);return
	if p.get("stuck",false):
		if d.kind=="bio":
			for target in game.players:
				if game.players[target].dead or game.players[target].spectator:continue
				if game.fighters[target].position.distance_to(p.position)<.8:explode(id,p.position);return
		return
	if d.get("guided",false) and game.players.has(p.owner) and not game.players[p.owner].dead:
		var desired: Vector3=-game._weapon_transform(p.owner).basis.z
		p.velocity=p.velocity.lerp(desired*d.speed,minf(delta*2.5,1.0)).normalized()*d.speed
	var steps:=1;var dt:=delta # One continuous relative-motion sweep; gravity uses elapsed physics time.
	for step in steps:
		var gravity: float=float(d.get("gravity",0))
		var end: Vector3=p.position+p.velocity*dt-Vector3.UP*gravity*dt*dt*.5
		p.velocity.y-=gravity*dt
		var hit: Dictionary=game._trace(p.position,end,p.owner,0.0,d.radius,{} if p.fresh else movement_start,targets.candidates(p.position,end,d.radius))
		p.fresh=false
		if hit.hit:
			if hit.id!=0 or hit.has("building"):
				var damage: int=int(d.damage)+randi_range(0,int(d.get("direct_random",0)))
				if hit.id!=0 and not hit.get("vehicle",false) and d.has("head_damage") and headshot(hit.id,hit.position):damage=d.head_damage
				if float(d.get("splash",0))==0 or (game.armory.kind=="quake" and d.kind=="rocket"):
					if hit.id!=0:game._damage(hit.id,p.owner,damage,d.name,false,hit.position,p.velocity.normalized(),false,hit.get("vehicle",false))
					if hit.has("building") and float(d.get("splash",0))==0:game.match_mode.fortress.damage_building(hit.building,p.owner,damage)
				explode(id,hit.position,hit.id if game.armory.kind=="quake" and d.kind=="rocket" else 0,hit.id if hit.get("vehicle",false) else 0);return
			var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.position,end+p.velocity.normalized()*(d.radius+.2),1))
			var normal: Vector3=ray.get("normal",-p.velocity.normalized())
			p.position=hit.position+normal*(d.radius+.015)
			if d.kind in ["bio","translocator"]:
				p.stuck=true;p.velocity=Vector3.ZERO;return
			if float(d.get("bounce",0))>0:
				p.velocity=p.velocity.bounce(normal)*d.bounce
				p.bounces=int(p.get("bounces",0))+1
				if p.bounces>12:game._projectile_end.rpc(id,p.position,p.weapon);return
				game._variant_bounce_fx.rpc(p.position,p.weapon)
				if p.velocity.length()<.3:p.stuck=true
				break
			explode(id,hit.position);return
		p.position=end
	if p.velocity.length_squared()>.001:p.direction=p.velocity.normalized()
func headshot(id: int,position: Vector3) -> bool:
	var actor=game.fighters.get(id)
	return actor!=null and position.y-actor.position.y>=actor.collision_height-.42
func explode(id: int,where: Vector3,ignore: int=0,hull_impact: int=0) -> void:
	if not game.projectiles.has(id):return
	var p: Dictionary=game.projectiles[id];var d: Dictionary=p.definition
	if float(d.get("splash",0))>0:blast(where,p.owner,int(d.splash),float(d.blast_radius),d.name,ignore,game.armory.kind=="quake",hull_impact)
	if d.kind=="flak_shell":
		for i in 6:launch(p.owner,4,where+Vector3.UP*.15,Vector3(randf_range(-1,1),randf_range(.1,1),randf_range(-1,1)).normalized(),{"fragment":true})
	game._projectile_end.rpc(id,where,p.weapon)
func blast(where: Vector3,owner_id: int,damage: int,radius: float,title: String,ignore: int=0,quake_falloff: bool=false,hull_impact: int=0) -> void:
	if not game.multiplayer.is_server() or game.intermission>0 or game.lobby.active():return
	game.match_mode.fortress.blast(where,owner_id,damage,radius)
	for id in game.players:
		var s: Dictionary=game.players[id]
		if id==ignore or s.dead or s.spectator or s.invulnerable>game.clock:continue
		if not game.match_mode.fortress.walkers.accepts_explosion(id,where,hull_impact):continue
		if id!=owner_id and game.match_mode.same_team(id,owner_id) and not game.match_mode.friendly_fire:continue
		var target: Vector3=game.fighters[id].position+Vector3.UP*minf(.8,game.fighters[id].collision_height*.5)
		target=game.match_mode.fortress.walkers.blast_target(id,where,target)
		var distance:=maxf(0,where.distance_to(target)-.3)
		if distance>=radius:continue
		var direction: Vector3=(target-where).normalized()
		if not game.match_mode.fortress.walkers.blast_reaches(id,game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where+direction*.06,target,1))):continue
		var points:=maxf(0,damage-distance*16) if quake_falloff else damage*(1-distance/radius)
		game.fighters[id].apply_blast(direction*minf(24,points*.15))
		game._damage(id,owner_id,maxi(1,roundi(points*(.5 if id==owner_id else 1))),title,false,target,direction,true,game.match_mode.fortress.walkers.mounted(id))
func shock_combo(owner_id: int,start: Vector3,end: Vector3) -> bool:
	var stop: Dictionary=game._trace(start,end,owner_id,game._shot_rewind(owner_id))
	var nearest:=start.distance_to(stop.position);var selected:=-1
	for id in game.projectiles:
		var p: Dictionary=game.projectiles[id]
		if p.get("definition",{}).get("kind","")!="shock_orb":continue
		var closest:=Geometry3D.get_closest_point_to_segment(p.position,start,stop.position)
		var distance:=start.distance_to(closest)
		if closest.distance_to(p.position)<=.30 and distance<nearest:nearest=distance;selected=id
	if selected<0:return false
	var p: Dictionary=game.projectiles[selected]
	game._impacts.rpc(start,PackedVector3Array([p.position]),3)
	blast(p.position,owner_id,165,5.0,"SHOCK COMBO")
	game._variant_combo_fx.rpc(p.position)
	game._projectile_end.rpc(selected,p.position,3)
	return true
func translocate(id: int) -> bool:
	if game.match_mode.kind=="as" or not discs.has(id) or not game.projectiles.has(discs[id]):return false
	var p: Dictionary=game.projectiles[discs[id]]
	var actor=game.fighters[id];var destination: Vector3=p.position+Vector3.UP*.08
	var shape:=CapsuleShape3D.new();shape.height=actor.collision_height;shape.radius=.30
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=destination+Vector3.UP*(shape.height*.5);query.collision_mask=1
	if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty():return false
	game.match_mode.drop(id);actor.position=destination;actor.velocity=Vector3.ZERO;actor.reset_view();game.players[id].serial+=1;game.players[id].cooldown=.5
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime:runtime.telefrag(id)
	game._teleport_fx.rpc(destination);game._projectile_end.rpc(discs[id],destination,11);discs.erase(id)
	return true
func cancel_player(id: int) -> void:
	charging.erase(id)
	if discs.has(id):
		var disc: int=discs[id]
		if game.projectiles.has(disc):game._projectile_end.rpc(disc,game.projectiles[disc].position,11)
		discs.erase(id)
func predict(id: int,command: Dictionary) -> void:
	if game.headless or game.multiplayer.is_server() or not game.players.has(id):return
	var s: Dictionary=game.players[id];var w: int=s.weapon;var alt: bool=command.get("alt_fire",false)
	if game.armory.vr_physical_only(w) and (s.vr_device or command.has("xr")):return
	if not command.fire and not alt:return
	if command.get("input_blocked",false) or command.weapon!=w or s.dead or s.spectator or game.visual_cooldown>0 or game.intermission>0 or game.lobby.active() or game.match_mode.special.blocked(id):return
	# Charged reports occur on authoritative release, not on the initial press.
	if game.armory.kind=="ut99" and (w==6 or w==0 and not alt or w==1 and alt or w in [9,11] and alt):return
	var d: Dictionary=game.match_mode.fortress.weapon_data(id,w).duplicate()
	if alt:d.merge(d.get("alt",{}),true)
	var ammo: int=int(s.ammo[d.ammo]) if d.ammo>=0 else 999
	predictions=predictions.filter(func(p):return game.clock-p.time<.6)
	for p in predictions:
		if p.ammo==d.ammo:ammo-=p.cost
	if ammo<d.cost or game._weapon_blocked(id):return
	predictions.append({"weapon":w,"alt":alt,"time":game.clock,"ammo":d.ammo,"cost":d.cost})
	game._play_variant_shot_fx(id,w,alt)
func consume_prediction(id: int,weapon: int,alternate: bool) -> bool:
	if id!=game.multiplayer.get_unique_id() or game.multiplayer.is_server() or game.demos.playing:return false
	predictions=predictions.filter(func(p):return game.clock-p.time<.6)
	for i in predictions.size():
		if predictions[i].weapon==weapon and predictions[i].alt==alternate:predictions.remove_at(i);return true
	return false

func charge_snapshot() -> Dictionary:
	var result: Dictionary={}
	for id in charging:result[id]=clampi(roundi(charging[id].time/charging[id].maximum*100),0,100)
	return result
func charge_label(id: int) -> String:
	var state: Dictionary=charge_snapshot() if game.multiplayer.is_server() else charge_view
	if not state.get(id) is int:return ""
	return "CHARGE %d%% · RELEASE TO FIRE · "%clampi(state[id],0,100)
