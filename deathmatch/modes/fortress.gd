extends Node
## Independent, server-authoritative TF adaptation; shares FPSloppa movement and combat.
const CLASSES={
	"scout":{"name":"SCOUT","hp":75,"armor":25,"speed":1.25,"owned":[0,2,3],"weapon":3,"ammo":[100,25,0,0],"action":"Sprint for 3 seconds · 10s cooldown"},
	"sniper":{"name":"SNIPER","hp":90,"armor":25,"speed":.9,"owned":[0,2,9],"weapon":9,"ammo":[80,0,0,0],"action":"Focus for 4 seconds: slow movement, stronger rail · 12s cooldown"},
	"soldier":{"name":"SOLDIER","hp":150,"armor":100,"speed":.85,"owned":[0,3,6],"weapon":6,"ammo":[0,25,12,0],"action":"Launch explosive grenade · 8s cooldown"},
	"demoman":{"name":"DEMOMAN","hp":120,"armor":75,"speed":.95,"owned":[0,3,6],"weapon":6,"ammo":[0,25,15,0],"action":"Place a pipe charge; use again to detonate · 8s cooldown"},
	"medic":{"name":"MEDIC","hp":110,"armor":50,"speed":1.1,"owned":[0,2,7],"weapon":7,"ammo":[80,0,0,100],"action":"Aim at a teammate: heal 35 HP and extinguish · 2s cooldown"},
	"heavy":{"name":"HEAVY","hp":200,"armor":150,"speed":.65,"owned":[0,3,5],"weapon":5,"ammo":[200,25,0,0],"action":"Brace for 4 seconds: 35% less damage, slower movement · 12s cooldown"},
	"pyro":{"name":"PYRO","hp":125,"armor":75,"speed":1.0,"owned":[0,3,7],"weapon":7,"ammo":[0,25,0,150],"action":"Launch a napalm grenade · 10s cooldown"},
	"spy":{"name":"SPY","hp":90,"armor":25,"speed":1.05,"owned":[0,2,4],"weapon":4,"ammo":[80,25,0,0],"action":"Cloak for 6 seconds; damage, attacks and flags reveal · 14s cooldown"},
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
var next_id:=1
var tick_credit:=0.0
var visuals: Dictionary={}
var request_times: Dictionary={}
func setup(value) -> void:mode_ref=weakref(value)
func enabled() -> bool:return mode.kind=="tf"
func definition(id: int) -> Dictionary:
	return CLASSES.get(game.players.get(id,{}).get("tf_class","soldier"),CLASSES.soldier)
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
	buildings.clear();charges.clear();burns.clear();cooldowns.clear();effects.clear();request_times.clear();tick_credit=0.0
	for node in visuals.values():if is_instance_valid(node):node.queue_free()
	visuals.clear()
	for fighter in game.fighters.values():fighter.visible=true
func spawn(id: int) -> void:
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
	var role: String=game.players[id].get("tf_class","soldier")
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
		"scout","sniper","heavy","spy":
			if role=="spy" and carrying(id):return false
			if role=="spy":copy_disguise(id)
			effects[id]={"kind":role,"until":game.clock+({"scout":3.0,"sniper":4.0,"heavy":4.0,"spy":6.0}[role])}
			cooldowns[id]=game.clock+({"scout":10.0,"sniper":12.0,"heavy":12.0,"spy":14.0}[role])
		"medic":
			var hit: Dictionary=game._trace(game._shot_origin(id),game._shot_origin(id)-game._weapon_transform(id).basis.z*6,id)
			var other: int=hit.id
			if other==0 or not mode.same_team(id,other) or game.players[other].dead:return false
			if game.players[other].hp>=max_health(other) and not burns.has(other):return false
			game.players[other].hp=mini(max_health(other),game.players[other].hp+35);burns.erase(other);cooldowns[id]=game.clock+2
			game._impacts.rpc(game._shot_origin(id),PackedVector3Array([hit.position]),7)
		"engineer":used=engineer(id)
		"demoman","soldier","pyro":
			if s.ammo[2]<1 and role!="pyro":return false
			if role=="pyro" and s.ammo[3]<20:return false
			var origin: Vector3=game._shot_origin(id)
			if game._weapon_blocked(id):return false
			var end: Vector3=origin-game._weapon_transform(id).basis.z*(4 if role=="demoman" else 14)
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1))
			var pos: Vector3=hit.position+hit.normal*.15 if not hit.is_empty() else end
			var floor: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos,pos-Vector3.UP*8,1))
			if floor.is_empty():return false
			pos=floor.position+Vector3.UP*.12
			charges[id]={"owner":id,"team":s.team,"position":pos,"kind":"pipe" if role=="demoman" else "napalm" if role=="pyro" else "grenade","armed":game.clock+.7,"until":game.clock+(30 if role=="demoman" else 1.2)}
			s.ammo[3 if role=="pyro" else 2]-=20 if role=="pyro" else 1
			cooldowns[id]=game.clock+(10 if role=="pyro" else 8)
	if used:s.invulnerable=0
	return used
func engineer(id: int) -> bool:
	var s: Dictionary=game.players[id];var origin: Vector3=game._shot_origin(id)
	var end: Vector3=origin-game._weapon_transform(id).basis.z*3.5
	var repair: Dictionary=game._trace(origin,end,id)
	for key in buildings:
		if repair.get("building",0)!=key:continue
		var b: Dictionary=buildings[key]
		if b.team!=s.team or b.hp>=150 or b.position.distance_to(game.fighters[id].position)>3.5:continue
		if not mode.nearby(id,b.position,3.5):continue
		if s.ammo[3]<10:return false
		b.hp=mini(150,b.hp+40);s.ammo[3]-=10;cooldowns[id]=game.clock+1;return true
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
	buildings[next_id]={"owner":id,"team":s.team,"position":pos,"kind":tool,"hp":150,"ready":game.clock+3,"next":game.clock+3,"expires":game.clock+120}
	next_id+=1;s.ammo[3]-=60;cooldowns[id]=game.clock+2;return true
func damage_building(key: int,attacker: int,amount: int) -> void:
	if not multiplayer.is_server() or not enabled() or not buildings.has(key):return
	var b: Dictionary=buildings[key]
	if game.players.has(attacker) and game.players[attacker].team==b.team and not mode.friendly_fire:return
	b.hp-=maxi(0,amount)
	if b.hp<=0:buildings.erase(key)
func trace(start: Vector3,end: Vector3,limit: float,radius: float=0.0) -> Dictionary:
	var result: Dictionary={}
	if not enabled():return result
	for key in buildings:
		var pos: Vector3=buildings[key].position
		var fraction: float=game.HitDetection.capsule_fraction(start-pos,end-pos,.55+radius)
		if fraction<limit:limit=fraction;result={"key":key,"fraction":fraction}
	return result
func blast(pos: Vector3,owner: int,damage: int,radius: float) -> void:
	if not enabled():return
	for key in buildings.keys():
		var target: Vector3=buildings[key].position+Vector3.UP*.6
		var distance:=pos.distance_to(target)
		if distance>=radius:continue
		if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.1,target,1)).is_empty():damage_building(key,owner,int(damage*(1-distance/radius)))
func detonate(id: int) -> void:
	if not charges.has(id):return
	var charge: Dictionary=charges[id];charges.erase(id)
	game._blast(charge.position,id,100,4.5)
	game._impacts.rpc(charge.position+Vector3.UP*.1,PackedVector3Array([charge.position+Vector3.UP*2]),6)
	if charge.kind=="napalm":
		for target in game.players:
			if not game.players[target].dead and mode.nearby(target,charge.position,4.5):ignite(target,id)
func tick(delta: float) -> void:
	if not enabled() or not multiplayer.is_server():return
	for id in cooldowns.keys():if not game.players.has(id):departed(id)
	for id in effects.keys():
		if effects[id].until<=game.clock or not game.players.has(id) or game.players[id].dead or carrying(id):effects.erase(id)
	for id in charges.keys():
		if not game.players.has(id):charges.erase(id)
		elif game.clock>=charges[id].until:detonate(id)
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
	for key in buildings.keys():
		var b: Dictionary=buildings[key]
		if not game.players.has(b.owner) or game.players[b.owner].team!=b.team or game.clock>b.expires:buildings.erase(key);continue
		if game.clock<b.ready or game.clock<b.next:continue
		b.next=game.clock+(.5 if b.kind=="sentry" else 1.0)
		if b.kind=="dispenser":
			for id in game.players:
				if game.players[id].team==b.team and not game.players[id].dead and not game.players[id].spectator and mode.nearby(id,b.position,3):resupply(id,.5)
		else:
			var origin: Vector3=b.position+Vector3.UP*1.1
			var nearest:=18.0;var victim:=0
			for id in game.players:
				var s: Dictionary=game.players[id]
				if s.dead or s.spectator or s.team==b.team or cloaked(id) or s.get("tf_disguise",{}).get("team",-1)==b.team or s.invulnerable>game.clock:continue
				var target: Vector3=game.fighters[id].position+Vector3.UP*.9
				var distance:=origin.distance_to(target)
				if distance<nearest and game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,target,1)).is_empty():nearest=distance;victim=id
			if victim!=0:
				var target: Vector3=game.fighters[victim].position+Vector3.UP*.9
				game._damage(victim,b.owner,12,"SENTRY",false,target,(target-origin).normalized());game._impacts.rpc(origin,PackedVector3Array([target]),5)
func resupply(id: int,delta: float) -> void:
	var s: Dictionary=game.players[id];var data:=definition(id)
	if s.hp<data.hp:s.hp=mini(data.hp,s.hp+maxi(1,int(20*delta)))
	if s.armor<data.armor:s.armor=mini(data.armor,s.armor+maxi(1,int(15*delta)))
	for i in range(4):
		var maximum: int=maxi(data.ammo[i],120 if i==3 and s.tf_class=="engineer" else 0)
		if s.ammo[i]<maximum:s.ammo[i]=mini(maximum,s.ammo[i]+maxi(1,int([40,10,4,40][i]*delta)))
	burns.erase(id)
func snapshot() -> Dictionary:
	if not enabled():return {}
	var people: Dictionary={}
	for id in game.players:
		var s: Dictionary=game.players[id]
		people[id]={"class":s.get("tf_class","soldier"),"next":s.get("tf_next","soldier"),"tool":s.get("tf_tool","sentry"),"disguise":s.get("tf_disguise",{}),"cooldown":maxf(0,cooldowns.get(id,0)-game.clock)}
	var state_effects:=effects.duplicate(true)
	for effect in state_effects.values():effect.until=maxf(0,effect.until-game.clock)
	return {"players":people,"buildings":buildings.duplicate(true),"charges":charges.duplicate(true),"effects":state_effects}
func receive(data: Dictionary) -> void:
	buildings=data.get("buildings",{});charges=data.get("charges",{});effects=data.get("effects",{})
	for effect in effects.values():effect.until+=game.clock
	for id in data.get("players",{}):
		if not game.players.has(id):continue
		var row: Dictionary=data.players[id];var s: Dictionary=game.players[id]
		s.tf_class=row["class"];s.tf_next=row.next;s.tf_tool=row.tool;s.tf_disguise=row.get("disguise",{});cooldowns[id]=game.clock+row.cooldown
func status(id: int) -> String:
	if not enabled() or not game.players.has(id):return ""
	var s: Dictionary=game.players[id]
	return " · "+definition(id).name+" · USE: "+("READY" if cooldowns.get(id,0)<=game.clock else "%.0fs"%[cooldowns[id]-game.clock])+ (" · NEXT: "+s.get("tf_next","soldier").to_upper() if s.get("tf_next","soldier")!=s.get("tf_class","soldier") else "")
func draw() -> void:
	if game.headless:return
	var mine: int=multiplayer.get_unique_id()
	for id in game.fighters:
		game.fighters[id].visible=true
		var role: String=game.players[id].get("tf_class","soldier")
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
	if enabled():
		for key in buildings:desired["b"+str(key)]=buildings[key]
		for key in charges:desired["c"+str(key)]=charges[key]
	for key in visuals.keys():
		if not desired.has(key):visuals[key].queue_free();visuals.erase(key)
	for key in desired:
		var row: Dictionary=desired[key]
		if visuals.has(key):continue
		var node:=Node3D.new();game.add_child(node);node.position=row.position;visuals[key]=node
		var material=game.Art.material(mode.COLORS[row.team],.5,.1)
		var dark=game.Art.material(Color("343d43"),.7,0)
		if key.begins_with("b"):
			game.Art.box(node,Vector3(0,.3,0),Vector3(1,.6,.8),material)
			if row.kind=="sentry":
				game.Art.box(node,Vector3(0,.8,0),Vector3(.35,.65,.35),dark)
				var gun: Node3D=game.Art.weapon(5);node.add_child(gun);gun.position=Vector3(0,1.1,0);gun.scale*=.7
			else:
				game.Art.box(node,Vector3(0,.8,0),Vector3(.75,.6,.6),dark)
				game.Art.box(node,Vector3(0,.8,-.31),Vector3(.12,.4,.02),game.Art.material(Color.WHITE))
				game.Art.box(node,Vector3(0,.8,-.32),Vector3(.4,.12,.02),game.Art.material(Color.WHITE))
			var label:=Label3D.new();node.add_child(label);label.text=row.kind.to_upper();label.position.y=1.7;label.font_size=28;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		else:game.Art.box(node,Vector3(0,.12,0),Vector3(.3,.24,.3),material)

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
