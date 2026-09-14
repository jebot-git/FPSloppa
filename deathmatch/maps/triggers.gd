extends RefCounted
## Common Quake entity logic. All activations originate on the server.
const SCALE=preload("res://deathmatch/maps/loader.gd").SCALE
var runtime
var game
var rows: Dictionary={}
var targets: Dictionary={}
var pending: Array=[]
var killed_targets: Array=[]
var crush_until: Dictionary={}
func setup(owner_runtime,entities: Array) -> void:
	runtime=owner_runtime;game=runtime.game
	for node in entities:
		var e: Dictionary=node.attributes
		if int(e.get("spawnflags",0))&2048:continue
		var kind: String=e.get("classname","")
		var row:={"node":node,"data":e,"kind":kind,"until":0.0,"hp":float(e.get("health",0)),"count":int(e.get("count",2)),"gate":-1,"bounds":runtime.node_bounds(node),"initial_position":node.position}
		rows[node]=row
		var target: String=e.get("targetname","")
		if not target.is_empty():
			if not targets.has(target):targets[target]=[]
			targets[target].append(node)
		for i in game.gates.size():
			if game.gates[i].node==node:row.gate=i;break
		if kind=="func_button":
			var travel:=direction(e)*maxf(0,extent(row.bounds.size,direction(e))-float(e.get("lip",4))*SCALE)
			row.gate=game.gates.size()
			game.gates.append({"node":node,"base_position":node.position,"base":node.position.y,"travel":travel,"center":row.bounds.get_center(),"open":false,"until":0.0,"bsp":true,"touch_target":true,"move_seconds":maxf(.05,travel.length()/(float(e.get("speed",40))*SCALE)),"wait_seconds":float(e.get("wait",1))})
		if kind=="func_door_secret" and (target.is_empty() or int(e.get("spawnflags",0))&16) and not int(e.get("spawnflags",0))&8:row.hp=10000.0
		if row.gate>=0:
			var gate: Dictionary=game.gates[row.gate]
			gate.touch_target=kind!="func_door" or not target.is_empty() or row.hp>0
			gate.wait_seconds=float(e.get("wait",5 if kind=="func_door_secret" else 1 if kind=="func_button" else 3))
			gate.move_seconds=maxf(.05,gate.travel.length()/(maxf(1,float(e.get("speed",40 if kind=="func_button" else 100)))*SCALE))
			gate.toggle=kind=="func_door" and int(e.get("spawnflags",0))&32!=0
			if kind=="func_door" and int(e.get("spawnflags",0))&1:
				node.position+=gate.travel;gate.base_position=node.position;gate.travel=-gate.travel
			if kind=="func_door_secret":
				if int(e.get("spawnflags",0))&1:gate.wait_seconds=-1.0
				var forward:=direction(e);var sideways:=forward.cross(Vector3.UP)
				var first: Vector3=Vector3.DOWN*row.bounds.size.y if int(e.get("spawnflags",0))&4 else sideways*extent(row.bounds.size,sideways)*(-1.0 if int(e.get("spawnflags",0))&2 else 1.0)
				gate.secret_first=first;gate.travel=first+forward*extent(row.bounds.size,forward)
				gate.move_seconds=(first.length()+(gate.travel-first).length())/(50*SCALE)+1
				gate.secret_speed=50*SCALE
		if node is Area3D and row.hp>0:node.collision_layer=1
	# Adjacent door panels form one group unless DOOR_DONT_LINK is set.
	for node in rows:
		var row: Dictionary=rows[node]
		if row.kind!="func_door" or int(row.data.get("spawnflags",0))&4:continue
		var group: Array=[node];var scan:=0
		while scan<group.size():
			var current: Dictionary=rows[group[scan]];scan+=1
			for other in rows:
				var candidate: Dictionary=rows[other]
				if other in group or candidate.kind!="func_door" or int(candidate.data.get("spawnflags",0))&4:continue
				if current.bounds.grow(.001).intersects(candidate.bounds):group.append(other)
		var controlled: bool=group.any(func(n):return game.gates[rows[n].gate].touch_target)
		for member in group:
			rows[member].group=group
			game.gates[rows[member].gate].touch_target=controlled
	configure_trains()
static func extent(size: Vector3,axis: Vector3) -> float:return size.abs().dot(axis.abs())
static func direction(e: Dictionary) -> Vector3:
	var angle:=float(e.get("angle",0))
	return Vector3.UP if angle==-1 else Vector3.DOWN if angle==-2 else Vector3(-sin(deg_to_rad(angle)),0,-cos(deg_to_rad(angle)))
func use_target(target: String,id: int,visited: Array=[]) -> bool:
	var used:=false
	var chain:=visited.duplicate()
	for node in targets.get(target,[]):
		if activate(node,id,chain):
			used=true
			chain.append_array(rows[node].get("group",[node]))
	return used
func activate(node: Node,id: int,visited: Array=[]) -> bool:
	if not game.multiplayer.is_server() or not rows.has(node) or node in visited or visited.size()>=32:return false
	var row: Dictionary=rows[node]
	if game.clock<row.until:return false
	var chain:=visited.duplicate();chain.append(node)
	if row.kind=="trigger_counter":
		row.count-=1
		if row.count>0:return true
	if row.gate>=0:
		for member in row.get("group",[node]):
			var entry: Dictionary=rows[member];var gate: Dictionary=game.gates[entry.gate]
			if game.match_mode.kind=="as" and game.match_mode.assault.stage<int(gate.get("as_unlock",0)):continue
			var opened: bool=not gate.open if gate.get("toggle",false) else true
			gate.until=INF if gate.wait_seconds<0 or gate.get("toggle",false) else game.clock+gate.move_seconds+gate.wait_seconds
			game._gate_state.rpc(entry.gate,opened)
		row.until=game.clock+game.gates[row.gate].move_seconds+maxf(0,game.gates[row.gate].wait_seconds) if row.kind=="func_button" else game.clock+.1
		if row.kind=="func_button":row.until+=game.gates[row.gate].move_seconds
	elif row.kind=="trigger_relay":row.until=0.0
	else:
		row.until=INF if row.kind in ["trigger_once","trigger_secret","trigger_counter"] or float(row.data.get("wait",.2))<0 else game.clock+maxf(.2,float(row.data.get("wait",.2)))
	var delay:=maxf(0,float(row.data.get("delay",0)))
	# Buttons fire their targets when they finish pressing inward.
	if row.kind=="func_button":delay+=game.gates[row.gate].move_seconds
	if delay>0:pending.append({"at":game.clock+delay,"data":row.data,"id":id,"visited":chain})
	else:fire_targets(row.data,id,chain)
	return true
func fire_targets(e: Dictionary,id: int,visited: Array) -> void:
	var killed: String=e.get("killtarget","")
	if not killed.is_empty() and not killed in killed_targets:killed_targets.append(killed)
	receive_killed(killed_targets)
	use_target(str(e.get("target","")),id,visited)
func damage(node: Node,id: int,amount: float) -> void:
	if not rows.has(node) or amount<=0:return
	var row: Dictionary=rows[node]
	if row.hp<=0 or game.clock<row.until:return
	if row.gate>=0 and game.gates[row.gate].open:return
	row.hp-=amount
	if row.hp<=0 or row.kind=="func_door_secret":
		activate(node,id)
		row.hp=float(row.data.get("health",10000 if row.kind=="func_door_secret" else 0))
func tick() -> void:
	if not game.multiplayer.is_server():return
	tick_trains()
	crush()
	for event in pending.duplicate():
		if game.clock>=event.at:pending.erase(event);fire_targets(event.data,event.id,event.visited)
	for node in rows:
		var row: Dictionary=rows[node]
		if row.kind!="func_button" or float(row.data.get("health",0))>0 or game.clock<row.until:continue
		for id in game.players:
			if game.players[id].dead or game.players[id].spectator or game.match_mode.special.blocked(id):continue
			var actor=game.fighters[id]
			var box:=AABB(actor.position+Vector3(-.3,0,-.3),Vector3(.6,actor.collision_height,.6))
			if not row.bounds.grow(.08).intersects(box):continue
			var start: Vector3=actor.position+Vector3.UP*actor.torso_height()
			var end: Vector3=row.bounds.get_center()
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
			if hit.is_empty() or hit.collider==node:activate(node,id)

func configure_trains() -> void:
	for node in rows:
		var row: Dictionary=rows[node]
		if row.kind!="func_train":continue
		var corners: Array=[];var name: String=row.data.get("target","")
		for step in 128:
			var choices: Array=targets.get(name,[])
			if choices.is_empty() or choices[0] in corners:break
			var corner: Node3D=choices[0]
			if rows[corner].kind!="path_corner":break
			corners.append(corner);name=rows[corner].data.get("target","")
		if corners.size()<2:continue
		var offset: Vector3=node.position-row.bounds.position
		row.route=[];row.route_time=0.0
		for i in corners.size():
			var from: Vector3=corners[i].position+offset
			var to: Vector3=corners[(i+1)%corners.size()].position+offset
			var wait:=maxf(0,float(rows[corners[i]].data.get("wait",0)))
			var seconds:=from.distance_to(to)/(maxf(1,float(row.data.get("speed",100)))*SCALE)
			row.route.append({"from":from,"to":to,"wait":wait,"seconds":seconds});row.route_time+=seconds+wait
		row.started=game.clock
		row.gate=game.gates.size()
		game.gates.append({"node":node,"base_position":corners[0].position+offset,"base":node.position.y,"travel":Vector3.ZERO,"center":row.bounds.get_center(),"open":false,"until":INF,"bsp":true,"touch_target":true,"train":true})
		node.position=corners[0].position+offset
func tick_trains() -> void:
	for node in rows:
		var row: Dictionary=rows[node]
		if not row.has("route") or row.route_time<=0:continue
		var at:=fposmod(game.clock-float(row.started),float(row.route_time))
		for leg in row.route:
			var duration: float=leg.wait+leg.seconds
			if at>duration:at-=duration;continue
			node.position=leg.from.lerp(leg.to,clampf((at-leg.wait)/maxf(.001,leg.seconds),0,1));break

func blast(origin: Vector3,id: int,amount: float,radius: float) -> void:
	if radius<=0:return
	for node in rows:
		var row: Dictionary=rows[node]
		if row.hp<=0:continue
		var centre: Vector3=row.bounds.get_center()
		if row.gate>=0:centre+=node.position-game.gates[row.gate].base_position
		var distance:=origin.distance_to(centre)
		if distance>=radius:continue
		var query:=PhysicsRayQueryParameters3D.create(origin,centre,1);query.collide_with_areas=true
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider==node:damage(node,id,amount*(1-distance/radius))

func receive_killed(names: Array) -> void:
	for name in names:
		for node in targets.get(name,[]):
			rows[node].until=INF
			if node is CollisionObject3D:node.collision_layer=0;node.collision_mask=0
			node.hide()
func crush() -> void:
	for node in rows:
		var row: Dictionary=rows[node]
		if row.kind!="func_door" or float(row.data.get("dmg",0))<=0 or row.gate<0:continue
		var gate: Dictionary=game.gates[row.gate]
		if not gate.has("motion_tween") or not is_instance_valid(gate.motion_tween) or not gate.motion_tween.is_running():continue
		var bounds: AABB=row.bounds
		bounds.position+=node.position-row.get("initial_position",Vector3.ZERO)
		for id in game.players:
			if game.players[id].dead or game.players[id].spectator or game.clock<crush_until.get(id,0.0):continue
			var actor=game.fighters[id]
			if bounds.grow(-.02).intersects(AABB(actor.position+Vector3(-.28,.05,-.28),Vector3(.56,actor.collision_height-.1,.56))):
				crush_until[id]=game.clock+.5
				game._damage(id,0,int(row.data.dmg),"CRUSH",true)
