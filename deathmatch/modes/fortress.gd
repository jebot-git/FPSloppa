extends Node
## Independent, server-authoritative TF adaptation; shares FPSloppa movement and combat.
const CLASSES={
	"scout":{"name":"SCOUT","hp":75,"armor":25,"speed":1.25,"owned":[0,2,3],"weapon":3,"ammo":[100,25,0,0],"action":"Sprint for 3 seconds · 10s cooldown"},
	"sniper":{"name":"SNIPER","hp":90,"armor":25,"speed":.9,"owned":[0,2,9],"weapon":9,"ammo":[80,0,0,0],"action":"Focus for 4 seconds: slow movement, stronger rail · 12s cooldown"},
	"soldier":{"name":"SOLDIER","hp":150,"armor":100,"speed":.85,"owned":[0,3,6],"weapon":6,"ammo":[0,25,12,0],"action":"Launch explosive grenade · 8s cooldown"},
	"demoman":{"name":"DEMOMAN","hp":120,"armor":75,"speed":.95,"owned":[0,3,6],"weapon":6,"ammo":[0,25,15,0],"action":"Throw a pipe grenade; use again to detonate · 8s cooldown"},
	"medic":{"name":"MEDIC","hp":110,"armor":50,"speed":1.1,"owned":[0,2,7],"weapon":7,"ammo":[80,0,0,100],"action":"Aim at a teammate: heal 35 HP and extinguish · 2s cooldown"},
	"heavy":{"name":"HEAVY","hp":200,"armor":150,"speed":.65,"owned":[0,3,5],"weapon":5,"ammo":[200,25,0,0],"action":"Brace for 4 seconds: 35% less damage, slower movement · 12s cooldown"},
	"pyro":{"name":"PYRO","hp":125,"armor":75,"speed":1.0,"owned":[0,3,7],"weapon":7,"ammo":[0,25,0,150],"action":"Launch a napalm grenade · 10s cooldown"},
	"spy":{"name":"SPY","hp":90,"armor":25,"speed":1.05,"owned":[0,2,4],"weapon":4,"ammo":[80,25,0,0],"action":"Disguise as nearest enemy; gunfire, damaging melee, damage and flags reveal"},
	"engineer":{"name":"ENGINEER","hp":100,"armor":75,"speed":1.0,"owned":[0,2,3],"weapon":3,"ammo":[100,30,0,120],"action":"Aim at friendly building to repair; otherwise build selected tool"}
}
const CLASS_COLORS={"scout":Color("f7dc6f"),"sniper":Color("a4df80"),"soldier":Color("ff9c54"),"demoman":Color("d3a0ed"),"medic":Color("65edcb"),"heavy":Color("c7cdd4"),"pyro":Color("ff6c9b"),"spy":Color("a9b9ff"),"engineer":Color("80d5f4")}
var mode_ref: WeakRef
var mode:
	get:return mode_ref.get_ref()
var game:
	get:return mode.game
var buildings: Dictionary={}
var charges: Dictionary={}
var burns: Dictionary={}
var cooldowns: Dictionary={}
var effects: Dictionary={}
var spy_invisibility:=false
var invisible_spy: Dictionary={}
var spy_cell_credit: Dictionary={}
var next_id:=1
var tick_credit:=0.0
var visuals: Dictionary={}
var request_times: Dictionary={}
var physical=preload("res://deathmatch/modes/vr_interactions.gd").new()
func _init() -> void:
	physical.name="PhysicalInteractions";add_child(physical)
func setup(value) -> void:
	mode_ref=weakref(value);physical.setup(self)
func enabled() -> bool:return mode.kind=="tf"
func structures_enabled() -> bool:return not game.lobby.active() and (enabled() or mode.kind=="as")
func definition(id: int) -> Dictionary:
	return class_definition(game.players.get(id,{}).get("tf_class","soldier"))
func class_definition(role: String) -> Dictionary:
	var data: Dictionary=CLASSES.get(role,CLASSES.soldier)
	if role=="spy" and spy_invisibility:
		if invisible_spy.is_empty():
			invisible_spy=data.duplicate(true);invisible_spy.ammo[3]=50;invisible_spy.action="Toggle invisibility: 1 cell/second; regenerate cells while visible"
		return invisible_spy
	return data
func max_health(id: int) -> int:return definition(id).hp if enabled() else 100
func speed(id: int) -> float:
	if not enabled():return 1.0
	var scale: float=definition(id).speed
	var effect: Dictionary=effects.get(id,{})
	if effect.get("until",0.0)>game.clock:
		match effect.get("kind",""):
			"scout":scale*=1.3
			"sniper","heavy":scale*=.5
	return scale
func reset() -> void:
	physical.reset();spy_cell_credit.clear()
	buildings.clear();charges.clear();burns.clear();cooldowns.clear();effects.clear();request_times.clear();tick_credit=0.0
	for node in visuals.values():if is_instance_valid(node):node.queue_free()
	visuals.clear()
	for fighter in game.fighters.values():fighter.visible=true
func spawn(id: int) -> void:
	physical.departed(id);spy_cell_credit.erase(id)
	burns.erase(id);effects.erase(id);cooldowns[id]=game.clock+2
	if not enabled():return
	var s: Dictionary=game.players[id]
	var fallback: String=CLASSES.keys()[posmod(-id,CLASSES.size())] if id<0 else "soldier"
	s.tf_disguise={}
	s.tf_class=s.get("tf_next",s.get("tf_class",fallback));s.tf_next=s.tf_class
	var data:=definition(id)
	s.hp=data.hp;s.armor=data.armor;s.tier=2;s.owned=data.owned.duplicate();s.weapon=data.weapon;s.ammo=data.ammo.duplicate()
	# Class changes remove prior engineer assets; normal engineer deaths retain them.
	if s.tf_class!="engineer":remove_owned(id)
	charges.erase(id);s.tf_regen=0.0
func remove_owned(id: int) -> void:
	for key in buildings.keys():if buildings[key].owner==id:buildings.erase(key)
func departed(id: int) -> void:
	physical.departed(id);spy_cell_credit.erase(id)
	for other in game.players:
		if game.players[other].get("tf_disguise",{}).get("peer",0)==id:revealed(other)
	remove_owned(id);charges.erase(id);burns.erase(id);effects.erase(id);cooldowns.erase(id);request_times.erase(id)
func choose(class_id: String,tool: String="sentry") -> void:
	if multiplayer.is_server():select_class(multiplayer.get_unique_id(),class_id,tool)
	else:class_request.rpc_id(1,class_id,tool)
@rpc("any_peer","call_remote","reliable",0)
func class_request(class_id: String,tool: String) -> void:
	if multiplayer.is_server():select_class(multiplayer.get_remote_sender_id(),class_id,tool)
func select_class(id: int,class_id: String,tool: String="sentry") -> bool:
	if not multiplayer.is_server() or not enabled() or not game.active or not game.players.has(id) or game.players[id].spectator or not CLASSES.has(class_id) or not tool in ["sentry","dispenser"]:return false
	if game.clock<request_times.get(id,0.0):return false
	request_times[id]=game.clock+.25
	game.players[id].tf_next=class_id;game.players[id].tf_tool=tool
	return true
func weapon_data(id: int,weapon: int) -> Dictionary:
	var data: Dictionary=game.W.DATA[weapon]
	if not enabled():return data
	data=data.duplicate()
	var role: String=game.players.get(id,{}).get("tf_class","soldier")
	if weapon==9:
		data.damage=150 if effects.get(id,{}).get("until",0)>game.clock else 90
		data.cycle=1.5;data.ammo=0;data.cost=2
	if role=="pyro" and weapon==7:
		data.merge({"name":"FLAMETHROWER","damage":8,"dice":1,"cycle":.12,"range":8.0,"pellets":1,"spread":3.0,"vertical":3.0},true)
	if role=="medic" and weapon==7:data.cycle=.15
	return data
func revealed(id: int) -> void:
	if game.players.has(id):game.players[id].tf_disguise={}
	if effects.get(id,{}).get("kind","")=="spy":effects.erase(id)
func cloaked(id: int) -> bool:
	return enabled() and effects.get(id,{}).get("kind","")=="spy" and effects[id].until>game.clock
func carrying(id: int) -> bool:
	for flag in mode.flags:if flag.carrier==id:return true
	return false
func incoming_damage(id: int,amount: int,weapon: String,bypass: bool) -> int:
	if not enabled():return amount
	if game.players[id].get("tf_class","")=="spy":revealed(id)
	if bypass:return amount
	if effects.get(id,{}).get("kind","")=="heavy" and effects[id].until>game.clock:amount=roundi(amount*.65)
	if game.players[id].get("tf_class","")=="pyro" and weapon in ["FLAMETHROWER","BURN","NAPALM"]:amount=roundi(amount*.5)
	return maxi(1,amount)
func ignite(victim: int,attacker: int) -> void:
	if not enabled() or not game.players.has(victim) or game.players[victim].dead or game.players[victim].invulnerable>game.clock:return
	if mode.same_team(victim,attacker) and not mode.friendly_fire:return
	burns[victim]={"owner":attacker,"until":game.clock+3,"next":game.clock+.5}
func burning(id: int) -> bool:
	return enabled() and burns.has(id) and burns[id].until>game.clock and game.players.has(id) and not game.players[id].dead and not game.players[id].spectator
func action(id: int) -> bool:
	if game.lobby.active():return false
	if not enabled() or not multiplayer.is_server() or not game.active or game.intermission>0 or game.map_loading or not game.players.has(id):return false
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator:return false
	var role: String=s.get("tf_class","soldier")
	if role=="demoman" and charges.has(id) and charges[id].kind=="pipe":
		if game.clock<charges[id].armed:return false
		detonate(id);cooldowns[id]=game.clock+8;return true
	if game.clock<cooldowns.get(id,0):return false
	var used:=true
	match role:
		"spy":
			if carrying(id):return false
			if spy_invisibility:
				if cloaked(id):revealed(id)
				else:
					if s.ammo[3]<=0:return false
					s.tf_disguise={};s.ammo[3]-=1;spy_cell_credit[id]=0.0
					effects[id]={"kind":"spy","until":game.clock+s.ammo[3]+1.0}
			else:
				copy_disguise(id)
				if s.tf_disguise.is_empty():return false
			cooldowns[id]=game.clock+.5
		"scout","sniper","heavy":
			effects[id]={"kind":role,"until":game.clock+({"scout":3.0,"sniper":4.0,"heavy":4.0,"spy":6.0}[role])}
			cooldowns[id]=game.clock+({"scout":10.0,"sniper":12.0,"heavy":12.0,"spy":14.0}[role])
			game._ability_fx.rpc(role,game.fighters[id].position,game.fighters[id].position,s.team)
		"medic":
			var hit: Dictionary=game._trace(game._shot_origin(id),game._shot_origin(id)-game._weapon_transform(id).basis.z*6,id)
			var other: int=hit.id
			used=heal(id,other,game._shot_origin(id))
		"engineer":used=engineer(id)
		"demoman","soldier","pyro":
			if s.ammo[2]<1 and role!="pyro":return false
			if role=="pyro" and s.ammo[3]<20:return false
			var origin: Vector3=game._shot_origin(id)
			if game._weapon_blocked(id):return false
			# Swept, server-simulated projectile; never teleport a charge to a floor.
			var direction: Vector3=-game._weapon_transform(id).basis.z
			var pos:=origin+direction*.25
			if game.HitDetection.world_fraction(game.get_world_3d().direct_space_state,origin,pos,.12)<=1.0:return false
			used=throw_charge(id,pos,direction*14+Vector3.UP*3)
	if used:s.invulnerable=0
	return used
func can_act(id: int) -> bool:
	return multiplayer.is_server() and enabled() and game.active and not game.lobby.active() and game.intermission<=0 and not game.map_loading and game.players.has(id) and not game.players[id].dead and not game.players[id].spectator and not mode.special.blocked(id) and game.clock>=cooldowns.get(id,0)
func repair_building(id: int,key: int,origin: Vector3) -> bool:
	if not can_act(id) or game.players[id].tf_class!="engineer" or not buildings.has(key):return false
	var s: Dictionary=game.players[id];var b: Dictionary=buildings[key]
	if b.team!=s.team or b.hp>=150 or s.ammo[3]<10 or not mode.nearby(id,b.position,3.5):return false
	b.hp=mini(150,b.hp+40);s.ammo[3]-=10;cooldowns[id]=game.clock+1;s.invulnerable=0
	game._ability_fx.rpc("repair",origin,b.position+Vector3.UP*.7,s.team);return true
func heal(id: int,other: int,origin: Vector3) -> bool:
	if not can_act(id) or game.players[id].tf_class!="medic" or other==id or not game.players.has(other):return false
	var target: Dictionary=game.players[other]
	if not mode.same_team(id,other) or target.dead or target.spectator or not mode.nearby(id,game.fighters[other].position,6):return false
	if target.hp>=max_health(other) and not burns.has(other):return false
	target.hp=mini(max_health(other),target.hp+35);burns.erase(other);cooldowns[id]=game.clock+2;game.players[id].invulnerable=0
	game._ability_fx.rpc("heal",origin,game.fighters[other].position+Vector3.UP,game.players[id].team);return true
func throw_charge(id: int,pos: Vector3,velocity: Vector3) -> bool:
	if not can_act(id) or not pos.is_finite() or not velocity.is_finite():return false
	var s: Dictionary=game.players[id];var role: String=s.tf_class
	if not role in ["soldier","demoman","pyro"] or charges.has(id):return false
	var ammo:=3 if role=="pyro" else 2;var cost:=20 if role=="pyro" else 1
	if s.ammo[ammo]<cost:return false
	if game.HitDetection.world_fraction(game.get_world_3d().direct_space_state,pos,pos,.12)==0:return false
	charges[id]={"owner":id,"team":s.team,"position":pos,"velocity":velocity.limit_length(18),"kind":"pipe" if role=="demoman" else "napalm" if role=="pyro" else "grenade","armed":game.clock+.7,"until":game.clock+(30 if role=="demoman" else 1.2),"bounce_fx":0.0}
	s.ammo[ammo]-=cost;cooldowns[id]=game.clock+(10 if role=="pyro" else 8);s.invulnerable=0;return true
func engineer(id: int) -> bool:
	var s: Dictionary=game.players[id];var origin: Vector3=game._shot_origin(id)
	var end: Vector3=origin-game._weapon_transform(id).basis.z*3.5
	var repair: Dictionary=game._trace(origin,end,id)
	for key in buildings:
		if repair.get("building",0)!=key:continue
		return repair_building(id,key,origin)
	var tool: String=s.get("tf_tool","sentry")
	for b in buildings.values():if b.owner==id and b.kind==tool:return false
	if s.ammo[3]<60:return false
	# Ground placement must be visible, clear of players, objectives and other buildings.
	if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1)).is_empty():return false
	var floor: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end,end-Vector3.UP*4,1))
	if floor.is_empty() or floor.normal.y<.8:return false
	var pos: Vector3=floor.position+Vector3.UP*.02
	var shape:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.55;capsule.height=1.4;shape.shape=capsule;shape.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.75);shape.collision_mask=1
	if not game.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():return false
	for point in game.spawn_points+mode.bases:if point.distance_to(pos)<2.0:return false
	for other in game.fighters:if game.fighters[other].position.distance_to(pos)<1.3:return false
	for b in buildings.values():if b.position.distance_to(pos)<1.5:return false
	# Keep the mount clear even while a nearby pickup is waiting to respawn.
	for pickup in game.pickups:
		if pickup.kind=="weapon" and pickup.item==5 and pickup.position.distance_to(pos)<1.5:return false
	buildings[next_id]={"owner":id,"team":s.team,"position":pos,"kind":tool,"hp":150,"ready":game.clock+3,"next":game.clock+3,"expires":game.clock+120}
	next_id+=1;s.ammo[3]-=60;cooldowns[id]=game.clock+2;game._ability_fx.rpc("build",pos,pos,s.team);return true
func damage_building(key: int,attacker: int,amount: int) -> void:
	if not multiplayer.is_server() or not structures_enabled() or not buildings.has(key):return
	var b: Dictionary=buildings[key]
	if b.has("objective") and not mode.assault.can_damage_objective(attacker,int(b.objective)):return
	if game.players.has(attacker) and game.players[attacker].team==b.team and not mode.friendly_fire:return
	if amount>0 and b.hp>0:revealed(attacker)
	b.hp-=maxi(0,amount)
	if b.hp<=0:
		buildings.erase(key);game._ability_fx.rpc("explosion",b.position+Vector3.UP*.6,b.position,b.team)
		if b.has("objective"):mode.assault.destroyed(attacker,int(b.objective))
func trace(start: Vector3,end: Vector3,limit: float,radius: float=0.0) -> Dictionary:
	var result: Dictionary={}
	if not structures_enabled():return result
	for key in buildings:
		var pos: Vector3=buildings[key].position
		var fraction: float=game.HitDetection.capsule_fraction(start-pos,end-pos,.55+radius)
		if fraction<limit:limit=fraction;result={"key":key,"fraction":fraction}
	return result
func blast(pos: Vector3,owner: int,damage: int,radius: float) -> void:
	if not structures_enabled():return
	for key in buildings.keys():
		var target: Vector3=buildings[key].position+Vector3.UP*.6
		var distance:=pos.distance_to(target)
		if distance>=radius:continue
		if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.1,target,1)).is_empty():damage_building(key,owner,int(damage*(1-distance/radius)))
func detonate(id: int) -> void:
	if not charges.has(id):return
	var charge: Dictionary=charges[id];charges.erase(id)
	game._blast(charge.position,id,100,4.5)
	game._ability_fx.rpc("napalm" if charge.kind=="napalm" else "explosion",charge.position,charge.position,charge.team)
	if charge.kind=="napalm":
		for target in game.players:
			if not game.players[target].dead and mode.nearby(target,charge.position,4.5):ignite(target,id)
func tick_spy_cells(delta: float) -> void:
	if not spy_invisibility:return
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.dead or s.spectator or s.get("tf_class","")!="spy":continue
		var credit: float=spy_cell_credit.get(id,0.0)+delta
		var amount:=int(credit);spy_cell_credit[id]=credit-amount
		if amount==0:continue
		if cloaked(id):
			s.ammo[3]=maxi(0,s.ammo[3]-amount)
			if s.ammo[3]==0:revealed(id)
			else:effects[id].until=game.clock+s.ammo[3]+1.0
		else:s.ammo[3]=mini(50,s.ammo[3]+amount)

func tick(delta: float) -> void:
	if mode.kind=="as":
		if multiplayer.is_server():tick_sentries()
		return
	if not enabled() or not multiplayer.is_server():return
	for id in cooldowns.keys():if not game.players.has(id):departed(id)
	for id in effects.keys():
		if effects[id].until<=game.clock or not game.players.has(id) or game.players[id].dead or carrying(id):effects.erase(id)
	tick_spy_cells(delta)
	tick_charges(delta)
	for id in burns.keys():
		var burn: Dictionary=burns[id]
		if not game.players.has(id) or game.players[id].dead or burn.until<=game.clock:burns.erase(id);continue
		if game.clock>=burn.next:burn.next=game.clock+.5;game._damage(id,burn.owner,4,"BURN")
	tick_credit+=delta
	if tick_credit<.25:return
	var elapsed:=tick_credit;tick_credit=0
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.dead or s.spectator:continue
		if carrying(id):revealed(id)
		if s.get("tf_class","")=="medic" and s.hp<max_health(id):
			s.tf_regen=s.get("tf_regen",0.0)+elapsed*3
			if s.tf_regen>=1:var amount:=int(s.tf_regen);s.tf_regen-=amount;s.hp=mini(max_health(id),s.hp+amount)
		# Team resupply zones are class-safe; ordinary maps fall back to team spawns.
		var stations: Array=game.tf_resupply[s.team] if s.team in [0,1] else []
		if stations.is_empty() and s.team in [0,1]:stations=mode.spawns(s.team)
		for point in stations:
			if mode.nearby(id,point,1.8):resupply(id,elapsed);break
	tick_sentries()
func tick_sentries() -> void:
	for key in buildings.keys():
		var b: Dictionary=buildings[key]
		if b.has("objective"):continue
		if not b.get("map_owned",false) and (not game.players.has(b.owner) or game.players[b.owner].team!=b.team or game.clock>b.expires):buildings.erase(key);continue
		if game.clock<b.ready:continue
		if b.kind=="dispenser":
			if game.clock<b.next:continue
			b.next=game.clock+1.0
			for id in game.players:
				if game.players[id].team==b.team and not game.players[id].dead and not game.players[id].spectator and mode.nearby(id,b.position,3):resupply(id,.5)
		else:
			# Track between shots without running a target/occlusion scan every physics tick.
			if game.clock<b.get("scan_at",0.0):continue
			b.scan_at=game.clock+.1
			var origin: Vector3=b.position+Vector3.UP*1.1
			var nearest:=18.0;var victim:=0
			for id in game.players:
				var s: Dictionary=game.players[id]
				if s.dead or s.spectator or s.team==b.team or cloaked(id) or s.get("tf_disguise",{}).get("team",-1)==b.team or s.invulnerable>game.clock:continue
				var target: Vector3=game.fighters[id].position+Vector3.UP*minf(.9,game.fighters[id].collision_height*.5)
				var distance:=origin.distance_to(target)
				if distance<nearest and game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,target,1)).is_empty():nearest=distance;victim=id
			if victim!=0:
				var target: Vector3=game.fighters[victim].position+Vector3.UP*minf(.9,game.fighters[victim].collision_height*.5)
				b["aim"]=target
				if game.clock<b.next:continue
				b.next=game.clock+.5
				var direction: Vector3=(target-origin).normalized()
				var muzzle: Vector3=origin+direction*(-game.Art.muzzle(5).z*.7)
				game._damage(victim,b.owner,12,"SENTRY",false,target,direction);game._ability_fx.rpc("sentry_fire",muzzle,target,b.team)
func resupply(id: int,delta: float) -> void:
	var s: Dictionary=game.players[id];var data:=definition(id)
	if s.hp<data.hp:s.hp=mini(data.hp,s.hp+maxi(1,int(20*delta)))
	if s.armor<data.armor:s.armor=mini(data.armor,s.armor+maxi(1,int(15*delta)))
	for i in range(4):
		var maximum: int=maxi(data.ammo[i],120 if i==3 and s.tf_class=="engineer" else 0)
		if s.ammo[i]<maximum:s.ammo[i]=mini(maximum,s.ammo[i]+maxi(1,int([40,10,4,40][i]*delta)))
	burns.erase(id)
func snapshot() -> Dictionary:
	if game.lobby.active():return {}
	if mode.kind=="as":return {"buildings":buildings.duplicate(true)}
	if not enabled():return {}
	var people: Dictionary={}
	for id in game.players:
		var s: Dictionary=game.players[id]
		people[id]={"class":s.get("tf_class","soldier"),"next":s.get("tf_next","soldier"),"tool":s.get("tf_tool","sentry"),"disguise":s.get("tf_disguise",{}),"cooldown":maxf(0,cooldowns.get(id,0)-game.clock)}
	var state_effects:=effects.duplicate(true)
	for effect in state_effects.values():effect.until=maxf(0,effect.until-game.clock)
	var state_charges:=charges.duplicate(true)
	for charge in state_charges.values():
		charge.armed=maxf(0,charge.armed-game.clock);charge.until=maxf(0,charge.until-game.clock)
	var burning_players: Dictionary={}
	for id in burns:
		if burning(id):burning_players[id]=maxf(0,burns[id].until-game.clock)
	return {"spy_invisibility":spy_invisibility,"players":people,"buildings":buildings.duplicate(true),"charges":state_charges,"effects":state_effects,"burning":burning_players}
func receive(data: Dictionary) -> void:
	if game.lobby.active():reset();return
	spy_invisibility=bool(data.get("spy_invisibility",false))
	buildings=data.get("buildings",{});charges=data.get("charges",{});effects=data.get("effects",{})
	burns.clear()
	for id in data.get("burning",{}):
		burns[id]={"owner":0,"until":game.clock+clampf(float(data.burning[id]),0,3),"next":game.clock+.5}
	for effect in effects.values():effect.until+=game.clock
	for charge in charges.values():charge.armed+=game.clock;charge.until+=game.clock
	for id in data.get("players",{}):
		if not game.players.has(id):continue
		var row: Dictionary=data.players[id];var s: Dictionary=game.players[id]
		s.tf_class=row["class"];s.tf_next=row.next;s.tf_tool=row.tool;s.tf_disguise=row.get("disguise",{});cooldowns[id]=game.clock+row.cooldown
func status(id: int) -> String:
	if not enabled() or not game.players.has(id):return ""
	var s: Dictionary=game.players[id]
	var ability:=ability_state(id)
	return " · "+definition(id).name+" · USE "+ability.label+": "+("READY" if ability.ready else "%.1fs"%[ability.remaining])+ (" · NEXT: "+s.get("tf_next","soldier").to_upper() if s.get("tf_next","soldier")!=s.get("tf_class","soldier") else "")
func draw() -> void:
	if game.headless:return
	var mine: int=game.demos.selected_player if game.demos.playing else multiplayer.get_unique_id()
	for id in game.fighters:
		game.fighters[id].visible=true
		game.fighters[id].set_burning_visual(burning(id))
		var role: String=game.players.get(id,{}).get("tf_class","soldier")
		var friendly: bool=mode.same_team(id,mine) or id==mine
		var disguise: Dictionary=game.players[id].get("tf_disguise",{}) if enabled() else {}
		if not friendly and not disguise.is_empty():role=disguise.get("class","soldier")
		game.fighters[id].set_class_badge(CLASSES.get(role,CLASSES.soldier).name if enabled() else "",CLASS_COLORS.get(role,Color.WHITE))
		var label: Label3D=game.fighters[id].label
		if label:
			label.text=disguise.get("name",game.players[id].name) if not friendly and not disguise.is_empty() else game.players[id].name
			var team: int=disguise.get("team",game.players[id].team) if not friendly and not disguise.is_empty() else game.players[id].team
			if team in [0,1] and enabled():label.modulate=mode.COLORS[team].lightened(.4)
		game.fighters[id].set_cloak_visual(cloaked(id),friendly,mode.COLORS[maxi(0,game.players[id].team)],get_process_delta_time())
	var desired: Dictionary={}
	if structures_enabled():
		for key in buildings:desired["b"+str(key)]=buildings[key]
		for key in charges:desired["c"+str(key)]=charges[key]
	for key in visuals.keys():
		if not desired.has(key):visuals[key].queue_free();visuals.erase(key)
	for key in desired:
		var row: Dictionary=desired[key]
		if visuals.has(key):
			visuals[key].position=row.position
			aim_sentry(visuals[key],row)
			if row.has("objective"):visuals[key].get_node("ObjectiveHealth").text="SHOOT COMPRESSOR\n%d / %d"%[row.hp,row.max_hp]
			continue
		var node:=Node3D.new();game.add_child(node);node.position=row.position;visuals[key]=node
		var material=game.Art.material(mode.COLORS[row.team],.5,.1)
		var dark=game.Art.material(Color("343d43"),.7,0)
		if key.begins_with("b"):
			game.Art.box(node,Vector3(0,.3,0),Vector3(1,.6,.8),material)
			if row.kind=="compressor":
				for x in [-.25,.25]:
					var tank:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.21;cylinder.bottom_radius=.21;cylinder.height=1.0;tank.mesh=cylinder;tank.position=Vector3(x,.95,.05);tank.material_override=dark;node.add_child(tank)
				game.Art.box(node,Vector3(0,.8,-.25),Vector3(.65,.48,.12),game.Art.material(Color("ad4835"),.5))
				game.Art.box(node,Vector3(0,.85,-.32),Vector3(.42,.20,.02),game.Art.material(Color("f6b44b"),0,.6))
			elif row.kind=="sentry":
				game.Art.box(node,Vector3(0,.8,0),Vector3(.35,.65,.35),dark)
				var gun:=Node3D.new();node.add_child(gun);gun.name="SentryGun";gun.position=Vector3(0,1.1,0)
				var model: Node3D=game.Art.weapon(5);gun.add_child(model);model.scale*=.7
				# Center the actual barrel on the aiming pivot; the mesh origin is below it.
				model.position.y=-game.Art.muzzle(5).y*.7
				aim_sentry(node,row)
			else:
				game.Art.box(node,Vector3(0,.8,0),Vector3(.75,.6,.6),dark)
				game.Art.box(node,Vector3(0,.8,-.31),Vector3(.12,.4,.02),game.Art.material(Color.WHITE))
				game.Art.box(node,Vector3(0,.8,-.32),Vector3(.4,.12,.02),game.Art.material(Color.WHITE))
			var label:=Label3D.new();node.add_child(label);label.text=row.kind.to_upper();label.position.y=1.7;label.font_size=28;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			if row.has("objective"):label.name="ObjectiveHealth";label.text="SHOOT COMPRESSOR\n%d / %d"%[row.hp,row.max_hp];label.pixel_size=.004
		else:
			var ball:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.12;sphere.height=.24;sphere.radial_segments=8;sphere.rings=4;ball.mesh=sphere;ball.material_override=material;node.add_child(ball)
			game.Art.box(node,Vector3(0,.13,0),Vector3(.10,.08,.08),game.Art.material(Color("ffd267"),0,1))

func aim_sentry(node: Node3D,row: Dictionary) -> void:
	var gun:=node.get_node_or_null("SentryGun") as Node3D
	if not gun or not row.has("aim"):return
	var direction: Vector3=row.aim-gun.global_position
	if not direction.is_finite() or direction.length_squared()<.0001:return
	var up:=Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP))>.999 else Vector3.UP
	gun.look_at(row.aim,up)

func copy_disguise(id: int) -> void:
	var nearest:=INF;var selected:=0
	for other in game.players:
		if other==id or game.players[other].spectator or mode.same_team(id,other):continue
		var distance: float=game.fighters[id].position.distance_squared_to(game.fighters[other].position)
		if distance<nearest:nearest=distance;selected=other
	if selected==0:return
	var target: Dictionary=game.players[selected]
	game.players[id].tf_disguise={"peer":selected,"hash":game.avatars.choices.get(selected,{}).get("hash",""),"class":target.get("tf_class","soldier"),"team":target.team,"name":target.name}
func display_avatar(id: int,original: String) -> String:
	if not enabled() or not game.players.has(id):return original
	var disguise: Dictionary=game.players[id].get("tf_disguise",{})
	var hash: String=disguise.get("hash","")
	return hash if game.avatars.library.entries.has(hash) else original

func outgoing_damage(attacker: int,victim: int,amount: int,weapon: String) -> int:
	if not enabled() or weapon!="FIST" or not game.players.has(attacker) or game.players[attacker].get("tf_class","")!="spy" or attacker==victim:return amount
	var direction: Vector3=(game.fighters[attacker].position-game.fighters[victim].position).normalized()
	var facing: Vector3=game.W.direction(game.players[victim].yaw,0)
	return maxi(amount,120) if facing.dot(direction)<-.5 else amount

func can_fire(id: int,weapon: int) -> bool:
	if not game.players.has(id) or weapon<0 or weapon>=game.W.DATA.size():return false
	var data:=weapon_data(id,weapon)
	return data.ammo<0 or game.players[id].ammo[data.ammo]>=data.cost

func tick_charges(delta: float) -> void:
	var space=game.get_world_3d().direct_space_state
	for id in charges.keys():
		if not game.players.has(id):charges.erase(id);continue
		if game.clock>=charges[id].until:detonate(id);continue
		var charge: Dictionary=charges[id]
		var steps:=clampi(int(ceil(delta*60)),1,16);var dt:=clampf(delta,0,.25)/steps
		for step in steps:
			if not charges.has(id):break
			var start: Vector3=charge.position;var velocity: Vector3=charge.get("velocity",Vector3.ZERO)
			velocity.y-=20*dt;var end:=start+velocity*dt
			var fraction: float=game.HitDetection.world_fraction(space,start,end,.12)
			var victim:=0
			for other in game.players:
				if other==id or game.players[other].dead or game.players[other].spectator:continue
				var pos: Vector3=game.fighters[other].position
				var at: float=game.HitDetection.capsule_fraction(start-pos,end-pos,.42,game.fighters[other].damage_top())
				if at<=1.0 and at<fraction:fraction=at;victim=other
			if fraction<=1.0:
				charge.position=start.lerp(end,maxf(0,fraction-.005))
				if victim!=0 and charge.kind!="pipe":detonate(id);break
				var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end+velocity.normalized()*.16,1))
				var normal: Vector3=hit.normal if not hit.is_empty() else -velocity.normalized()
				charge.position+=normal*.015;velocity=velocity.bounce(normal)*.55
				if normal.y>.7 and velocity.length()<1:velocity=Vector3.ZERO
				if game.clock>=charge.get("bounce_fx",0):
					game._ability_fx.rpc("bounce",charge.position,charge.position,charge.team);charge.bounce_fx=game.clock+.2
			else:charge.position=end
			charge.velocity=velocity

func ability_state(id: int) -> Dictionary:
	if not enabled() or not game.players.has(id):return {}
	var role: String=game.players.get(id,{}).get("tf_class","soldier")
	var labels={"scout":"SPRINT","sniper":"FOCUS","soldier":"GRENADE","demoman":"PIPE GRENADE","medic":"HEAL","heavy":"BRACE","pyro":"NAPALM","spy":"UNCLOAK" if spy_invisibility and cloaked(id) else "CLOAK" if spy_invisibility else "DISGUISE","engineer":"BUILD / REPAIR"}
	var total: float={"scout":10.0,"sniper":12.0,"soldier":8.0,"demoman":8.0,"medic":2.0,"heavy":12.0,"pyro":10.0,"spy":.5,"engineer":2.0}[role]
	var remaining:=maxf(0,cooldowns.get(id,0)-game.clock)
	var active_left:=maxf(0,effects.get(id,{}).get("until",0)-game.clock)
	if role=="demoman" and charges.has(id):
		remaining=maxf(0,charges[id].armed-game.clock);total=.7;labels[role]="DETONATE PIPE"
	return {"label":labels[role],"remaining":remaining,"fraction":1-clampf(remaining/total,0,1),"active":active_left,"ready":remaining<=0}
