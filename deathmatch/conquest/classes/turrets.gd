extends Node3D
const Attribution=preload("res://deathmatch/server/attribution.gd")
## One stationary body per owner. Authority scans at 10 Hz and launches normal ordnance.
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const HP:=200
const AMMO:=12
const RANGE:=150.0
const COOLDOWN:=120.0
const INTERVAL:=1.5
const HALF:=1.0
const MUZZLE_HEIGHT:=1.15
const MUZZLE_REACH:=1.65
var game
var rows:Dictionary={}
var bodies:Dictionary={}
var models:Dictionary={}
var direct:Dictionary={}
var next_id:=0
var next_scan:=0.0
func setup(arena) -> void:game=arena
func equipped(id:int) -> bool:return game.classes.role(id)=="technician" and game.classes.ensure(id).get("equipped_utility","engineering")=="turret"
func body(key:int) -> StaticBody3D:
	if bodies.has(key):return bodies[key]
	var node:=StaticBody3D.new();node.name="TurretBody_%d"%key;node.collision_layer=1;node.collision_mask=0;node.set_meta("cq_turret",key)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(HALF*2,1.4,HALF*2);shape.shape=box;shape.position.y=.7;node.add_child(shape);add_child(node);bodies[key]=node
	return node
func owner_key(id:int) -> int:
	for key in rows:
		if rows[key].owner==id:return key
	return -1
func remove(key:int) -> void:
	rows.erase(key);direct.erase(key)
	if bodies.has(key):
		bodies[key].collision_layer=0;bodies[key].queue_free();bodies.erase(key)
	if models.has(key):models[key].queue_free();models.erase(key)
func excluded(id:int) -> Array[RID]:
	var key:=owner_key(id);var result:Array[RID]=[]
	if bodies.has(key):result.append(bodies[key].get_rid())
	return result
func surface(start:Vector3,end:Vector3,exclude:Array[RID]=[]) -> Dictionary:
	return Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(start,end,1,exclude),"query.turrets.surface.ray")
func site(id:int) -> Dictionary:
	if not game.classes.alive(id) or not game.fighters.has(id) or game.fighters[id].in_water:return {}
	var pose:Transform3D=game._weapon_transform(id);var start:Vector3=game.fighters[id].position+Vector3.UP*.6
	var ahead:Vector3=pose.origin-pose.basis.z*1.6;ahead.y=game.fighters[id].position.y+.3
	var ignore:=excluded(id)
	var center:=surface(ahead+Vector3.UP*.4,ahead-Vector3.UP*1.8,ignore)
	if center.is_empty() or center.normal.dot(Vector3.UP)<cos(deg_to_rad(8)) or center.position.distance_to(start)>2.8:return {}
	var point:Vector3=center.position;var highest:float=point.y
	# Full footprint must be supported: no slopes, cliff edges or narrow ledges.
	for x in [-HALF,HALF]:
		for z in [-HALF,HALF]:
			var p:=point+Vector3(x,0,z);var hit:=surface(p+Vector3.UP*.2,p-Vector3.UP*.2,ignore)
			if hit.is_empty() or hit.normal.dot(Vector3.UP)<cos(deg_to_rad(8)) or absf(hit.position.y-point.y)>.08:return {}
			highest=maxf(highest,hit.position.y)
	point.y=highest+.03
	if not surface(start,point+Vector3.UP*.7,ignore).is_empty():return {}
	var query:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(HALF*2,1.4,HALF*2);query.shape=box;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.71);query.collision_mask=3;query.exclude=ignore
	if not Attribution.shape(get_world_3d().direct_space_state,query,1,"query.turrets.site.shape").is_empty():return {}
	if game.battle_map and game.battle_map.Landscape.in_water(point):return {}
	var direction:=Vector3(-pose.basis.z.x,0,-pose.basis.z.z).normalized()
	if direction.length_squared()<.01:direction=Vector3.FORWARD
	return {"position":point,"direction":direction}
func deploy(id:int) -> bool:
	if not game.multiplayer.is_server() or not equipped(id) or not game.classes.alive(id) or game.classes.ensure(id).xp.technician<game.classes.progression.UTILITY_XP:return false
	if game.classes.ensure(id).get("turret_ready",0.0)>game.clock or game.lobby.active() or game.intermission>0 or game.players[id].get("input_blocked",false):return false
	var placement:=site(id)
	if placement.is_empty():return false # Invalid placement never spends cooldown/removes old turret.
	var old:=owner_key(id)
	if old>=0:remove(old)
	next_id+=1;rows[next_id]={"owner":id,"team":game.players[id].team,"position":placement.position,"direction":placement.direction,"hp":HP,"ammo":AMMO,"fire_at":game.clock,"shot_at":-100.0,"target":""}
	body(next_id).position=placement.position;game.classes.ensure(id)["turret_ready"]=game.clock+COOLDOWN
	return true
func muzzle(row:Dictionary) -> Vector3:return row.position+Vector3.UP*MUZZLE_HEIGHT+row.direction*MUZZLE_REACH
func clear_line(key:int,start:Vector3,target:Dictionary) -> bool:
	var ignore:Array[RID]=[]
	if bodies.has(key):ignore.append(bodies[key].get_rid())
	var hit:=surface(start,target.position,ignore)
	if hit.is_empty():return true
	var node=target.get("node")
	return is_instance_valid(node) and (node.owns_collider(hit.collider) if node.has_method("owns_collider") else hit.collider==node)
func target(key:int,vehicles:Dictionary) -> Dictionary:
	var row:Dictionary=rows[key];var origin:Vector3=row.position+Vector3.UP*MUZZLE_HEIGHT
	var best:Dictionary={};var distance:=INF
	for name in vehicles:
		var candidate:Dictionary=vehicles[name];var range_squared:float=row.position.distance_squared_to(candidate.position)
		if candidate.team==row.team or candidate.team not in [0,1] or range_squared>RANGE*RANGE or range_squared>=distance:continue
		if clear_line(key,origin,candidate):best={"name":name,"position":candidate.position,"node":candidate.node};distance=range_squared
	if not best.is_empty():return best
	for id in game.players:
		var s:Dictionary=game.players[id]
		if not game.classes.alive(id) or s.team==row.team or s.team not in [0,1] or game.classes.cloaked(id) or game.match_mode.fortress.walkers.mounted(id):continue
		var point:Vector3=game.fighters[id].position+Vector3.UP*minf(.8,game.fighters[id].collision_height*.5)
		var range_squared:float=row.position.distance_squared_to(game.fighters[id].position)
		var radius:float=RANGE*game.spotting.detection_scale(game,id)
		if range_squared>radius*radius or range_squared>=distance:continue
		var candidate:Dictionary={"name":"p:"+str(id),"position":point,"node":null}
		if clear_line(key,origin,candidate):best=candidate;distance=range_squared
	return best
func tick() -> void:
	if not game.multiplayer.is_server() or game.clock<next_scan:return
	next_scan=game.clock+.1
	var vehicles:Dictionary=game.variant_combat.vehicle_lock.targets(game)
	for key in rows.keys():
		var row:Dictionary=rows[key]
		if row.hp<=0 or row.ammo<=0:remove(key);continue
		var aim:=target(key,vehicles)
		row.target=aim.get("name","")
		if aim.is_empty():continue
		var pivot:Vector3=row.position+Vector3.UP*MUZZLE_HEIGHT;row.direction=(aim.position-pivot).normalized()
		var origin:=muzzle(row)
		if game.clock<row.fire_at or not clear_line(key,pivot,{"position":origin,"node":null}) or not clear_line(key,origin,aim):continue
		# A straight, unguided single shot; no salvo, player ammo or lock-on state.
		var shot:int=game.variant_combat.launch(row.owner,11,origin,row.direction,{"turret_shot":true,"cq_turret":key,"cq_team":row.team})
		if shot<0:continue
		row.ammo-=1;row.fire_at=game.clock+INTERVAL;row.shot_at=game.clock
		game._cq_turret_shot.rpc(origin,row.direction,row.team)
		if row.ammo<=0:remove(key)
func damage(key:int,attacker:int,amount:float,projectile:int=-1,kind:String="infantry") -> void:
	if not game.multiplayer.is_server() or not rows.has(key) or amount<=0 or game.intermission>0 or game.lobby.active():return
	var row:Dictionary=rows[key];var team:int=game.players.get(attacker,{}).get("team",-1)
	if attacker!=row.owner and team==row.team and not game.match_mode.friendly_fire and kind not in ["ordnance","grenade"]:return
	row.hp=maxi(0,row.hp-roundi(amount))
	if projectile>=0:direct[key]=projectile
	if row.hp<=0:remove(key)
func blast(where:Vector3,owner:int,damage_points:int,radius:float,quake:bool) -> void:
	for key in rows.keys():
		if game.variant_combat.active_projectile>=0 and direct.get(key,-1)==game.variant_combat.active_projectile:continue
		var row:Dictionary=rows[key];var point:Vector3=row.position+Vector3.UP*.7;var distance:float=where.distance_to(point)
		if distance>=radius or not clear_line(key,where,{"position":point,"node":null}):continue
		damage(key,owner,maxf(0,damage_points-distance*16) if quake else damage_points*(1-distance/radius),-1,"ordnance")
func receive(data:Dictionary,offset:float) -> void:
	rows=data.duplicate(true)
	for key in bodies.keys():
		if not rows.has(key):remove(key)
	for key in rows:
		var row:Dictionary=rows[key];row.fire_at+=offset;row.shot_at+=offset;body(key).position=row.position
func draw() -> void:
	if game.headless:return
	for key in rows:
		var row:Dictionary=rows[key]
		if not models.has(key):
			var node:Node3D=load("res://deathmatch/models/turret/turret.glb").instantiate();add_child(node);Lighting.convert_node(node);preload("res://deathmatch/conquest/classes/recon_drone.gd").prepare_model(node);models[key]=node
		models[key].position=row.position
		var aim:Node3D=models[key].find_child("Aim",true,false)
		if aim and row.direction.length_squared()>.001:aim.basis=Basis.looking_at(row.direction.normalized(),Vector3.UP)
func _process(_delta:float) -> void:
	if game and game.active:draw()
func reset() -> void:
	for key in rows.keys():remove(key)
	rows.clear();direct.clear();next_scan=0.0
