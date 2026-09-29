extends RefCounted
const Data=preload("res://deathmatch/tribes/deployable_data.gd")
const Model=preload("res://deathmatch/tribes/deployable_model.gd")
var rules
var game
var rows: Dictionary={}
var nodes: Dictionary={}
var next_id:=1
var next_scan:=0.0
var contacts: Array=[[],[]]
var suppressed: Array=[]
var supply_time: Dictionary={}
func setup(value):rules=value;game=rules.game
func reset():
	for node in nodes.values():if is_instance_valid(node):node.queue_free()
	rows.clear();nodes.clear();next_id=1;next_scan=0;contacts=[[],[]];suppressed.clear();supply_time.clear()
func active() -> bool:return rules.enabled() and rules.mode.kind=="st"
func operational(row: Dictionary) -> bool:return row.hp>Data.hp(row.kind)*(.2 if row.kind in ["pulse","motion","remote_jammer"] else .5)
func count(team: int,kind: String) -> int:
	return rows.values().filter(func(row):return row.team==team and row.kind==kind).size()
func accessible(id: int) -> bool:
	if not active() or not game.active or game.map_loading or game.intermission>0 or not game.players.has(id) or not game.fighters.has(id):return false
	var s: Dictionary=game.players[id]
	return not s.dead and not s.spectator and s.team in [0,1] and not rules.mode.special.blocked(id)
func enabled(id: int) -> bool:
	return accessible(id) and not game.players[id].get("input_blocked",false)
func placement(id: int,origin: Vector3,direction: Vector3) -> Dictionary:
	if not enabled(id) or not origin.is_finite() or not direction.is_finite() or absf(direction.length()-1)>.01:return {}
	var s: Dictionary=game.players[id];var kind: String=s.tribes_pack
	if not Data.is_pack(kind) or not Data.allowed(s.tribes_class,kind) or count(s.team,kind)>=Data.KINDS[kind].limit:return {}
	var actor=game.fighters[id];var eye: Vector3=actor.position+Vector3.UP*actor.eye_height()
	if eye.distance_to(origin)>1.8 or not ray(eye,origin).is_empty():return {}
	var hit:=ray(origin,origin+direction*3)
	if hit.is_empty() or hit.collider.has_meta("st_deployable"):return {}
	if kind not in ["camera","motion"] and hit.normal.y<=.7:return {}
	var point: Vector3=hit.position+hit.normal*.03
	var pads=rules.stations()
	if not pads or not pads.playable_bounds.has_point(point):return {}
	var nearby_turrets:=0
	for row in rows.values():
		var offset: Vector3=(row.position-point).abs()
		if row.position.distance_to(point)<1.4:return {}
		if kind=="turret" and row.kind=="turret":
			if offset.x<5 and offset.y<5 and offset.z<5:return {}
			if offset.x<25 and offset.y<12.5 and offset.z<25:nearby_turrets+=1
	if nearby_turrets>=2:return {}
	for peer in game.players:
		if game.players[peer].dead or game.players[peer].spectator:continue
		if (game.fighters[peer].position+Vector3.UP*.5).distance_to(point+hit.normal*.5)<1.05:return {}
	var row:={"kind":kind,"team":s.team,"owner":id,"position":point,"normal":hit.normal,"yaw":s.yaw,"hp":Data.hp(kind),"energy":float(Data.KINDS[kind].reserve),"ready":game.clock+1,"aim":-Basis(Vector3.UP,s.yaw).z}
	if kind=="camera":row.aim=hit.normal if hit.normal.y<.7 else -Data.frame(row).basis.z
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=Data.KINDS[kind].size
	query.shape=shape;query.collision_mask=1;query.transform=Data.frame(row)*Transform3D(Basis.IDENTITY,Vector3(0,shape.size.y*.5+.025,0))
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return {}
	return row
func deploy(id: int,origin: Vector3,direction: Vector3) -> bool:
	if not game.multiplayer.is_server():return false
	var row:=placement(id,origin,direction)
	if row.is_empty():return false
	rows[next_id]=row;next_id+=1
	var s: Dictionary=game.players[id];s.tribes_pack="none";game.fighters[id].tribes_state.pack="none";game.fighters[id].tribes_state.pack_on=false
	# The used pack can no longer be traded back. Equipment value also clamps
	# credit, so deployment cannot manufacture team or remote-station energy.
	s.tribes_paid=maxi(0,s.tribes_paid-int(rules.Arsenal.PACKS[row.kind].cost))
	sync();return true
func ray(a: Vector3,b: Vector3) -> Dictionary:
	if a.distance_squared_to(b)<.000001:return {}
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func station(id: int,inventory_only: bool=true) -> int:
	# Menus block weapon input, not access to a station or its local reserve.
	if not accessible(id):return -1
	var point: Vector3=game.fighters[id].position;var team: int=game.players[id].team
	for key in rows:
		var row: Dictionary=rows[key]
		if row.team!=team or row.kind not in (["inventory"] if inventory_only else ["inventory","ammo_station"]) or (game.clock<row.ready or not operational(row)):continue
		var pad: Vector3=Data.frame(row)*Vector3(0,0,-1.25)
		if absf(point.y-pad.y)>.9 or Vector2(point.x-pad.x,point.z-pad.z).length()>1.4:continue
		if ray(point+Vector3.UP*.8,pad+Vector3.UP*.8).is_empty():return key
	return -1
func can_shop(id: int,armour: String,pack: String) -> bool:
	return station(id)<0 or armour==game.players[id].tribes_class and pack not in ["inventory","ammo_station"]
func available(id: int) -> int:
	var key:=station(id)
	return floori(rows[key].energy) if key>=0 else rules.balance(id)
func pay(id: int,amount: int):
	var key:=station(id)
	if key>=0:rows[key].energy=clampf(rows[key].energy-amount,0,Data.KINDS.inventory.reserve)
	else:rules.spend(id,amount)
func trace(start: Vector3,end: Vector3,hit: Dictionary,radius: float) -> Dictionary:
	var nearest: float=start.distance_to(hit.position)+.01
	for key in rows:
		var row: Dictionary=rows[key];var frame: Transform3D=Data.frame(row);var size: Vector3=Data.KINDS[row.kind].size
		var inverse:=frame.affine_inverse()
		var local: Variant=AABB(Vector3(-size.x*.5,0,-size.z*.5),size).grow(radius).intersects_segment(inverse*start,inverse*end)
		if local==null:continue
		var point: Vector3=frame*local;var distance:=start.distance_to(point)
		if distance<nearest:nearest=distance;hit={"id":0,"hit":true,"position":point,"deployable":key}
	return hit
func damage(key: int,attacker: int,amount: float):
	if not game.multiplayer.is_server() or not rows.has(key) or amount<=0:return
	if game.players.get(attacker,{}).get("team",-1)==rows[key].team and not rules.mode.friendly_fire:return
	rows[key].hp=maxf(0,rows[key].hp-amount)
	if rows[key].hp<=Data.hp(rows[key].kind)*(0.0 if rows[key].kind in ["pulse","motion","remote_jammer"] else .25):rows.erase(key);sync()
func repair(key: int,id: int,amount: float) -> bool:
	if not game.multiplayer.is_server() or not rows.has(key) or game.players[id].team!=rows[key].team:return false
	var before: float=rows[key].hp;rows[key].hp=minf(Data.hp(rows[key].kind),before+maxf(0,amount));return rows[key].hp>before
func blast(where: Vector3,owner_id: int,amount: float,radius: float,source_team: int=-1):
	for key in rows.keys():
		var row: Dictionary=rows[key];var point: Vector3=Data.frame(row)*Vector3(0,Data.KINDS[row.kind].size.y*.5,0)
		if row.team==source_team and not rules.mode.friendly_fire:continue
		var distance:=where.distance_to(point)
		if distance>=radius:continue
		var hit: Dictionary=game._trace(where+(point-where).normalized()*.06,point,owner_id)
		if hit.get("deployable",-1)==key:damage(key,owner_id,amount*(1-distance/radius))
func jammed(target: int) -> bool:
	if rules.jammed(target):return true
	for row in rows.values():
		if row.kind=="remote_jammer" and operational(row) and row.team==game.players[target].team and game.clock>=row.ready and row.position.distance_to(game.fighters[target].position)<=80:return true
	return false
func scan():
	contacts=[[],[]];suppressed.clear()
	var pads=rules.stations()
	if pads:
		for key in pads.assets.rows.size():
			var row: Dictionary=pads.assets.rows[key]
			if row.kind=="pulse" and pads.assets.active(key):scan_pulse(row.team,row.frame.origin+Vector3.UP*6.15,float(row.get("range",pads.assets.SENSOR_RANGE)))
	for row in rows.values():
		if row.kind not in ["pulse","motion","camera"] or (game.clock<row.ready or not operational(row)):continue
		var eye: Vector3=Data.eye(row)
		for id in game.players:
			var s: Dictionary=game.players[id]
			if s.dead or s.spectator or s.team==row.team:continue
			var actor=game.fighters[id];var point: Vector3=actor.position+Vector3.UP*actor.torso_height()
			if point.distance_to(eye)>Data.KINDS[row.kind].range:continue
			if row.kind=="motion":
				if actor.velocity.length()<1:continue
			else:
				if row.kind=="camera" and row.aim.dot((point-eye).normalized())<.707:continue
				if not ray(eye,point).is_empty():continue
				if row.kind=="pulse" and jammed(id):
					if id not in suppressed:suppressed.append(id)
					continue
			if id not in contacts[row.team]:contacts[row.team].append(id)
func scan_pulse(team: int,eye: Vector3,distance: float):
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.dead or s.spectator or s.team not in [0,1] or s.team==team:continue
		var actor=game.fighters[id];var point: Vector3=actor.position+Vector3.UP*actor.torso_height()
		if eye.distance_to(point)>distance or not ray(eye,point).is_empty():continue
		if jammed(id):
			if id not in suppressed:suppressed.append(id)
		elif id not in contacts[team]:contacts[team].append(id)
func sensor_status(id: int) -> String:
	var team: int=game.players.get(id,{}).get("team",-1)
	if team not in [0,1]:return ""
	if id in contacts[1-team]:return "DETECTED"
	return "JAMMED" if id in suppressed else "CLEAR"
func tick(delta: float):
	if not active() or not game.multiplayer.is_server():return
	if game.clock>=next_scan:next_scan=game.clock+.2;scan()
	for key in rows:
		var row: Dictionary=rows[key]
		if row.kind not in ["turret","camera"] or (game.clock<row.ready or not operational(row)):continue
		if row.kind=="turret":row.energy=minf(60,row.energy+5*delta)
		if rules.remote.advance(key,delta) or row.kind=="camera":continue
		var start: Vector3=Data.frame(row)*Vector3(0,1.2,0)
		var target:=0;var nearest:=30.0
		for id in game.players:
			var s: Dictionary=game.players[id]
			if s.dead or s.spectator or s.team==row.team:continue
			var actor=game.fighters[id];var point: Vector3=actor.position+Vector3.UP*actor.torso_height()
			var distance:=start.distance_to(point)
			if distance>nearest or actor.velocity.length()<1 and id not in contacts[row.team]:continue
			if not ray(start,point).is_empty():continue
			target=id;nearest=distance
		if target==0:continue
		var actor=game.fighters[target];var point: Vector3=actor.position+Vector3.UP*actor.torso_height()+actor.velocity*nearest/80
		var direction: Vector3=(point-start).normalized();row.aim=row.aim.slerp(direction,minf(1,delta*6)).normalized()
		if row.aim.dot(direction)<.97 or row.energy<6 or game.clock<float(row.get("fire_at",0)):continue
		fire(key,row.owner if game.players.has(row.owner) and game.players[row.owner].team==row.team else 0)
	for id in game.players:
		var key:=station(id,false)
		if key<0:supply_time.erase(id);continue
		if game.clock<float(supply_time.get(id,0)):continue
		supply_time[id]=game.clock+.5
		var row: Dictionary=rows[key];var s: Dictionary=game.players[id]
		for w in [1,2,3,4,7,9,10]:
			if w not in s.owned:continue
			var amount:=mini(rules.Arsenal.capacity(s.tribes_class,s.tribes_pack,w)-s.tribes_ammo[w],20 if w==2 else 2)
			amount=mini(amount,floori(row.energy/rules.Arsenal.AMMO_PRICE[w]))
			if amount<=0:continue
			var cost: int=amount*rules.Arsenal.AMMO_PRICE[w];s.tribes_ammo[w]+=amount;row.energy-=cost;s.tribes_paid=mini(rules.MAX_TEAM_ENERGY,s.tribes_paid+cost)
		if not s.tribes_kit and row.energy>=35:s.tribes_kit=true;row.energy-=35;s.tribes_paid=mini(rules.MAX_TEAM_ENERGY,s.tribes_paid+35)
func fire(key: int,owner_id: int) -> bool:
	if not game.multiplayer.is_server() or not rows.has(key):return false
	var row: Dictionary=rows[key]
	if row.kind!="turret" or not operational(row) or game.clock<row.ready or row.energy<6 or game.clock<float(row.get("fire_at",0)):return false
	var start: Vector3=Data.eye(row)
	# The projectile begins above the housing; never shoot through adjacent cover.
	if not ray(start,start+row.aim*.35).is_empty():return false
	if game.variant_combat.launch(owner_id,0,start,row.aim,{"tribes_turret":true,"turret_team":row.team})<0:return false
	row.fire_at=game.clock+.4;row.energy-=5;rules.deployable_sound.rpc(game.map_epoch,start);return true
func sync():
	for key in nodes.keys():
		if not rows.has(key):
			if is_instance_valid(nodes[key]):nodes[key].queue_free()
			nodes.erase(key)
	for key in rows:
		var row: Dictionary=rows[key]
		if not nodes.has(key) or not is_instance_valid(nodes[key]):
			var node:=StaticBody3D.new();node.collision_layer=1;node.collision_mask=0;node.set_meta("st_deployable",key)
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Data.KINDS[row.kind].size;shape.shape=box;shape.position.y=box.size.y*.5;node.add_child(shape)
			if not game.headless:node.add_child(Model.make(row.kind,row.team))
			game.add_child(node);nodes[key]=node
		nodes[key].global_transform=Data.frame(row)
	update_visuals()
func update_visuals():
	if game.headless:return
	for key in nodes:
		if not rows.has(key) or not is_instance_valid(nodes[key]):continue
		var row: Dictionary=rows[key]
		if not game.headless:preload("res://deathmatch/tribes/prop_library.gd").set_active(nodes[key].get_child(1),operational(row))
		if not game.headless and row.kind in ["turret","camera"]:
			var head=nodes[key].get_child(1).get_node("Head")
			head.look_at(head.global_position+row.aim,Vector3.UP if absf(row.aim.y)<.99 else Vector3.RIGHT)
func snapshot() -> Dictionary:
	var result: Dictionary={}
	for key in rows:
		result[key]=rows[key].duplicate();result[key].erase("fire_at")
	return {"rows":result,"contacts":contacts.duplicate(true),"suppressed":suppressed.duplicate()}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() not in [2,3] or data.size()==3 and not data.has("suppressed") or not data.get("rows") is Dictionary or data.rows.size()>150 or not data.get("contacts") is Array or data.contacts.size()!=2:return false
	if not data.get("suppressed",[]) is Array or data.get("suppressed",[]).size()>128:return false
	for id in data.get("suppressed",[]):
		if not id is int:return false
	var counts: Dictionary={}
	for key in data.rows:
		var r=data.rows[key]
		if not key is int or key<=0 or not r is Dictionary or r.size()!=10 or not Data.is_pack(str(r.get("kind",""))) or not r.get("team") is int or r.get("team") not in [0,1] or not r.get("owner") is int:return false
		for field in ["position","normal","aim"]:
			if not r.get(field) is Vector3 or not r[field].is_finite():return false
		if r.position.length()>16384 or absf(r.normal.length()-1)>.01 or absf(r.aim.length()-1)>.01:return false
		for field in ["yaw","hp","energy","ready"]:
			if not (r.get(field) is float or r.get(field) is int) or not is_finite(float(r[field])):return false
		if r.hp<=0 or r.hp>Data.hp(r.kind) or r.energy<0 or r.energy>Data.KINDS[r.kind].reserve or r.ready<0:return false
		var count_key: String=str(r.team)+r.kind;counts[count_key]=counts.get(count_key,0)+1
		if counts[count_key]>Data.KINDS[r.kind].limit:return false
	for team in data.contacts:
		if not team is Array or team.size()>128:return false
		for id in team:if not id is int:return false
	return true
func receive(data: Dictionary):
	if not valid(data):return
	rows=data.rows.duplicate(true);contacts=data.contacts.duplicate(true);suppressed=data.get("suppressed",[]).duplicate();sync()
