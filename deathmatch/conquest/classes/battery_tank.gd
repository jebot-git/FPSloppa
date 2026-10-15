extends Node3D
const Attribution=preload("res://deathmatch/server/attribution.gd")
## Shared authoritative rocket/light/heavy vehicle service; no AI or ammunition pool.
const Transport=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Hull=preload("res://deathmatch/conquest/classes/battery_hull.gd")
const Ballistics=preload("res://deathmatch/conquest/classes/ballistics.gd")
const MAX_RANGE:=5000.0
const SPEED:=sqrt(MAX_RANGE*20.0)
const FUSE:=90.0
const TRANSPORT_RESPAWN:=120.0
const TANK_RESPAWN:=180.0
const GRAVITY:=20.0
const INHERIT:=.5
const RELOAD:=30.0
const INTERVAL:=.15
const BARRAGE_RADIUS:=15.0 # Ground-space footprint, independent of range.
const FORWARD:=10.0
const REVERSE:=5.0
const TURN:=.65
const SIZE:=Vector3(4.5,1.7,4.8)
const PRIVATE_LAYER:=1<<19
const ROAD_MOBILITY:=1.25
const HOVER_HEIGHT:=.25
const MAX_HOVER_HEIGHT:=.5
const PROFILES={
	"rocket":{"name":"BATTERY TANK","hp":100,"size":SIZE,"forward":FORWARD,"reverse":REVERSE,"turn":TURN,"acceleration":4.0,"capacity":8,"reload":RELOAD,"interval":INTERVAL,"pair":1,"pitch_min":-89.0,"pitch_max":89.0,"pivot":Vector3(0,2.3,0),"length":2.65,"offset":.55,"model":"res://deathmatch/models/battery_tank/battery_tank.glb"},
	"light":{"name":"LIGHT TANK","hp":250,"size":Vector3(2.2,1.0,4.8),"forward":FORWARD,"reverse":REVERSE,"turn":TURN,"acceleration":4.0,"capacity":5,"reload":10.0,"interval":1.5,"pair":1,"pitch_min":-2.0,"pitch_max":35.0,"pivot":Vector3(0,.88044,1.30787),"length":3.46838,"offset":0.0,"model":"res://deathmatch/models/hover_tanks/light.glb"},
	"transport":{"name":"ALLIED TRANSPORT","hp":100,"size":Vector3(3.510538,2.820975,8),"forward":FORWARD,"reverse":REVERSE,"turn":TURN,"acceleration":4.0,"capacity":0,"reload":0.0,"interval":0.0,"pair":0,"pitch_min":0.0,"pitch_max":0.0,"pivot":Vector3.ZERO,"length":0.0,"offset":0.0,"model":"res://deathmatch/models/ground_transport/transport.glb"},
	"heavy":{"name":"HEAVY TANK","hp":500,"size":Vector3(3.2,1.2,5.8),"forward":6.0,"reverse":3.0,"turn":.35,"acceleration":2.5,"capacity":4,"reload":15.0,"interval":1.5,"pair":2,"pitch_min":-4.0,"pitch_max":25.0,"pivot":Vector3(0,1.06728,1.30121),"length":3.79844,"offset":.18,"model":"res://deathmatch/models/hover_tanks/heavy.glb"}}
static func profile(row:Dictionary) -> Dictionary:return PROFILES.get(row.get("kind","rocket"),PROFILES.rocket)
var game
var rows:Dictionary={}
var bodies:Dictionary={}
var models:Dictionary={}
var view
var next_helper:=0.0
var helper_points:=PackedVector3Array()
var helper_mesh:MeshInstance3D
func setup(arena) -> void:game=arena
static func placements() -> Array:
	var result:Array=[{"poi":"west ridge relay","position":Landscape.CENTERS[5]+Vector3(10,.08,-32),"yaw":PI,"team":-1,"kind":"rocket"},{"poi":"canyon crossing","position":Landscape.CENTERS[6]+Vector3(12,.08,-8),"yaw":0.0,"team":-1,"kind":"rocket"},
	{"poi":"military","position":Landscape.CENTERS[3]+Vector3(-62,.08,-45),"yaw":PI,"team":-1,"kind":"light"},
	{"poi":"military","position":Landscape.CENTERS[3]+Vector3(62,.08,-45),"yaw":PI,"team":-1,"kind":"light"},
	{"poi":"west ridge relay","position":Landscape.CENTERS[5]+Vector3(-26,.08,-32),"yaw":PI,"team":-1,"kind":"light"},
	{"poi":"canopy outpost","position":Landscape.CENTERS[8]+Vector3(-33,.08,26),"yaw":0.0,"team":-1,"kind":"light"},
	{"poi":"military","position":Landscape.CENTERS[3]+Vector3(50,.08,45),"yaw":0.0,"team":-1,"kind":"heavy"},
	{"poi":"radar","position":Landscape.CENTERS[4]+Vector3(41,.08,30),"yaw":0.0,"team":-1,"kind":"heavy"}]
	for spec in [[0,0,85.],[2,0,85.],[1,1,-85.],[3,1,-85.]]:
		var at:Vector3=Landscape.CENTERS[spec[0]]+Vector3(spec[2],0,0);at.y=Landscape.surface(at.x,at.z).x+.08
		result.append({"poi":Landscape.TYPES[spec[0]],"position":at,"yaw":PI*.5 if spec[1]==0 else -PI*.5,"team":spec[1],"kind":"transport"})
	return result
func reset() -> void:
	for row in rows.values():
		for id in occupants(row):unlock(id)
	for node in bodies.values()+models.values():
		if is_instance_valid(node):node.free()
	bodies.clear();models.clear();rows.clear();helper_points.clear();next_helper=0.0
	if view:view.deactivate()
func configure() -> void:
	reset()
	for i in placements().size():
		var p:Dictionary=placements()[i]
		rows[i]=spawn_row(p)
		body(i)
func spawn_row(p:Dictionary) -> Dictionary:
	return {"spawn":p.duplicate(),"respawn_at":0.0,"poi":p.poi,"position":p.position,"yaw":p.yaw,"team":p.team,"kind":p.kind,"hp":PROFILES[p.kind].hp,"pilot":0,"life":-1,"seats":[0,0,0,0,0,0,0,0],"seat_lives":[0,0,0,0,0,0,0,0],"jump_edges":{},"direction":Basis(Vector3.UP,p.yaw)*Vector3.FORWARD,"speed":0.0,"velocity":Vector3.ZERO,"left":0,"rounds":PROFILES[p.kind].capacity,"next":0.0,"reload_at":0.0,"shot_at":-100.0,"normal":Vector3.UP,"visual_y":p.position.y+(0.0 if p.kind in ["rocket","transport"] else HOVER_HEIGHT)}
func body(key:int):
	if bodies.has(key):return bodies[key]
	var node:=Hull.new();node.name="BatteryTank_%d"%key;node.service=self;node.key=key;node.collision_layer=1;node.collision_mask=1;node.floor_max_angle=deg_to_rad(30);node.floor_snap_length=.5;node.safe_margin=.02
	var config:=profile(rows[key]);var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=config.size;shape.shape=box;node.add_child(shape)
	var battery:=CollisionShape3D.new();battery.name="TurretCollision";var top:=BoxShape3D.new();top.size=Vector3(2.3,1.4,2.3) if rows[key].kind=="rocket" else Vector3(config.size.x*.7,.65,2.0);battery.shape=top;battery.position=Vector3(0,1.58,0) if rows[key].kind=="rocket" else Vector3(0,config.pivot.y+visual_origin(rows[key]).y-rows[key].position.y-config.size.y*.5,config.pivot.z);node.add_child(battery)
	if rows[key].kind=="transport":node.remove_child(battery);battery.free()
	add_child(node);node.add_to_group("cq_repairable_vehicles");bodies[key]=node
	pose_body(key);return node
func pose_body(key:int) -> void:
	var row:Dictionary=rows[key];bodies[key].position=row.position+Vector3.UP*(profile(row).size.y*.5+.02);bodies[key].rotation.y=row.yaw;bodies[key].collision_layer=1 if row.hp>0 else 0
	pose_turret_collider(key)
func visual_origin(row:Dictionary) -> Vector3:
	return Vector3(row.position.x,row.get("visual_y",row.position.y),row.position.z)
static func visual_basis(row:Dictionary) -> Basis:
	var normal:Vector3=row.get("normal",Vector3.UP)
	var forward:Vector3=Basis(Vector3.UP,row.yaw)*Vector3.FORWARD
	var right:=forward.cross(normal).normalized()
	return Basis(right,normal,-normal.cross(right).normalized())
func update_clearance(key:int) -> void:
	var token:=Attribution.begin("vehicle.clearance")
	_attributed_update_clearance(key)
	Attribution.end(token)

func _attributed_update_clearance(key:int) -> void:
	var row:Dictionary=rows[key];var height:float=0.0 if row.kind in ["rocket","transport"] else HOVER_HEIGHT
	row.visual_y=row.position.y+height;row.normal=Vector3.UP
	# Fit the rendered hull to its actual supporting floor, including structure floors.
	# Gravity still governs airborne falls; never snap down onto a distant floor.
	if bodies[key].is_on_floor():
		var excludes:Array[RID]=[]
		for node in bodies.values():excludes.append(node.get_rid())
		var hit:=Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(row.position+Vector3.UP*.6,row.position-Vector3.UP*6,1,excludes),"query.battery_tank.update_clearance.ray")
		if not hit.is_empty():row.visual_y=hit.position.y+minf(height,MAX_HOVER_HEIGHT);row.normal=hit.normal
	pose_turret_collider(key)
func pose_turret_collider(key:int) -> void:
	var row:Dictionary=rows[key]
	if row.kind=="transport":return
	if row.kind=="rocket" and row.get("normal",Vector3.UP)==Vector3.UP:
		bodies[key].get_node("TurretCollision").position=Vector3(0,1.58,0);return
	var config:=profile(row)
	var point:Vector3=visual_origin(row)+visual_basis(row)*config.pivot
	bodies[key].get_node("TurretCollision").position=Basis(Vector3.UP,-row.yaw)*(point-bodies[key].position)
static func occupants(row:Dictionary)->Array:
	return row.get("seats",[]).filter(func(id):return id!=0) if row.get("kind","")=="transport" else ([row.pilot] if row.pilot!=0 else [])
func seat_index(id:int,key:int)->int:return rows[key].get("seats",[]).find(id) if rows[key].kind=="transport" else -1
func passenger_position(id:int,key:int)->Vector3:
	var row:Dictionary=rows[key];var index:=seat_index(id,key)
	return visual_origin(row)+visual_basis(row)*Transport.point(index,"seat") if index>=0 else row.position
func mounted(id:int) -> bool:return key_for(id)>=0
func key_for(id:int) -> int:
	for key in rows:
		if id!=0 and occupants(rows[key]).has(id):return key
	return -1
func use(id:int) -> bool:
	if not multiplayer.is_server() or not game.classes.alive(id) or game.lobby.active() or game.intermission>0 or game.players[id].get("input_blocked",false) or game.clock<game.players[id].use_at:return false
	var key:=key_for(id)
	if key>=0:
		var aboard:Dictionary=rows[key]
		if aboard.kind=="transport":
			var current:=seat_index(id,key)
			if current!=6 and aboard.seats[6]==0:
				aboard.seats[current]=0;aboard.seat_lives[current]=0;aboard.seats[6]=id;aboard.seat_lives[6]=game.players[id].serial;aboard.pilot=id;aboard.life=game.players[id].serial;seat(id,key);game.players[id].use_at=game.clock+.5;return true
			return false
		if not leave(id):return false
		game.players[id].use_at=game.clock+.5;return true
	var nearest:=4.5;var chosen:=-1;var pod:=-1
	for k in rows:
		var row:Dictionary=rows[k];var distance:float=game.fighters[id].position.distance_to(row.position)
		if row.hp<=0:continue
		if row.kind=="transport":
			if row.team!=game.players[id].team:continue
			for i in 8:
				if row.seats[i]!=0:continue
				var entry:Vector3=row.position+Basis(Vector3.UP,row.yaw)*Transport.point(i,"entry");var reach:float=game.fighters[id].position.distance_to(entry)
				if reach>Transport.data().entry_radius or reach>nearest:continue
				var sight:=PhysicsRayQueryParameters3D.create(game.fighters[id].position+Vector3.UP*.8,entry+Vector3.UP*.8,1,[bodies[k].get_rid()])
				if not Attribution.ray(get_world_3d().direct_space_state,sight,"query.transport.entry.ray").is_empty():continue
				nearest=reach;chosen=k;pod=i
			continue
		if row.pilot!=0 or distance>nearest:continue
		var ray:=PhysicsRayQueryParameters3D.create(game.fighters[id].position+Vector3.UP*.8,row.position+Vector3.UP,1,[bodies[k].get_rid()])
		if not Attribution.ray(get_world_3d().direct_space_state,ray,"query.battery_tank.use.ray").is_empty():continue
		nearest=distance;chosen=k;pod=-1
	if chosen<0:return false
	var row:Dictionary=rows[chosen]
	if row.kind=="transport":
		row.seats[pod]=id;row.seat_lives[pod]=game.players[id].serial;row.jump_edges[id]=game.players[id].get("jump",false)
		if pod==6:row.pilot=id;row.life=game.players[id].serial
	else:row.pilot=id;row.life=game.players[id].serial;row.team=game.players[id].team
	game.classes.weapon_used(id);game.airstrike.cancel(id);game.grenades.cancel(id);game.variant_combat.cancel_player(id)
	game.players[id]["battery_saved_layer"]=game.fighters[id].collision_layer
	game.fighters[id].collision_layer=0;seat(id,chosen);game.players[id].use_at=game.clock+.5;return true
func seat(id:int,key:int) -> void:
	if not game.fighters.has(id):return
	game.fighters[id].vehicle_seated=true;game.fighters[id].position=passenger_position(id,key);game.fighters[id].velocity=Vector3.ZERO;game.fighters[id].blast_velocity=Vector2.ZERO;game.fighters[id].collision_layer=0
func unlock(id:int) -> void:
	if not game.fighters.has(id) or not game.players.has(id):return
	game.fighters[id].vehicle_seated=false
	game.fighters[id].collision_layer=0 if game.players[id].dead or game.players[id].spectator else int(game.players[id].get("battery_saved_layer",2));game.players[id].erase("battery_saved_layer");game.fighters[id].velocity=Vector3.ZERO
	if is_instance_valid(game.fighters[id].avatar):game.fighters[id].avatar.visible=true
func exit_site(id:int,key:int) -> Vector3:
	var row:Dictionary=rows[key];var space:=get_world_3d().direct_space_state
	var exits:Array=[Vector3(3.2,0,0),Vector3(-3.2,0,0),Vector3(0,0,3.5),Vector3(0,0,-3.5),Vector3(4.2,0,2),Vector3(-4.2,0,2)]
	if row.kind=="transport":
		var door:=Transport.point(seat_index(id,key),"entry");exits.push_front(door+Vector3(signf(door.x)*.8,0,0));exits.push_front(door);exits.append_array([Vector3(0,0,5),Vector3(0,0,-5)])
	for local in exits:
		var point:Vector3=row.position+Basis(Vector3.UP,row.yaw)*local
		var hit:=Attribution.ray(space,PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*3,1,[bodies[key].get_rid()]),"query.battery_tank.exit_site.ray")
		if hit.is_empty() or hit.normal.y<.8:continue
		point=hit.position+Vector3.UP*.08
		if Landscape.in_water(point):continue
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.7;query.shape=capsule;query.transform.origin=point+Vector3.UP*.88;query.collision_mask=3;query.exclude=[bodies[key].get_rid(),game.fighters[id].get_rid()]
		if Attribution.shape(space,query,1,"query.battery_tank.exit_site.shape").is_empty():return point
	return Vector3.INF
func leave(id:int,forced:bool=false) -> bool:
	var key:=key_for(id)
	if key<0:return false
	var point:=exit_site(id,key)
	if not point.is_finite() and not forced:return false
	if not point.is_finite():point=rows[key].position+Vector3.UP*2.5
	var row:Dictionary=rows[key]
	if row.kind=="transport":
		var i:=seat_index(id,key);row.seats[i]=0;row.seat_lives[i]=0;row.jump_edges.erase(id)
		if row.pilot==id:
			row.pilot=0;row.life=-1

	else:row.pilot=0;row.life=-1
	if row.pilot==0:row.speed=0.0;row.velocity=Vector3.ZERO;row.left=0
	unlock(id)
	if game.fighters.has(id):game.fighters[id].position=point;game.fighters[id].reset_view();game.fighters[id].jump_held=game.players[id].get("jump",false)
	return true
func direction(id:int) -> Vector3:
	# Validated weapon-hand pose; clamp barrel pitch without changing aim azimuth.
	var raw:Vector3=-game._weapon_transform(id).basis.z.normalized()
	var key:=key_for(id)
	if key<0 or rows[key].kind=="rocket":return raw
	var config:=profile(rows[key]);var frame:=visual_basis(rows[key]);raw=frame.inverse()*raw
	var pitch:=clampf(asin(clampf(raw.y,-1,1)),deg_to_rad(config.pitch_min),deg_to_rad(config.pitch_max))
	var horizontal:=Vector3(raw.x,0,raw.z).normalized()
	if horizontal.length_squared()<.1:horizontal=Vector3.FORWARD
	return frame*(horizontal*cos(pitch)+Vector3.UP*sin(pitch))
func pivot(row:Dictionary) -> Vector3:return visual_origin(row)+visual_basis(row)*profile(row).pivot
func muzzle(row:Dictionary,shot:int=0) -> Vector3:
	var config:=profile(row);var side:Vector3=row.direction.cross(row.get("normal",Vector3.UP)).normalized();return pivot(row)+row.direction*config.length+side*(config.offset if shot%2==0 else -config.offset)
func start_salvo(key:int) -> bool:
	var row:Dictionary=rows[key];var id:int=row.pilot
	if row.kind=="transport":return false
	if id==0 or row.left>0 or game.clock<row.reload_at or game.clock<row.next or not game.classes.alive(id):return false
	if row.kind!="rocket":return fire_volley(key)
	var space:=get_world_3d().direct_space_state;var pivot:Vector3=pivot(row)
	if not Attribution.ray(space,PhysicsRayQueryParameters3D.create(pivot,muzzle(row),1,[bodies[key].get_rid()]),"query.battery_tank.start_salvo.ray").is_empty():return false
	var impact:=barrage_impact(key)
	row.barrage_center=impact.position;row.barrage_time=impact.time;row.barrage_phase=randf()*TAU
	row.left=8;row.next=game.clock;return true
func barrage_impact(key:int) -> Dictionary:
	# Predict once per salvo against the actual map, not the scout marker. No homing.
	var row:Dictionary=rows[key];var origin:=muzzle(row);var velocity:Vector3=row.direction*SPEED+row.velocity*INHERIT
	var space:=get_world_3d().direct_space_state;var previous:=origin
	for i in range(1,361):
		var time:=i*.25;var point:=origin+velocity*time-Vector3.UP*GRAVITY*time*time*.5
		var hit:=Attribution.ray(space,PhysicsRayQueryParameters3D.create(previous,point,1,[bodies[key].get_rid()]),"query.battery_tank.barrage_impact.ray")
		if not hit.is_empty():
			var fraction:float=previous.distance_to(hit.position)/maxf(previous.distance_to(point),.001)
			return {"position":hit.position,"time":maxf(.1,time-.25+.25*fraction)}
		previous=point
	# Open map edges retain the trajectory's descending intersection with launch ground.
	var flight:float=(velocity.y+sqrt(maxf(0,velocity.y*velocity.y+2*GRAVITY*(origin.y-row.position.y))))/GRAVITY
	flight=maxf(.1,flight)
	return {"position":origin+velocity*flight-Vector3.UP*GRAVITY*flight*flight*.5,"time":flight}
static func barrage_solution(origin:Vector3,center:Vector3,flight:float,inherited:Vector3,offset:Vector3) -> Dictionary:
	# Keep the 5 km launch speed and select the same low/high arc as the original aim.
	# At maximum range, reduce dispersion until the target is ballistically reachable.
	for attempt in 6:
		var target:=center+offset*pow(.5,attempt)
		var low:=Ballistics.solve(origin,target,SPEED,GRAVITY,inherited)
		var high:=Ballistics.solve(origin,target,SPEED,GRAVITY,inherited,true)
		var solution:Dictionary=low if high.is_empty() or (not low.is_empty() and absf(low.time-flight)<=absf(high.time-flight)) else high
		if not solution.is_empty():solution.target=target;return solution
	# A moving hull can make the locked footprint unreachable at fixed launch speed.
	# Preserve the footprint and unguided arc with a small launch-speed adjustment.
	var target:=center+offset/32.0
	return {"velocity":(target-origin)/flight+Vector3.UP*GRAVITY*flight*.5,"time":flight,"target":target}
func barrage_round(row:Dictionary,origin:Vector3,shot:int) -> Dictionary:
	# One point per angular sector avoids eight random rockets clustering together.
	var angle:float=row.barrage_phase+TAU*(shot+randf()*.6)/8.0
	var radius:=BARRAGE_RADIUS*sqrt(randf_range(.16,1.0))
	var offset:=Vector3(cos(angle),0,sin(angle))*radius
	return barrage_solution(origin,row.barrage_center,row.barrage_time,row.velocity*INHERIT,offset)
func fire_volley(key:int) -> bool:
	var row:Dictionary=rows[key];var config:=profile(row)
	if row.rounds<=0:row.rounds=config.capacity
	if game.projectiles.size()+config.pair>game.variant_combat.MAX_PROJECTILES:return false
	var origins:Array=[]
	for barrel in config.pair:
		var origin:=muzzle(row,barrel)
		if not Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(pivot(row),origin,1,[bodies[key].get_rid()]),"query.battery_tank.fire_volley.ray").is_empty():return false
		origins.append(origin)
	for origin in origins:
		game.variant_combat.launch(row.pilot,11,origin,row.direction,{"hover_shot":row.kind,"turret_shot":true,"cq_team":row.team,"launch_velocity":row.direction*40.0+row.velocity*INHERIT})
		game._cq_turret_shot.rpc(origin,row.direction,row.team)
	row.rounds-=1;row.next=game.clock+config.interval;row.shot_at=game.clock
	if row.rounds==0:row.reload_at=game.clock+config.reload
	return true
static func mobility_at(point:Vector3) -> float:
	var token:=Attribution.begin("vehicle.terrain_mobility")
	var result:float=_attributed_mobility_at(point)
	Attribution.end(token)
	return result

static func _attributed_mobility_at(point:Vector3) -> float:
	if not Landscape.is_road(point.x,point.z):return 1.0
	# A structure floor above a road isn't road terrain.
	return ROAD_MOBILITY if absf(point.y-Landscape.surface(point.x,point.z).x)<1.0 else 1.0
static func water_contact(row:Dictionary) -> bool:
	var token:=Attribution.begin("vehicle.water_contact")
	var result:bool=_attributed_water_contact(row)
	Attribution.end(token)
	return result

static func _attributed_water_contact(row:Dictionary) -> bool:
	var size:Vector3=profile(row).size;var frame:=visual_basis(row)
	for point in [Vector3.ZERO,Vector3(size.x*.5,0,size.z*.5),Vector3(-size.x*.5,0,size.z*.5),Vector3(size.x*.5,0,-size.z*.5),Vector3(-size.x*.5,0,-size.z*.5)]:
		if Landscape.in_water(row.position+frame*point):return true
	return false
func tick(delta:float) -> void:
	if not multiplayer.is_server():return
	for key in rows:
		var row:Dictionary=rows[key];var config:=profile(row);var id:int=row.pilot
		if row.hp<=0:
			if row.get("respawn_at",0.0)>0.0 and game.clock+1e-9>=row.respawn_at:
				rows[key]=spawn_row(row.spawn)
				bodies[key].velocity=Vector3.ZERO
				pose_body(key)
			continue
		if row.kind=="transport":
			for rider in occupants(row):
				var i:=seat_index(rider,key)
				if not game.classes.alive(rider) or game.players[rider].serial!=row.seat_lives[i] or game.players[rider].team!=row.team:leave(rider,true);continue
				var jump:bool=game.players[rider].get("jump",false)
				if jump and not row.jump_edges.get(rider,false) and not game.players[rider].get("input_blocked",false):leave(rider)
				row.jump_edges[rider]=jump
			id=row.pilot
		if id!=0 and (not game.classes.alive(id) or game.players[id].serial!=row.life):leave(id,true);id=0
		var move:=Vector2.ZERO;var valid:=false
		if id!=0:
			var s:Dictionary=game.players[id];valid=not s.get("input_blocked",false) and game.clock-s.last_input<=.35 and (not s.vr_device or not s.xr.is_empty())
			if valid:move=s.move
		var old:Vector3=row.position;var node=bodies[key];var mobility:=mobility_at(row.position)
		row.speed=move_toward(row.speed,-move.y*(config.forward if move.y<0 else config.reverse)*mobility,delta*config.acceleration*mobility)
		row.yaw-=move.x*config.turn*mobility*delta
		node.rotation.y=row.yaw
		var horizontal:Vector3=Basis(Vector3.UP,row.yaw)*Vector3.FORWARD*row.speed
		# Retain the map boundary; water entry is fatal instead of an invisible barrier.
		var next:Vector3=row.position+horizontal*delta
		if absf(next.x)>Landscape.EXTENT*.5-4 or absf(next.z)>Landscape.EXTENT*.5-4:horizontal=Vector3.ZERO;row.speed=0.0
		node.velocity=Vector3(horizontal.x,node.velocity.y-GRAVITY*delta,horizontal.z)
		var slide_scope:=Attribution.begin("query.vehicle.slide")
		node.move_and_slide();Attribution.end(slide_scope)
		row.position=node.position-Vector3.UP*(profile(row).size.y*.5+.02);row.velocity=(row.position-old)/maxf(delta,.001);update_clearance(key)
		if water_contact(row):destroy(key,0,"VEHICLE DROWNED");continue
		if id!=0:
			if valid:row.direction=direction(id)
			for rider in occupants(row):seat(rider,key)
			crush(key,old,row.position)
			if row.kind!="transport" and valid and game.players[id].fire:start_salvo(key)
		if row.left>0 and game.clock>=row.next:
			var origin:=muzzle(row,8-row.left);var pivot:Vector3=pivot(row)
			if not Attribution.ray(get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(pivot,origin,1,[node.get_rid()]),"query.battery_tank.tick.ray").is_empty():continue
			var solution:=barrage_round(row,origin,8-row.left)
			var velocity:Vector3=solution.velocity;var aim:Vector3=(velocity-row.velocity*INHERIT).normalized()
			var shot:int=game.variant_combat.launch(id,5,origin,aim,{"battery_shot":true,"cq_team":row.team,"launch_velocity":velocity,"barrage_center":row.barrage_center,"barrage_target":solution.target,"barrage_time":solution.time})
			if shot>=0:
				row.left-=1;row.next=game.clock+INTERVAL;row.shot_at=game.clock;game._cq_turret_shot.rpc(origin,aim,row.team)
				if row.left==0:row.reload_at=game.clock+RELOAD
func crush(key:int,start:Vector3,end:Vector3) -> void:
	var row:Dictionary=rows[key]
	if absf(row.speed)<1.0:return
	for id in game.players:
		var s:Dictionary=game.players[id]
		if id==row.pilot or mounted(id) or s.dead or s.spectator or (game.classes.downed.has(id) and row.kind!="heavy") or s.invulnerable>game.clock or (s.team==row.team and not game.match_mode.friendly_fire):continue
		var point:Vector3=game.fighters[id].position;var closest:=Geometry3D.get_closest_point_to_segment(point,start,end);var local:Vector3=Basis(Vector3.UP,-row.yaw)*(point-closest)
		if absf(local.x)>profile(row).size.x*.5+.3 or absf(local.z)>profile(row).size.z*.5+.3 or local.y<-.4 or local.y>1.7:continue
		var ray:=PhysicsRayQueryParameters3D.create(closest+Vector3.UP*.8,point+Vector3.UP*.8,1,[bodies[key].get_rid()])
		if not Attribution.ray(get_world_3d().direct_space_state,ray,"query.battery_tank.crush.ray").is_empty():continue
		game._damage(id,row.pilot,10000,"HEAVY TANK CRUSH" if row.kind=="heavy" else "BATTERY RUNOVER",false,point,row.velocity.normalized())
func destroy(key:int,attacker:int=0,reason:String="VEHICLE DESTROYED") -> void:
	if not multiplayer.is_server() or not rows.has(key):return
	var row:Dictionary=rows[key]
	if row.get("respawn_at",0.0)>0.0:return
	row.respawn_at=game.clock+(TRANSPORT_RESPAWN if row.kind=="transport" else TANK_RESPAWN)
	var riders:Array=occupants(row)
	row.hp=0;row.left=0;row.rounds=0;row.speed=0.0;row.velocity=Vector3.ZERO;bodies[key].velocity=Vector3.ZERO;bodies[key].collision_layer=0
	for pilot in riders:
		# Release camera/avatar/collider state first, then kill at the wreck position.
		leave(pilot,true)
		if game.players.has(pilot) and not game.players[pilot].dead:
			game.fighters[pilot].position=row.position
			var source:int=attacker if game.players.has(attacker) else pilot
			game._damage(pilot,source,10000,reason,true,row.position+Vector3.UP,Vector3.UP,true)
func damage(key:int,team:int,amount:int,kind:String,attacker:int=0) -> int:
	if not multiplayer.is_server() or not rows.has(key) or amount<=0 or game.intermission>0 or game.lobby.active():return 0
	var row:Dictionary=rows[key]
	if row.hp<=0 or kind not in ["ordnance","grenade"] or (team==row.team and not game.match_mode.friendly_fire):return 0
	var dealt:int=mini(row.hp,roundi(amount*(.5 if kind=="grenade" else 1.0)));row.hp-=dealt
	if row.hp==0:destroy(key,attacker)
	return dealt
func blast(where:Vector3,team:int,amount:int,radius:float,kind:String,quake:bool=false,projectile:int=-1,attacker:int=0) -> void:
	for key in rows:
		if rows[key].hp<=0 or projectile>=0 and bodies[key].get_meta("cq_direct_projectile",-1)==projectile:continue
		var point:Vector3=bodies[key].global_position;var distance:float=where.distance_to(point)
		if distance>=radius:continue
		var ray:=PhysicsRayQueryParameters3D.create(where+Vector3.UP*.04,point,1,[bodies[key].get_rid()])
		if not Attribution.ray(get_world_3d().direct_space_state,ray,"query.battery_tank.blast.ray").is_empty():continue
		damage(key,team,maxi(0,roundi(amount-distance*16 if quake else amount*(1-distance/radius))),kind,attacker)
func receive(data:Dictionary,offset:float) -> void:
	var prior:Array=[]
	for row in rows.values():prior.append_array(occupants(row))
	for key in bodies.keys():
		if not data.has(key) or rows[key].kind!=data[key].kind:bodies[key].free();bodies.erase(key)
	for key in models.keys():
		if not data.has(key) or rows[key].kind!=data[key].kind:models[key].free();models.erase(key)
	rows=data.duplicate(true)
	for key in rows:
		rows[key].next+=offset;rows[key].reload_at+=offset;rows[key].shot_at+=offset;body(key);pose_body(key)
		for id in occupants(rows[key]):seat(id,key)
	for id in prior:
		if id!=0 and not mounted(id):unlock(id)
func draw() -> void:
	if game.headless:return
	for key in rows:
		var row:Dictionary=rows[key]
		if not models.has(key):
			var node:=Node3D.new();var hull:Node3D=load(profile(row).model).instantiate();node.add_child(hull);normalise_model(hull);add_child(node);preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(node);preload("res://deathmatch/conquest/classes/recon_drone.gd").prepare_model(node)
			if row.kind=="transport":Transport.prepare_windows(node);Transport.prepare_seats(node)
			models[key]=node
		models[key].position=visual_origin(row);models[key].basis=visual_basis(row);models[key].visible=row.hp>0
		var yaw_node:Node3D=models[key].find_child("Yaw",true,false)
		if yaw_node:
			var normal:Vector3=row.get("normal",Vector3.UP);yaw_node.global_basis=Basis.looking_at((row.direction-normal*row.direction.dot(normal)).normalized(),normal)
		var aim:Node3D=models[key].find_child("Aim",true,false)
		if aim:aim.global_basis=Basis.looking_at(row.direction,row.get("normal",Vector3.UP) if absf(row.direction.dot(row.get("normal",Vector3.UP)))<.99 else Vector3.RIGHT)
	for id in game.fighters:
		if mounted(id) and is_instance_valid(game.fighters[id].avatar):game.fighters[id].avatar.hide()
	if not view:view=preload("res://deathmatch/conquest/classes/battery_view.gd").new();add_child(view);view.setup(game,self)
	draw_helper();view.update()
func helper(id:int) -> Dictionary:
	var key:=key_for(id)
	if key<0 or rows[key].kind!="rocket" or game.classes.role(id)!="technician" or not game.classes.alive(id):return {}
	var row:Dictionary=rows[key];var origin:=muzzle(row,8-row.left);var best:Dictionary={};var score:=-2.0
	for scout in game.designations:
		var target:Dictionary=game.designations[scout]
		if game.classes.role(scout)!="scout" or target.until<game.clock or target.team!=row.team:continue
		var alignment:float=row.direction.dot((target.position-origin).normalized())
		if alignment>score:best=target;score=alignment
	if best.is_empty():return {}
	for high in [false,true]:
		var aim_row:=row.duplicate();var solution:Dictionary={}
		# The muzzle moves as the barrel turns; converge the aid on its aimed origin.
		for iteration in 6:
			origin=muzzle(aim_row,0)
			solution=Ballistics.solve(origin,best.position,SPEED,GRAVITY,row.velocity*INHERIT,high)
			if solution.is_empty():break
			aim_row.direction=solution.direction
		if solution.is_empty() or not Ballistics.clear(get_world_3d().direct_space_state,origin,solution,GRAVITY):continue
		solution["origin"]=origin;solution["target"]=best.position;return solution
	return {}
func draw_helper() -> void:
	if game.clock>=next_helper:
		next_helper=game.clock+.1;helper_points.clear()
		var solution:=helper(game.multiplayer.get_unique_id())
		if not solution.is_empty():
			var previous:Vector3=solution.origin
			for i in 25:
				var t:float=solution.time*(i+1)/25;var point:Vector3=solution.origin+solution.velocity*t-Vector3.UP*GRAVITY*t*t*.5;helper_points.append(previous);helper_points.append(point);previous=point
			var aim:Vector3=solution.origin+solution.direction*8
			var side:Vector3=solution.direction.cross(Vector3.UP).normalized()*.12
			helper_points.append_array(PackedVector3Array([aim-side,aim+side,aim-Vector3.UP*.12,aim+Vector3.UP*.12]))
	if not helper_points.is_empty() or is_instance_valid(helper_mesh):helper_mesh=game.line_visual(helper_points,Color(.4,1,.8,.8),helper_mesh)

static func normalise_model(model:Node3D) -> AABB:
	var bounds:=AABB();var first:=true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var frame:=Transform3D.IDENTITY;var node:Node=mesh
		while node!=model:
			frame=node.transform*frame;node=node.get_parent()
		var box:AABB=frame*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	if not first:model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	return bounds
