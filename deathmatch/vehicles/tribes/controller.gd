extends Node
## Server owns purchases, hulls, seats, flight, projectiles and all damage.
const Data=preload("res://deathmatch/vehicles/tribes/scout_data.gd")
const Hit=preload("res://deathmatch/hit_detection.gd")
var rules
var game
var rows: Dictionary={}
var bodies: Dictionary={}
var rockets: Dictionary={}
var next_id:=1
var next_rocket:=1
var locks: Dictionary={}
var requests: Dictionary={}
var impact_locks: Dictionary={}
var view
var render_motion=preload("res://deathmatch/vehicles/tribes/render_motion.gd").new()
var render_frames: Dictionary={}
var render_frame_number:=-1
func setup(value):rules=value;game=rules.game
func active() -> bool:return rules.enabled() and rules.mode.kind=="st"
func frame(row: Dictionary) -> Transform3D:return Transform3D(Basis(Vector3.UP,row.yaw),row.position)
func definition(row: Dictionary) -> Dictionary:return Data.definition(row.get("kind","scout"))
func seat_frame(row: Dictionary) -> Transform3D:
	var pose:=frame(row);pose.basis*=Basis(Vector3.RIGHT,row.pitch)*Basis(Vector3.FORWARD,row.bank);return pose
func occupants(row: Dictionary) -> Array:return [row.pilot]+row.get("passengers",[])
func seat_for(id: int,row: Dictionary) -> int:return occupants(row).find(id) if id!=0 else -1
func transport_pilot(id: int) -> bool:
	var key:=vehicle_for(id)
	return key!=0 and rows[key].pilot==id and rows[key].get("kind","scout") in ["lpc","hpc"]
func seat_position(row: Dictionary,slot: int) -> Vector3:return seat_frame(row)*definition(row).seats[slot]
func render_frame(key: int) -> Transform3D:
	# Whichever draws first (XR rig, avatar or hull) samples this render frame once.
	var number:=Engine.get_process_frames()
	if number!=render_frame_number:render_frames.clear();render_frame_number=number
	if not render_frames.has(key):
		var stamp: float
		if game.demos.playing:stamp=game.demos.render_time()
		elif game.multiplayer.is_server():stamp=game.clock-get_physics_process_delta_time()*(1.0-Engine.get_physics_interpolation_fraction())
		else:stamp=render_motion.advance(Time.get_ticks_usec()/1000000.0)
		render_frames[key]=render_motion.sample(key,stamp,seat_frame(rows[key]))
	return render_frames[key]
func render_seat_position(id: int) -> Vector3:
	var key:=vehicle_for(id)
	if key==0:return Vector3.INF
	return render_frame(key)*definition(rows[key]).seats[seat_for(id,rows[key])]
func mounted(id: int) -> bool:return vehicle_for(id)>0
func piloting(id: int) -> bool:
	var key:=vehicle_for(id);return key>0 and rows[key].pilot==id
func vehicle_for(id: int) -> int:
	if id==0:return 0
	for key in rows:if id in occupants(rows[key]):return key
	return 0
func eligible(id: int,inventory: bool=false) -> bool:
	return not rules.operating(id) and active() and game.active and not game.map_loading and game.intermission<=0 and game.players.has(id) and game.fighters.has(id) and not game.players[id].dead and not game.players[id].spectator and (inventory or not game.players[id].get("input_blocked",false)) and not rules.mode.special.blocked(id)
func station(id: int) -> int:
	var pads=rules.stations()
	return pads.at(id,["vehicle"]) if pads and eligible(id,true) and not mounted(id) else -1
func count(team: int,kind: String="scout") -> int:return rows.values().filter(func(row):return row.owner_team==team and row.get("kind","scout")==kind).size()
func spawn_frame(index: int) -> Transform3D:
	var pad: Dictionary=rules.stations().rows[index]
	var pose: Transform3D=pad.frame
	pose.origin=pad.get("vehicle_spawn",pose*Vector3(0,1.4,-8))
	return pose
func clear_volume(pose: Transform3D,half: Vector3,exclude: Array[RID]=[]) -> bool:
	var q:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=half*2;q.shape=shape;q.transform=pose;q.collision_mask=3;q.exclude=exclude
	return game.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
func purchase(id: int,epoch: int,life: int,kind: String="scout") -> bool:
	if kind not in Data.KINDS:return false
	var d:=Data.definition(kind)
	if not multiplayer.is_server() or not eligible(id,true) or epoch!=game.map_epoch or life!=game.players[id].serial or game.clock<float(requests.get(id,0)):return false
	requests[id]=game.clock+.5
	var index:=station(id)
	if index<0 or rules.balance(id)<d.price or count(game.players[id].team,kind)>=Data.TEAM_LIMIT or rows.size()>=Data.MAX_VEHICLES:return false
	var pose:=spawn_frame(index)
	if not clear_volume(pose,d.half+Vector3.ONE*.15):return false
	# Reserve synchronously before spending: duplicate RPCs cannot overlap hulls.
	var key:=next_id;next_id+=1
	rows[key]={"position":pose.origin,"velocity":Vector3.ZERO,"yaw":pose.basis.get_euler().y,"pitch":0.0,"bank":0.0,"kind":kind,"passengers":[],"passenger_lives":[],"hp":d.hp,"pilot":0,"life":-1,"team":game.players[id].team,"owner_team":game.players[id].team,"ready":game.clock+3.0,"next_fire":0.0,"idle_until":game.clock+120.0}
	rows[key].passengers.resize(d.seats.size()-1);rows[key].passengers.fill(0)
	rows[key].passenger_lives.resize(d.seats.size()-1);rows[key].passenger_lives.fill(-1)
	make_body(key);rules.spend(id,d.price)
	return true
func make_body(key: int):
	if bodies.has(key) and is_instance_valid(bodies[key]):return
	var body:=CharacterBody3D.new();body.name="TribesVehicle%d"%key;body.collision_layer=1;body.collision_mask=3;body.set_meta("st_scout",key)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=definition(rows[key]).half*2;shape.shape=box;body.add_child(shape)
	game.add_child(body);body.global_transform=frame(rows[key]);bodies[key]=body
func reachable(id: int,key: int,slot: int) -> bool:
	var seat:=seat_position(rows[key],slot)
	if game.fighters[id].position.distance_to(seat)>3.6:return false
	var ray:=PhysicsRayQueryParameters3D.create(game.fighters[id].position+Vector3.UP,seat+Vector3.UP,1,[bodies[key].get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func board(id: int,key: int,slot: int=-1) -> bool:
	if not multiplayer.is_server() or not eligible(id) or not rows.has(key) or mounted(id) or game.clock<float(locks.get(id,0)):return false
	var s: Dictionary=game.players[id];var row: Dictionary=rows[key]
	if rules.mode.st.carried(id)>=0 or row.ready>game.clock:return false
	var seats:=occupants(row)
	if slot<0:
		if s.tribes_class=="light" and row.pilot==0 and reachable(id,key,0):slot=0
		else:
			var distance:=INF
			for i in range(1,seats.size()):
				var near: float=game.fighters[id].position.distance_squared_to(seat_position(row,i))
				if seats[i]==0 and near<distance and reachable(id,key,i):slot=i;distance=near
	if slot<0 or slot>=seats.size() or seats[slot]!=0 or slot==0 and s.tribes_class!="light" or not reachable(id,key,slot):return false
	if slot==0:row.pilot=id;row.life=s.serial;row.team=s.team
	else:row.passengers[slot-1]=id;row.passenger_lives[slot-1]=s.serial
	row.idle_until=game.clock+120
	bodies[key].add_collision_exception_with(game.fighters[id]);game.fighters[id].add_collision_exception_with(bodies[key])
	game.fighters[id].prediction.clear();s.fire=false;s.fire_pending=[];rules.combat.cancel(id)
	game.fighters[id].jump_held=s.jump
	pin(key);return true
func use(id: int) -> bool:
	if not multiplayer.is_server() or not eligible(id):return false
	if mounted(id):leave(id);return true
	var nearby: Array=rows.keys().filter(func(key):return definition(rows[key]).seats.any(func(seat):return game.fighters[id].position.distance_to(seat_frame(rows[key])*seat)<3.6))
	nearby.sort_custom(func(a,b):return game.fighters[id].position.distance_squared_to(rows[a].position)<game.fighters[id].position.distance_squared_to(rows[b].position))
	for key in nearby:if board(id,key):return true
	return not nearby.is_empty()
func pin(key: int):
	var row: Dictionary=rows[key];var seats:=occupants(row)
	for slot in seats.size():
		var actor=game.fighters.get(seats[slot])
		if actor:
			actor.position=seat_position(row,slot);actor.velocity=row.velocity;actor.ski_held=false;actor.jet_held=false
			actor.render_mount=render_seat_position.bind(seats[slot])
func leave(id: int,force: bool=false) -> bool:
	var key:=vehicle_for(id)
	if key==0:return false
	var row: Dictionary=rows[key];var actor=game.fighters.get(id);var slot:=seat_for(id,row)
	var d:=definition(row);var seat: Vector3=d.seats[slot]
	var exit:=Vector3.INF
	if actor:
		for offset in [seat+Vector3(0,2.2,0),Vector3(d.half.x+1,seat.y,seat.z),Vector3(-d.half.x-1,seat.y,seat.z),Vector3(seat.x,seat.y,d.half.z+1)]:
			var target: Vector3=frame(row)*offset
			var excluded: Array[RID]=[bodies[key].get_rid(),actor.get_rid()]
			var ray:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.8,target+Vector3.UP*.8,1,excluded)
			if clear_volume(Transform3D(Basis.IDENTITY,target+Vector3.UP*.85),Vector3(.42,.83,.42),excluded) and game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():exit=target;break
		if exit==Vector3.INF and not force:return false
		bodies[key].remove_collision_exception_with(actor);actor.remove_collision_exception_with(bodies[key])
		actor.render_mount=Callable();actor.clear_mounted_visuals()
		actor.position=exit if exit!=Vector3.INF else seat_position(row,slot)+Vector3.UP*2.2
		actor.velocity=row.velocity+Vector3.UP*5;actor.prediction.clear();actor.reset_view()
	if slot==0:row.pilot=0;row.life=-1
	else:row.passengers[slot-1]=0;row.passenger_lives[slot-1]=-1
	row.idle_until=game.clock+120;locks[id]=game.clock+3
	return true
func handle_player(id: int,jump: bool,delta: float=1.0/60) -> bool:
	if not mounted(id):return false
	var actor=game.fighters[id];var pressed: bool=jump and not actor.jump_held;actor.jump_held=jump
	if pressed and eligible(id):leave(id)
	if mounted(id) and not piloting(id):
		var s: Dictionary=game.players[id]
		s.cooldown=maxf(0,s.cooldown-delta)
		if eligible(id) and game.clock-s.last_input<=.35:
			var held: Array=game.fire_delivery.begin_attempt(s,game.clock)
			rules.combat.tick_input(id,delta)
			game.fire_delivery.end_attempt(s,held)
	return mounted(id)
func departed(id: int):
	leave(id,true);locks.erase(id);requests.erase(id)
	for pair in impact_locks.keys():
		if pair.y==id:impact_locks.erase(pair)
func remove(key: int):
	if not rows.has(key):return
	for id in occupants(rows[key]):
		if id!=0:leave(id,true)
	if is_instance_valid(bodies.get(key)):bodies[key].free()
	bodies.erase(key);rows.erase(key)
	for pair in impact_locks.keys():
		if pair.x==key:impact_locks.erase(pair)
	render_motion.erase(key);render_frames.erase(key)
func reset():
	for key in rows.keys():remove(key)
	rockets.clear();locks.clear();requests.clear();impact_locks.clear();next_id=1;next_rocket=1
	render_motion.clear();render_frames.clear();render_frame_number=-1
	if is_instance_valid(view):view.clear()
func tick(delta: float):
	if not multiplayer.is_server():return
	if not active():
		if not rows.is_empty() or not rockets.is_empty():reset()
		return
	if game.intermission>0:return
	for key in rows.keys():
		var row: Dictionary=rows[key];var seats:=occupants(row);var lives: Array=[row.life]+row.get("passenger_lives",[]);var d:=definition(row)
		for slot in seats.size():
			var person: int=seats[slot]
			if person!=0 and (not game.players.has(person) or game.players[person].dead or game.players[person].spectator or game.players[person].serial!=lives[slot]):leave(person,true)
		var id: int=row.pilot
		if occupants(row).all(func(person):return person==0) and game.clock>row.idle_until:remove(key);continue
		var s: Dictionary=game.players.get(id,{})
		var enabled: bool=id!=0 and eligible(id) and game.clock-s.last_input<=.35
		var control:=Data.controls(s if enabled else {})
		if not enabled:control.yaw=row.yaw;control.pitch=0.0
		var body: CharacterBody3D=bodies[key]
		# Player movement runs before vehicles. Catch contacts initiated by a
		# player too, rather than only collisions returned by the hull sweep.
		for victim in game.fighters:
			var actor=game.fighters[victim]
			for contact in actor.get_slide_collision_count():
				var hit: KinematicCollision3D=actor.get_slide_collision(contact)
				if hit.get_collider()==body:impact_player(key,victim,row.velocity,hit.get_normal(),hit.get_position())
		if not render_motion.tracks.has(key):render_motion.push(key,game.clock-delta,seat_frame(row))
		var floor_query:=PhysicsRayQueryParameters3D.create(row.position,row.position-Vector3.UP*500,1,[body.get_rid()])
		var floor_hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(floor_query)
		var height: float=row.position.y-floor_hit.position.y if not floor_hit.is_empty() else d.altitude+10
		var old_yaw: float=row.yaw
		Data.advance(row,control,height,delta)
		if absf(wrapf(row.yaw-old_yaw,-PI,PI))>.0001:
			var excludes: Array[RID]=[body.get_rid()]
			for person in occupants(row):
				if person!=0 and game.fighters.has(person):excludes.append(game.fighters[person].get_rid())
			if not clear_volume(frame(row),d.half,excludes):row.yaw=old_yaw
		body.rotation.y=row.yaw
		var collision:=body.move_and_collide(row.velocity*delta)
		row.position=body.position
		if collision:
			var speed: float=maxf(0,-row.velocity.dot(collision.get_normal()))
			for contact in collision.get_collision_count():
				var collider=collision.get_collider(contact)
				for victim in game.fighters:
					if collider==game.fighters[victim]:impact_player(key,victim,row.velocity,-collision.get_normal(contact),collision.get_position(contact))
			row.velocity=row.velocity.slide(collision.get_normal())*.65
			if speed>8:
				damage(key,id,(speed-8)*4*(d.ground_scale if collision.get_normal().y>.5 else 1.0),"IMPACT")
			if not rows.has(key):continue
		pin(key)
		render_motion.push(key,game.clock,seat_frame(row))
		for person in occupants(row):
			if person!=0 and game.fighters.has(person):preload("res://deathmatch/movement/tribes.gd").energy_tick(game.fighters[person].tribes_state,false,delta)
		if enabled:
			var held: Array=game.fire_delivery.begin_attempt(s,game.clock)
			if s.fire:fire(key)
			game.fire_delivery.end_attempt(s,held)
		if row.position.y<game.fall_limit:remove(key)
	for key in rockets.keys():
		var rocket: Dictionary=rockets[key];rocket.life-=delta
		var end: Vector3=rocket.position+rocket.velocity*delta
		var hit: Dictionary=game._trace(rocket.position,end,rocket.owner)
		rocket.velocity+=rocket.direction*minf(Data.ROCKET_ACCEL*delta,maxf(0,Data.ROCKET_TERMINAL-rocket.speed));rocket.speed=minf(Data.ROCKET_TERMINAL,rocket.speed+Data.ROCKET_ACCEL*delta)
		if hit.hit or rocket.life<=0:
			var at: Vector3=hit.position if hit.hit else end
			# Keep blast visibility rays outside the struck face. Starting exactly
			# on it lets the shared ray bias begin inside a thin wall.
			if hit.hit:at+=hit.get("surface_normal",-rocket.direction)*.08
			rules.combat.blast(at,rocket.owner,{"name":"SCOUT ROCKET","splash":Data.ROCKET_DAMAGE,"blast_radius":Data.ROCKET_RADIUS,"kick":250.0,"turret_team":rocket.team if not game.players.has(rocket.owner) else -2})
			game._ability_fx.rpc("explosion",at,at,rocket.team);rockets.erase(key)
		else:rocket.position=end
func impact_player(key: int,victim: int,velocity: Vector3,direction: Vector3,point: Vector3) -> bool:
	if not multiplayer.is_server() or not active() or not rows.has(key) or not game.players.has(victim) or not game.fighters.has(victim):return false
	if not velocity.is_finite() or not direction.is_finite() or not point.is_finite() or velocity.length()<3 or direction.length_squared()<.5:return false
	var row: Dictionary=rows[key];var s: Dictionary=game.players[victim]
	if mounted(victim) or s.dead or s.spectator or s.invulnerable>game.clock or game.intermission>0 or game.match_mode.special.blocked(victim):return false
	if s.team==row.team and not rules.mode.friendly_fire:return false
	var actor=game.fighters[victim];direction=direction.normalized()
	var closing: float=(velocity-actor.velocity).dot(direction)
	if closing<3:return false # No grazing damage or damage from a parked hull.
	var pair:=Vector2i(key,victim);var previous: Dictionary=impact_locks.get(pair,{})
	if previous.get("life",-1)==s.serial and game.clock<float(previous.get("until",0)):return false
	impact_locks[pair]={"life":s.serial,"until":game.clock+.35}
	var d:=definition(row)
	# Reuse mass-aware blast momentum and the authoritative damage/snapshot path.
	# Send the impulse before lethal damage so the death pose retains momentum.
	actor.apply_blast(direction*minf(28,closing*.8)+Vector3.UP*minf(3,closing*.12))
	game._damage(victim,row.pilot,roundi(d.ram*100/.66*minf(1,closing/d.speed)),d.name+" IMPACT",false,point,direction)
	return true
func fire(key: int) -> bool:
	if not multiplayer.is_server() or not rows.has(key) or rockets.size()>=64:return false
	var row: Dictionary=rows[key];var id: int=row.pilot
	if row.get("kind","scout")!="scout" or id==0 or not eligible(id) or game.clock<row.next_fire or game.clock<row.ready:return false
	var pose:=frame(row);var muzzle: Vector3=Data.MUZZLE;muzzle.x*=1 if next_rocket%2 else -1
	var start: Vector3=pose*muzzle
	var ray:=PhysicsRayQueryParameters3D.create(row.position,start,1,[bodies[key].get_rid()])
	if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	var direction:=pose.basis*Basis(Vector3.RIGHT,row.pitch)*Vector3.FORWARD
	var state: Dictionary=game.players[id]
	if state.get("vr_device",false) and not state.get("xr",{}).is_empty():
		direction=(Basis(Vector3.UP,state.yaw)*state.xr.weapon.basis*Vector3.FORWARD).normalized()
	rockets[next_rocket]={"position":start,"velocity":direction*Data.ROCKET_SPEED+row.velocity*.5,"direction":direction,"speed":Data.ROCKET_SPEED,"owner":id,"team":row.team,"life":Data.ROCKET_LIFE};next_rocket+=1
	row.next_fire=game.clock+Data.ROCKET_CYCLE;game.players[id].invulnerable=0;game.players[id].shots+=1
	game._ability_fx.rpc("scout_fire",start,start+direction*2,row.team)
	return true
func trace(start: Vector3,end: Vector3,hit: Dictionary,radius: float) -> Dictionary:
	var distance:=start.distance_to(hit.position)
	for key in rows:
		var inverse:=frame(rows[key]).affine_inverse()
		var t:=Hit.box_fraction(inverse*start,inverse*end,definition(rows[key]).half,radius)
		if not is_finite(t):continue
		var point:=start.lerp(end,t)
		if start.distance_to(point)>distance+.02:continue
		hit={"id":0,"hit":true,"position":point,"scout":key};distance=start.distance_to(point)
	return hit
func damage(key: int,attacker: int,amount: float,family: String="",source_team: int=-1):
	if not multiplayer.is_server() or not active() or not rows.has(key) or not is_finite(amount) or amount<=0:return
	var row: Dictionary=rows[key]
	if not rules.mode.friendly_fire and (source_team==row.team or attacker!=row.pilot and game.players.get(attacker,{}).get("team",-1)==row.team):return
	row.hp=maxf(0,row.hp-amount*(.5 if family.to_lower() in ["blaster","laser rifle"] else 1.0))
	if row.hp<=0:
		var at: Vector3=row.position;var team: int=row.team;var name: String=definition(row).name;remove(key)
		game._ability_fx.rpc("explosion",at,at,team)
		game._blast(at,attacker,20,4,name+" WRECK")
func repair(key: int,id: int,amount: float) -> bool:
	if not multiplayer.is_server() or not rows.has(key) or not is_finite(amount) or amount<=0 or not game.players.has(id) or game.players[id].team!=rows[key].team:return false
	var before: float=rows[key].hp;rows[key].hp=minf(definition(rows[key]).hp,before+amount);return rows[key].hp>before
func blast(where: Vector3,owner: int,amount: float,radius: float,source_team: int=-1):
	for key in rows.keys():
		if not rows.has(key):continue
		var row: Dictionary=rows[key];var pose:=frame(row)
		var point: Vector3=pose*((pose.affine_inverse()*where).clamp(-definition(row).half,definition(row).half))
		var distance:=where.distance_to(point)
		if distance>=radius:continue
		var query:=PhysicsRayQueryParameters3D.create(where,point,1,[bodies[key].get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():damage(key,owner,amount*(1-distance/radius),"",source_team)
func snapshot() -> Dictionary:return {"rows":rows.duplicate(true),"rockets":rockets.duplicate(true)}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2 or not data.get("rows") is Dictionary or not data.get("rockets") is Dictionary or data.rows.size()>Data.MAX_VEHICLES or data.rockets.size()>64:return false
	var pilots: Array=[]
	for key in data.rows:
		var row=data.rows[key]
		if not key is int or key<=0 or not row is Dictionary or row.size() not in [13,16]:return false
		for field in ["position","velocity","yaw","pitch","bank","hp","pilot","life","team","owner_team","ready","next_fire","idle_until"]:
			if not row.has(field):return false
		var kind=row.get("kind","scout")
		if not kind is String or kind not in Data.KINDS:return false
		var d:=Data.definition(kind)
		if row.size()==16:
			if not row.has("kind") or not row.get("passengers") is Array or not row.get("passenger_lives") is Array or row.passengers.size()!=d.seats.size()-1 or row.passenger_lives.size()!=row.passengers.size():return false
			for i in row.passengers.size():
				var person=row.passengers[i];var life=row.passenger_lives[i]
				if not person is int or not life is int or person!=0 and (person in pilots or life<0) or person==0 and life!=-1:return false
				if person!=0:pilots.append(person)
		elif kind!="scout":return false
		if not row.team is int or not row.owner_team is int:return false
		for field in ["position","velocity"]:
			if not row.get(field) is Vector3 or not row[field].is_finite() or row[field].length()>20000:return false
		for field in ["yaw","pitch","bank","hp","ready","next_fire","idle_until"]:
			if not (row.get(field) is float or row.get(field) is int) or not is_finite(float(row[field])):return false
		if row.hp<=0 or row.hp>d.hp or absf(row.pitch)>d.pitch+.001 or absf(row.bank)>d.bank+.001 or row.team not in [0,1] or row.owner_team not in [0,1] or not row.pilot is int or not row.life is int:return false
		if row.pilot!=0:
			if row.pilot in pilots or row.life<0:return false
			pilots.append(row.pilot)
	for key in data.rockets:
		var row=data.rockets[key]
		if not key is int or key<=0 or not row is Dictionary or row.size()!=7:return false
		for field in ["position","velocity","direction","speed","life","owner","team"]:
			if not row.has(field):return false
		if not row.team is int:return false
		for field in ["position","velocity","direction"]:
			if not row.get(field) is Vector3 or not row[field].is_finite() or row[field].length()>20000:return false
		for field in ["speed","life"]:
			if not (row.get(field) is int or row.get(field) is float) or not is_finite(float(row[field])):return false
		if row.life<0 or row.life>Data.ROCKET_LIFE or row.speed<0 or row.speed>Data.ROCKET_TERMINAL or not row.owner is int or row.team not in [0,1] or absf(row.direction.length()-1)>.01:return false
	return true
func receive(data: Dictionary):
	if not valid(data):return
	for key in rows.keys():
		if not data.rows.has(key) or data.rows[key].get("kind","scout")!=rows[key].get("kind","scout"):remove(key)
	for key in rows:
		for person in occupants(rows[key]):
			if person!=0 and game.fighters.has(person):
				bodies[key].remove_collision_exception_with(game.fighters[person]);game.fighters[person].remove_collision_exception_with(bodies[key])
				game.fighters[person].render_mount=Callable()
	rows=data.rows.duplicate(true);rockets=data.rockets.duplicate(true)
	for key in rows:
		# Older Scout recordings predate kind and passenger arrays.
		rows[key].merge({"kind":"scout","passengers":[],"passenger_lives":[]})
		make_body(key);bodies[key].global_transform=frame(rows[key])
		pin(key)
		var stamp: float=game.demos.snapshot_time if game.demos.playing else game.snapshot_view_time if game.snapshot_view_time>=0 else game.clock
		render_motion.push(key,stamp,seat_frame(rows[key]))
		if not game.demos.playing:render_motion.received(stamp,Time.get_ticks_usec()/1000000.0)
		for person in occupants(rows[key]):
			if person!=0 and game.fighters.has(person):
				bodies[key].add_collision_exception_with(game.fighters[person]);game.fighters[person].add_collision_exception_with(bodies[key])
func update(delta: float):
	if game.headless:return
	if not is_instance_valid(view):view=preload("res://deathmatch/vehicles/tribes/view.gd").new();game.add_child(view);view.setup(self)
	view.update(delta)
