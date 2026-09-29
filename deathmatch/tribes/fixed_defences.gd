extends RefCounted
const Health=preload("res://deathmatch/tribes/equipment_health.gd")
const Data=preload("res://deathmatch/tribes/fixed_defence_data.gd")
var pads
var rows: Array=[]
var next_scan:=0.0
var heat: Dictionary={}
var stats: Dictionary={}
var game:
	get:return pads.game
func setup(value,entities: Array):
	pads=value
	for entity in entities:
		var e: Dictionary=entity.attributes
		if e.get("classname","") not in ["info_tribes_turret_socket","info_tribes_turret"] or int(e.get("team",-1)) not in [0,1]:continue
		var kind: String=e.get("type","fusion")
		if not Data.TYPES.has(kind):continue
		rows.append({"kind":kind,"power_group":pads.circuit(e).power_group,"power_sources":pads.circuit(e).power_sources,"team":int(e.team),"position":entity.global_position-Vector3.UP*.70,"hp":Data.hp(kind),"energy":Data.TYPES[kind].energy,"aim":-Basis(Vector3.UP,deg_to_rad(float(e.get("angle",0)))).z,"operator":0,"target":0,"fire_at":0.0})
	rows.sort_custom(func(a,b):return a.team<b.team or a.team==b.team and a.position.x<b.position.x)
	for key in rows.size():fixture(key)
func reset():
	heat.clear();next_scan=0;stats.clear()
	for row in rows:row.hp=Data.hp(row.kind);row.energy=Data.TYPES[row.kind].energy;row.operator=0;row.target=0;row.fire_at=0.0;row.erase("command")
func active(key: int) -> bool:return game.match_mode.kind=="st" and key>=0 and key<rows.size() and Health.enabled(rows[key].hp,Data.hp(rows[key].kind)) and pads.connected(rows[key])
func operated(id: int) -> int:
	if id==0:return -1
	for key in rows.size():
		if rows[key].operator==id:return key
	return -1
func release(id: int):
	for row in rows:
		if row.operator==id:row.operator=0;row.erase("command")
func eligible(id: int) -> bool:
	if not game.active or game.map_loading or game.intermission>0 or not game.players.has(id) or not game.fighters.has(id):return false
	var s: Dictionary=game.players[id]
	return not s.dead and not s.spectator and not game.match_mode.special.blocked(id) and game.match_mode.st.carried(id)<0 and not game.match_mode.tribes.vehicles.mounted(id)
func control(id: int,key: int,epoch: int,life: int) -> bool:
	if not game.multiplayer.is_server() or epoch!=game.map_epoch or game.players.get(id,{}).get("serial",-1)!=life:return false
	if key<0:release(id);return true
	if not eligible(id) or not active(key) or rows[key].team!=game.players[id].team or rows[key].operator not in [0,id]:return false
	release(id);rows[key].operator=id;rows[key].lease=game.clock+1;rows[key].life=life;return true
func command(id: int,key: int,epoch: int,life: int,direction: Vector3,fire: bool) -> bool:
	if not game.multiplayer.is_server() or epoch!=game.map_epoch or not eligible(id) or not active(key) or rows[key].operator!=id or rows[key].life!=life or game.players[id].serial!=life or not direction.is_finite() or absf(direction.length()-1)>.01:return false
	if game.players[id].get("input_blocked",false):return false
	rows[key].lease=game.clock+.6;rows[key].command={"aim":direction,"fire":fire};return true
func eye(key: int) -> Vector3:return rows[key].position+Vector3.UP*(Data.size(rows[key].kind).y-.25)
func muzzle(key: int) -> Vector3:return eye(key)+rows[key].aim*2.1
func trace(hit: Dictionary) -> Dictionary:
	if game.match_mode.kind!="st" or not hit.hit or hit.id!=0:return hit
	for key in rows.size():
		var size: Vector3=Data.size(rows[key].kind)
		if AABB(rows[key].position-Vector3(size.x*.5,0,size.z*.5),size).grow(.08).has_point(hit.position):hit["fixed_turret"]=key;hit.erase("surface_normal");break
	return hit
func damage(key: int,attacker: int,amount: float,family: String=""):
	if not game.multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=rows.size() or not is_finite(amount) or amount<=0:return
	if game.players.get(attacker,{}).get("team",-1)==rows[key].team and not game.match_mode.friendly_fire:return
	Health.hit(rows[key],Data.hp(rows[key].kind),amount,pads.connected(rows[key]),family)
	if not active(key):rows[key].operator=0;rows[key].target=0
func repair(key: int,id: int,amount: float) -> bool:
	if not game.multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=rows.size() or game.players.get(id,{}).get("team",-1)!=rows[key].team or not is_finite(amount) or amount<=0:return false
	var before: float=rows[key].hp;rows[key].hp=minf(Data.hp(rows[key].kind),before+amount);return rows[key].hp>before
func blast(where: Vector3,attacker: int,amount: float,radius: float,team: int=-1,family: String=""):
	for key in rows.size():
		if rows[key].team==team and not game.match_mode.friendly_fire:continue
		if where.distance_to(eye(key))>radius+4:continue
		var hit: Dictionary=game._trace(where,eye(key),attacker)
		if hit.get("fixed_turret",-1)==key and where.distance_to(hit.position)<radius:damage(key,attacker,amount*(1-where.distance_to(hit.position)/radius),family)
func warm(id: int) -> bool:return game.match_mode.tribes.vehicles.mounted(id) or game.clock<float(heat.get(id,0))
func acquire(key: int) -> int:
	var row: Dictionary=rows[key];var d: Dictionary=Data.TYPES[row.kind];var nearest: float=d.range;var selected:=0
	if nearest<=0:return 0 # Original mortar is manually operated.
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.dead or s.spectator or s.team==row.team:continue
		if row.kind=="missile" and not warm(id):continue
		var actor=game.fighters[id];var point: Vector3=actor.position+Vector3.UP*actor.torso_height();var distance: float=eye(key).distance_to(point)
		if distance>=nearest or row.kind=="mini" and actor.velocity.length()<2 and id not in game.match_mode.tribes.deployables.contacts[row.team]:continue
		if not game.match_mode.tribes.deployables.ray(muzzle(key),point).is_empty():continue
		selected=id;nearest=distance
	return selected
func tick(delta: float):
	if not game.multiplayer.is_server() or game.match_mode.kind!="st":return
	for id in game.players:
		if not game.players[id].dead and not game.players[id].spectator and game.fighters[id].tribes_state.jetting:heat[id]=game.clock+.75
	for id in heat.keys():
		if not game.players.has(id) or heat[id]<game.clock:heat.erase(id)
	var scan: bool=game.clock>=next_scan
	if scan:next_scan=game.clock+.2
	for key in rows.size():
		var row: Dictionary=rows[key];var d: Dictionary=Data.TYPES[row.kind]
		if row.operator!=0 and (not active(key) or not eligible(row.operator) or row.team!=game.players[row.operator].team or game.players[row.operator].serial!=row.get("life",-1) or game.clock>row.get("lease",0)):release(row.operator)
		if not active(key):continue
		row.energy=minf(d.energy,row.energy+d.recharge*delta)
		if scan and row.operator==0:row.target=acquire(key)
		var desired: Vector3=row.aim;var firing:=false
		if row.operator!=0:
			var input: Dictionary=row.get("command",{})
			if not input.is_empty():desired=input.aim;firing=input.fire and not game.players[row.operator].get("input_blocked",false)
		elif row.target!=0 and game.players.has(row.target) and not game.players[row.target].dead:
			var actor=game.fighters[row.target];var point: Vector3=actor.position+Vector3.UP*actor.torso_height()
			if row.kind=="missile" and not warm(row.target):row.target=0;continue
			if not game.match_mode.tribes.deployables.ray(muzzle(key),point).is_empty():continue
			if d.speed>0:point+=actor.velocity*minf(1.5,eye(key).distance_to(point)/d.speed)
			desired=(point-eye(key)).normalized();firing=true
		row.aim=row.aim.slerp(desired,minf(1,delta*d.turn)).normalized()
		if firing and row.aim.dot(desired)>.985 and row.energy>=d.minimum and game.clock>=row.fire_at:fire(key)
func fire(key: int) -> bool:
	if not game.multiplayer.is_server() or not active(key):return false
	var row: Dictionary=rows[key];var d: Dictionary=Data.TYPES[row.kind];var start:=muzzle(key)
	if row.energy<d.minimum or game.clock<row.fire_at:return false
	if not game.match_mode.tribes.deployables.ray(eye(key)+row.aim*1.7,start).is_empty():return false
	if row.kind=="elf":
		var hit: Dictionary=game._trace(start,start+row.aim*d.range,0)
		if hit.id==0 or game.players[hit.id].team==row.team:return false
		game.fighters[hit.id].tribes_state.energy=maxf(0,game.fighters[hit.id].tribes_state.energy-6)
		var damage: int=game.match_mode.tribes.combat.fractional(-5000-key,hit.id,.006,"fixed_elf")
		if damage>0:game._damage(hit.id,row.operator,damage,d.name,false,hit.position,row.aim)
		game._impacts.rpc(start,PackedVector3Array([hit.position]),6)
	else:
		if game.variant_combat.launch(row.operator,d.weapon,start,row.aim,{"fixed_turret":row.kind,"turret_team":row.team,"target":row.target})<0:return false
	row.energy=maxf(0,row.energy-d.cost);row.fire_at=game.clock+d.cycle
	stats[row.kind]=int(stats.get(row.kind,0))+1;game.match_mode.tribes.deployable_sound.rpc(game.map_epoch,start);return true
func fixture(key: int):
	var row: Dictionary=rows[key];var node:=StaticBody3D.new();node.collision_layer=1;node.collision_mask=0
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Data.size(row.kind);shape.shape=box;shape.position.y=box.size.y*.5;node.add_child(shape);pads.add_child(node);node.global_position=row.position
	if not game.headless:
		var model=preload("res://deathmatch/tribes/fixed_defence_model.gd").make(row.kind,row.team);node.add_child(model);row.model=model
func update():
	for key in rows.size():
		var row: Dictionary=rows[key]
		if not is_instance_valid(row.get("model")):continue
		preload("res://deathmatch/tribes/prop_library.gd").set_active(row.model,active(key))
		var head=row.model.get_node("Head");head.look_at(head.global_position+row.aim,Vector3.UP if absf(row.aim.y)<.99 else Vector3.RIGHT)
		row.model.get_node("Status").text=Data.TYPES[row.kind].name+" · "+("OFFLINE" if not active(key) else "CONTROLLED" if row.operator else "%d%%"%roundi(100*row.hp/Data.hp(row.kind)))
func snapshot() -> Array:return rows.map(func(row):return [row.hp,row.energy,row.aim,row.operator])
static func valid(data: Variant) -> bool:
	if not data is Array or data.size()>64:return false
	for row in data:
		if not row is Array or row.size()!=4 or not row[3] is int or not row[2] is Vector3 or not row[2].is_finite() or absf(row[2].length()-1)>.01:return false
		for i in 2:
			if not (row[i] is float or row[i] is int) or not is_finite(float(row[i])) or row[i]<0 or row[i]>(Data.hp("mini") if i==0 else 200):return false
	return true
func receive(data: Array):
	if not valid(data) or data.size()!=rows.size():return
	for i in rows.size():
		if data[i][0]>Data.hp(rows[i].kind) or data[i][1]>Data.TYPES[rows[i].kind].energy:return
	for i in rows.size():rows[i].hp=data[i][0];rows[i].energy=data[i][1];rows[i].aim=data[i][2];rows[i].operator=data[i][3]
