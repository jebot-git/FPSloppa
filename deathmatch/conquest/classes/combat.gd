extends "res://deathmatch/experimental/combat.gd"
const Attribution=preload("res://deathmatch/server/attribution.gd")
var active_projectile:=-1
var salvos:Dictionary={}
var charges:Dictionary={}
var bursts:Dictionary={}
var burst_held:Dictionary={}
var vehicle_lock=preload("res://deathmatch/conquest/classes/vehicle_lock.gd").new()
var magazines=preload("res://deathmatch/conquest/classes/magazines.gd").new()
func setup(arena) -> void:super.setup(arena);magazines.setup(arena)
func tick_input(id:int,delta:float) -> void:
	var token:=Attribution.begin("player.combat_input")
	_tick_input(id,delta)
	Attribution.end(token)
func _tick_input(id:int,delta:float) -> void:
	if game.battery_tanks.mounted(id):return
	var s:Dictionary=game.players[id]
	if s.weapon!=5:charges.erase(id)
	if s.weapon!=0:bursts.erase(id);burst_held.erase(id)
	if not game.classes.alive(id) or game.intermission>0 or game.lobby.active():salvos.erase(id);charges.erase(id);bursts.erase(id);burst_held.erase(id);return
	if salvos.has(id) and salvos[id].at<=game.clock:
		if s.weapon!=5 or s.serial!=salvos[id].life:salvos.erase(id)
		else:
			launch_blast(id);salvos[id].left-=1;salvos[id].at=game.clock+game.armory.data(5).salvo_interval
			if salvos[id].left<=0:salvos.erase(id)
	var grenade_scope:=Attribution.begin("player.grenade_input")
	game.grenades.sample_player(id)
	Attribution.end(grenade_scope)
	if game.grenades.selected(id)>=0:charges.erase(id);return
	if s.fire or s.get("alt_fire",false):game.classes.weapon_used(id)
	if s.weapon in [6,7,8]:
		if s.fire and not s.get("input_blocked",false) and game.clock-s.last_input<=.35:
			if s.weapon==6:game.deploy_class_box(id)
			elif s.weapon==8:game.designate(id)
		return
	var reload_scope:=Attribution.begin("player.magazine_reload")
	var ready:bool=magazines.tick(id)
	Attribution.end(reload_scope)
	if not ready:charges.erase(id);return
	if s.weapon==5:
		var valid:bool=s.fire and s.weapon in s.owned and game.clock-s.last_input<=.35 and s.cooldown<=0 and s.ammo[2]>=3 and magazines.loaded(id)>=3 and not s.get("input_blocked",false) and not s.get("reload",false) and not game._shot_solution(id).blocked and game.projectiles.size()<=MAX_PROJECTILES-3
		if not valid:charges.erase(id);return
		if not charges.has(id):
			charges[id]={"at":game.clock+game.armory.data(5).charge_time,"life":s.serial};game.classes.weapon_used(id)
		elif charges[id].life!=s.serial:charges.erase(id)
		elif game.clock>=charges[id].at:
			charges.erase(id);s.ammo[2]-=3;magazines.consume(id,3);s.cooldown=game.armory.data(5).cycle;s.invulnerable=0;s.shots+=1;launch_blast(id)
			salvos[id]={"left":2,"at":game.clock+game.armory.data(5).salvo_interval,"life":s.serial}
		return
	if s.weapon==0:
		if not s.fire:burst_held.erase(id)
		if bursts.has(id):
			if bursts[id].life!=s.serial or bursts[id].at<game.clock-.35 or s.get("input_blocked",false) or game.clock-s.last_input>.35:bursts.erase(id);return
			if game.clock>=bursts[id].at:
				s.cooldown=0.0
				if fire(id):magazines.consume(id)
				bursts[id].left-=1;bursts[id].at=game.clock+.065
				if bursts[id].left<=0:bursts.erase(id);s.cooldown=.23
		elif s.fire and not burst_held.has(id) and s.cooldown<=0:
			if fire(id):
				magazines.consume(id);bursts[id]={"left":2,"at":game.clock+.065,"life":s.serial};burst_held[id]=true
		return
	bursts.erase(id);burst_held.erase(id)
	if s.fire:
		if fire(id):magazines.consume(id)
func fire(id:int,alternate:bool=false,_charge:float=0.0) -> bool:
	if not game.multiplayer.is_server() or not game.players.has(id) or not game.classes.alive(id):return false
	var s:Dictionary=game.players[id];var w:int=s.weapon;var d:Dictionary=game.armory.data(w)
	if w not in s.owned or w in [5,6,7,8] or alternate or s.cooldown>0 or game.intermission>0 or game.lobby.active() or s.get("input_blocked",false) or game.clock-s.last_input>.35:return false
	if d.ammo<0 or s.ammo[d.ammo]<d.cost or magazines.loaded(id)<d.cost or magazines.state(id).get("cycling",-1)==w:return false
	var lock:Dictionary=vehicle_lock.locks.get(id,{})
	if w==11 and (not lock.get("ready",false) or lock.get("life",-1)!=s.serial):return false
	var solution:Dictionary=game._shot_solution(id)
	if solution.blocked or (d.kind not in ["hitscan","sniper"] and game.projectiles.size()>=MAX_PROJECTILES):return false
	var basis:Basis=game._weapon_transform(id).basis
	var accuracy:float=game.fighters[id].accuracy_scale()
	var direction:Vector3=(-basis.z+basis.x*randf_range(-1,1)*tan(deg_to_rad(d.spread*accuracy))+basis.y*randf_range(-1,1)*tan(deg_to_rad(d.vertical*accuracy))).normalized()
	s.ammo[d.ammo]-=d.cost;s.cooldown=d.cycle;s.invulnerable=0;s.shots+=1;game.classes.weapon_used(id)
	game._variant_shot_fx.rpc(id,w,false)
	if d.kind in ["hitscan","sniper"]:
		var hit:Dictionary=game._trace(solution.origin,solution.origin+direction*d.range,id,game._shot_rewind(id))
		var damage:int=int(d.get("head_damage",d.damage)) if hit.get("headshot",false) and not hit.get("vehicle",false) else int(d.damage)
		if d.get("cq_beam",false):
			var shield:Dictionary=game.healing_field.intercept(id,solution.origin,hit.position,float(d.damage),true)
			if shield.damage<=0:
				game._cq_beam_impacts.rpc(solution.origin,PackedVector3Array([shield.position]),w,s.team);return true
			damage=roundi(damage*shield.damage/float(d.damage))
		game._damage_map_hit(hit,id,damage)
		if hit.id!=0:game._damage(hit.id,id,damage,d.name,false,hit.position,direction,false,hit.get("vehicle",false),false,hit.get("headshot",false))
		if w==10:game._cq_beam_impacts.rpc(solution.origin,PackedVector3Array([hit.position]),w,s.team)
		else:game._impacts.rpc(solution.origin,PackedVector3Array([hit.position]),w)
	else:
		var extra:Dictionary={"vehicle_target":lock.get("target",""),"guided_team":s.team} if w==11 else {}
		launch(id,w,solution.origin,direction,extra)
	return true
func launch_blast(id:int) -> void:
	var solution:Dictionary=game._shot_solution(id)
	if solution.blocked:return
	var direction:Vector3=-game._weapon_transform(id).basis.z
	launch(id,5,solution.origin,direction,{"guided_team":game.players[id].team})
	game._variant_shot_fx.rpc(id,5,false)
func launch(owner_id:int,weapon:int,position:Vector3,direction:Vector3,extra:Dictionary={}) -> int:
	if game.projectiles.size()>=MAX_PROJECTILES:return -1
	var tagged:=extra.duplicate();tagged["cq_team"]=extra.get("cq_team",game.players.get(owner_id,{}).get("team",0))
	game.projectile_id+=1
	game._projectile_spawn.rpc(game.projectile_id,owner_id,weapon,position,direction,atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1,1)),tagged)
	return game.projectile_id
func predict(id:int,command:Dictionary) -> void:
	if game.battery_tanks.mounted(id):return
	if game.headless or game.multiplayer.is_server() or not game.players.has(id) or command.weapon in [0,5,6,7,8,11] or game.classes.downed.has(id):return
	var state:Dictionary=game.players[id];var weapon:int=state.weapon
	if not command.fire or command.weapon!=weapon or command.get("input_blocked",false) or state.dead or state.spectator or game.visual_cooldown>0 or game.intermission>0 or game.lobby.active():return
	var data:Dictionary=game.armory.data(weapon)
	var ammo:int=state.ammo[data.ammo]
	predictions=predictions.filter(func(p):return game.clock-p.time<.6)
	for prediction in predictions:
		if prediction.ammo==data.ammo:ammo-=prediction.cost
	var magazine:Dictionary=magazines.states.get(id,{})
	if ammo<data.cost or magazine.get("reloading",-1)>=0 or magazine.get("clips",{}).get(weapon,data.magazine)<=0 or game._weapon_blocked(id):return
	predictions.append({"weapon":weapon,"alt":false,"time":game.clock,"ammo":data.ammo,"cost":data.cost})
	game._play_variant_shot_fx(id,weapon,false)
func reset() -> void:super.reset();salvos.clear();charges.clear();bursts.clear();burst_held.clear();vehicle_lock.locks.clear();magazines.states.clear()
func definition(owner_id:int,weapon:int,extra:Dictionary) -> Dictionary:
	var data:Dictionary=super.definition(owner_id,weapon,extra)
	if weapon in [0,1,4,5,11]:
		data.cq_effect="ordnance" if weapon in [5,11] else "energy"
		var team:int=extra.get("cq_team",game.players.get(owner_id,{}).get("team",0))
		data.color=Color("ff3c39") if team==0 else Color("3b8dff")
	if extra.get("turret_shot",false):data.name="TURRET ORDNANCE";data.guided=false;data.gravity=0.0;data.speed=40.0;data.fuse=4.0
	if extra.has("hover_shot"):data.name="%s TANK ORDNANCE"%str(extra.hover_shot).to_upper();data.inherit=.5
	if extra.get("battery_shot",false):data.merge({"name":"BATTERY MORTAR","kind":"tribes_mortar","speed":sqrt(5000.0*20),"gravity":20.0,"inherit":.5,"damage":152,"splash":152,"blast_radius":20.0,"radius":.3,"fuse":90.0,"arm":2.0,"bounce":.1,"guided":false,"quake_rocket":false,"direct_random":0,"cq_effect":"ordnance"},true)
	if weapon==3:data.cq_bullet=true
	return data

func cancel_player(id:int) -> void:
	super.cancel_player(id);salvos.erase(id);charges.erase(id);bursts.erase(id);burst_held.erase(id);vehicle_lock.locks.erase(id)
func explode(id:int,where:Vector3,ignore:int=0,hull_impact:int=0) -> void:
	if game.projectiles.has(id):
		var p:Dictionary=game.projectiles[id];var d:Dictionary=p.definition
		if d.get("splash",0)>0:
			for vehicle in game.get_tree().get_nodes_in_group("cq_repairable_vehicles"):
				if vehicle.hp<=0 or vehicle.get("service")==game.battery_tanks or vehicle.get_meta("cq_direct_projectile",-1)==id:continue
				var distance:float=where.distance_to(vehicle.global_position)
				if distance>d.blast_radius:continue
				var target:Dictionary={"position":vehicle.global_position,"node":vehicle}
				if vehicle_lock.clear_line(game,where,target):vehicle.damage(p.extra.get("cq_team",-1),maxi(0,int((d.splash-distance*12.8)*.5)))
	super.explode(id,where,ignore,hull_impact)

func tick_projectile(id:int,delta:float,movement_start:Dictionary,targets) -> void:
	active_projectile=id
	if game.projectiles.get(id,{}).get("extra",{}).get("battery_shot",false):tick_battery(id,delta,movement_start,targets)
	else:super.tick_projectile(id,delta,movement_start,targets)
	active_projectile=-1

func blast(where:Vector3,owner_id:int,damage:int,radius:float,title:String,ignore:int=0,quake_falloff:bool=false,hull_impact:int=0,ignite:bool=false) -> void:
	if game.multiplayer.is_server() and game.intermission<=0 and not game.lobby.active():game.turrets.blast(where,owner_id,damage,radius,quake_falloff)
	var p:Dictionary=game.projectiles.get(active_projectile,{})
	var kind:String="ordnance" if title=="AIRSTRIKE" or p.get("definition",{}).get("cq_effect","")=="ordnance" else "infantry"
	game.battery_tanks.blast(where,p.get("extra",{}).get("cq_team",game.players.get(owner_id,{}).get("team",-1)),damage,radius,kind,quake_falloff,active_projectile,owner_id)
	super.blast(where,owner_id,damage,radius,title,ignore,quake_falloff,hull_impact,ignite)

func tick_battery(id:int,delta:float,movement_start:Dictionary,targets) -> void:
	# Port of main ST combat's mortar arming/bounce path, on the shared projectile store.
	var p:Dictionary=game.projectiles[id];var d:Dictionary=p.definition;p.life-=delta
	var age:float=d.fuse-p.life
	if p.life<=0 or p.stuck and age>=d.arm:explode(id,p.position);return
	if p.stuck:return
	var end:Vector3=p.position+p.velocity*delta-Vector3.UP*d.gravity*delta*delta*.5;p.velocity.y-=d.gravity*delta
	var hit:Dictionary=game._trace(p.position,end,p.owner if age<.25 else 0,0,d.radius,{} if p.fresh else movement_start,targets.candidates(p.position,end,d.radius));p.fresh=false
	if not hit.hit:p.position=end;p.direction=p.velocity.normalized();return
	if age>=d.arm:explode(id,hit.position);return
	var ray:Dictionary=Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(p.position,end+p.velocity.normalized()*(d.radius+.2),1),"query.combat.tick_battery.ray")
	var normal:Vector3=ray.get("normal",-p.velocity.normalized());p.position=hit.position+normal*(d.radius+.015);p.velocity=p.velocity.bounce(normal)*d.bounce
	if p.velocity.length()<1.0:p.stuck=true;p.velocity=Vector3.ZERO
	game._variant_bounce_fx.rpc(p.position,p.weapon)
