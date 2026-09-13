extends Node
## Server-owned cockpit reservation, movement and cannon heat. Opt-in test actors.
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
const View=preload("res://deathmatch/vehicles/ba2/view.gd")
const Tuning=preload("res://deathmatch/vehicles/ba2/tuning.gd")
const Hit=preload("res://deathmatch/hit_detection.gd")
const SPEED=Tuning.SPEED
const TRANSITION=Tuning.TRANSITION
const STRIDE=Tuning.STRIDE
const LADDER=Vector3(0,.08,0)
const SEAT=Vector3(0,6.2,0)
const PILOT_ARMOR=200
const BOARDING_EXIT_LOCK=3.0
const HULL_RADII=Vector3(1.97,2.637,2.51)
const HEAT_PER_VOLLEY=12.5
const COOL_RATE=25.0
const RESTART_HEAT=25.0
const PITCH_LIMIT=PI/4
const AIM_SPEED=PI/30 # Six degrees/second, X hinge only.
const SPLASH_RADIUS=1.25
const CANNON_RANGE=60.0
const CANNON_CONE=Tuning.LATERAL_LIMIT
const CRUSH_RADIUS=5.0
const CRUSH_HEIGHT=1.8
const CRUSH_OFFSET=Vector3(0,0,-1.2) # Centre of the four-foot footprint, includes belly ladder.
var fortress_ref: WeakRef
var tf:
	get:return fortress_ref.get_ref()
var game:
	get:return tf.game
var definitions: Array=[]
var robots: Dictionary={}
var bodies: Dictionary={}
var views: Dictionary={}
var reboard_until: Dictionary={}
var cockpit: Node3D
func setup(fortress) -> void:fortress_ref=weakref(fortress)
func configure(rows: Array) -> void:
	definitions=rows.duplicate(true);reset()
func reset() -> void:
	if is_instance_valid(cockpit):cockpit.free();cockpit=null
	for id in game.fighters:
		if mounted(id):_unlock(id)
	for node in bodies.values():if is_instance_valid(node):node.free()
	for node in views.values():if is_instance_valid(node):node.free()
	bodies.clear();views.clear();robots.clear();reboard_until.clear()
	for definition in definitions:
		if definition.get("points",[]).size()<2:continue
		var key: String=str(definition.get("id","ba2"))
		var path:=Route.curve(definition.points,definition.get("loop",false))
		if path.get_baked_length()<1:continue
		var pose:=Route.sample(path,0)
		robots[key]={"id":key,"points":definition.points,"loop":definition.get("loop",false),"fixed_team":definition.get("team",-1),"team":definition.get("team",-1),"path":path,"pilot":0,"pilot_life":-1,"exit_lock":0.,"distance":0.,"speed":0.,"from_speed":0.,"to_speed":0.,"transition":0.,"position":pose.origin,"yaw":pose.basis.get_euler().y,"heat":[0.,0.],"overheated":[false,false],"next":[0.,0.],"last_fire":[-100.,-100.],"pitches":[0.,0.],"body_yaw":0.,"targets":[0,0],"scan_at":0.,"state":"parked","ready":game.clock+3.0}
		_make_body(key)
func _make_body(key: String) -> void:
	var body:=AnimatableBody3D.new();body.name="BA2_"+key;body.sync_to_physics=false;body.collision_layer=1;body.collision_mask=3
	body.set_meta("ba2_id",key)
	var hull:=CollisionShape3D.new();hull.name="HullCollision"
	var convex:=ConvexPolygonShape3D.new();var vertices:=PackedVector3Array()
	for latitude in range(9):
		var angle:=PI*latitude/8.
		for longitude in 16:
			var turn:=TAU*longitude/16.
			vertices.append(Vector3(sin(angle)*cos(turn),cos(angle),sin(angle)*sin(turn))*HULL_RADII)
	convex.points=vertices;hull.shape=convex;hull.transform=_body_pose(robots[key]);body.add_child(hull)
	for pair in 2:
		var gun:=_add_box(body,Vector3(2.3362067 if pair==0 else -2.3362067,7.3625116,1.15),Vector3(.8,1.55,2.5))
		gun.name="CannonCollision"+str(pair)
	for x in [-3.8,3.8]:
		for z in [-3.5,1.1]:
			var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=4.8;shape.shape=capsule;shape.position=Vector3(x,2.65,z);body.add_child(shape)
	game.get_node("Map").add_child(body);bodies[key]=body;body.global_transform=transform(robots[key])
func _add_box(body: Node3D,at: Vector3,size: Vector3) -> CollisionShape3D:
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.position=at;body.add_child(shape)
	return shape
func transform(row: Dictionary) -> Transform3D:return Transform3D(Basis(Vector3.UP,float(row.yaw)),row.position)
func mounted(id: int) -> bool:return not vehicle_for(id).is_empty()
func vehicle_for(id: int) -> String:
	if id==0:return ""
	for key in robots:if int(robots[key].pilot)==id:return key
	return ""
func ladder_visible(row: Dictionary) -> bool:return int(row.pilot)==0 and float(row.speed)<=.0001
func handle_player(id: int,jump: bool) -> bool:
	if mounted(id):
		var actor=game.fighters[id]
		var pressed: bool=jump and not actor.jump_held
		actor.jump_held=jump
		if pressed and not game.players[id].get("input_blocked",false):leave(id)
		if mounted(id):pin(id)
		return true
	if jump and not game.fighters[id].jump_held:
		for key in robots:
			if try_board(id,key):return true
	return false
func try_board(id: int,key: String) -> bool:
	if not multiplayer.is_server() or not game.active or game.map_loading or game.intermission>0 or game.lobby.active() or not robots.has(key) or not game.players.has(id) or not game.fighters.has(id):return false
	var s: Dictionary=game.players[id];var r: Dictionary=robots[key]
	if mounted(id) or s.dead or s.spectator or s.get("input_blocked",false) or game.match_mode.special.blocked(id) or game.clock<reboard_until.get(id,0.) or not ladder_visible(r):return false
	if game.match_mode.kind=="tb" and int(s.team)!=game.match_mode.titanball.ATTACKERS:return false
	if int(r.fixed_team)>=0 and int(s.team)!=int(r.fixed_team):return false
	var base: Vector3=transform(r)*LADDER;var at: Vector3=game.fighters[id].position
	if Vector2(at.x-base.x,at.z-base.z).length()>1.3 or absf(at.y-base.y)>1.8:return false
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.8,base+Vector3.UP*.8,1)
	if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	# Reserve before teleporting. This path never yields, including simultaneous inputs.
	var previous_hp: int=s.hp
	r.pilot=id;r.team=s.team;r.targets=[0,0];s["ba2_saved_mask"]=game.fighters[id].collision_mask
	r.exit_lock=BOARDING_EXIT_LOCK;s.hp=tf.max_health(id)
	s["ba2_loadout"]={"weapon":s.weapon,"armor":s.armor,"tier":s.tier}
	enforce_pilot(id)
	game.fighters[id].collision_mask=0;bodies[key].add_collision_exception_with(game.fighters[id])
	tf.revealed(id);s.invulnerable=0;s.fire=false;s.offhand_fire=false;s.melee=false;s.charge=0;s.room=Vector3.ZERO;s.move=Vector2.ZERO;s.swim=Vector3.ZERO
	game.variant_combat.cancel_player(id)
	_teleport(id,transform(r)*SEAT,float(r.yaw)+PI)
	r.pilot_life=s.serial;game.fighters[id].jump_held=true
	game.server_log.record("titan_boarded",{"pilot":id,"robot":key,"class":s.get("tf_class",""),"hp_before":previous_hp,"hp":s.hp,"max_hp":tf.max_health(id),"exit_lock":r.exit_lock,"distance":r.distance},2)
	return true
func _teleport(id: int,at: Vector3,yaw: float) -> void:
	var actor=game.fighters[id];var s: Dictionary=game.players[id]
	actor.position=at;actor.target=at;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view();s.serial+=1;s.yaw=yaw
	if id==multiplayer.get_unique_id():game.local_yaw=yaw
	game.history.clear()
func _unlock(id: int) -> void:
	if not game.players.has(id) or not game.fighters.has(id):return
	game.fighters[id].collision_mask=int(game.players[id].get("ba2_saved_mask",3));game.players[id].erase("ba2_saved_mask")
	game.fighters[id].velocity=Vector3.ZERO;game.fighters[id].blast_velocity=Vector2.ZERO
	var s: Dictionary=game.players[id]
	if s.has("ba2_loadout"):
		s.weapon=s.ba2_loadout.weapon;s.armor=s.ba2_loadout.armor;s.tier=s.ba2_loadout.tier;s.erase("ba2_loadout")
		if id==multiplayer.get_unique_id():game.desired_weapon=s.weapon
func enforce_pilot(id: int) -> void:
	if not multiplayer.is_server() or not mounted(id) or not game.players.has(id):return
	var s: Dictionary=game.players[id];s.weapon=0;s.armor=PILOT_ARMOR;s.tier=2
	if id==multiplayer.get_unique_id():game.desired_weapon=0
func leave(id: int,forced: bool=false) -> bool:
	if not multiplayer.is_server():return false
	var key:=vehicle_for(id)
	if key.is_empty():return false
	var r: Dictionary=robots[key];var exit_point:=Vector3.INF
	if not forced and float(r.get("exit_lock",0.))>0.:return false
	var alive: bool=game.players.has(id) and not game.players[id].dead and not game.players[id].spectator
	if game.fighters.has(id):exit_point=_exit_point(id,r)
	if not exit_point.is_finite():
		if not forced:return false
		exit_point=transform(r)*(LADDER+Vector3.UP*.1)
	# Death/disconnect always release the reservation, even if the ground is blocked.
	r.pilot=0;r.pilot_life=-1;r.targets=[0,0];reboard_until[id]=game.clock+1.0
	r.exit_lock=0.
	if game.fighters.has(id):bodies[key].remove_collision_exception_with(game.fighters[id])
	_unlock(id)
	if not alive and game.fighters.has(id):game.fighters[id].collision_layer=0
	if game.fighters.has(id) and game.players.has(id) and exit_point.is_finite():_teleport(id,exit_point,float(r.yaw)+PI)
	return true
func departed(id: int) -> void:
	if multiplayer.is_server():leave(id,true)
func _exit_point(id: int,r: Dictionary) -> Vector3:
	for offset in [Vector3.ZERO,Vector3(1.2,0,0),Vector3(-1.2,0,0),Vector3(0,0,1.5),Vector3(2.4,0,1.5),Vector3(-2.4,0,1.5)]:
		var at: Vector3=transform(r)*(LADDER+offset)
		var floor_ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3,1)
		var floor_hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(floor_ray)
		if floor_hit.is_empty() or floor_hit.normal.y<.8:continue
		at=floor_hit.position+Vector3.UP*.025
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.65;query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.83);query.collision_mask=3;query.exclude=[game.fighters[id].get_rid()]
		if game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return at
	return Vector3.INF
func pin(id: int,visual: bool=false) -> void:
	var key:=vehicle_for(id)
	if key.is_empty() or not game.fighters.has(id):return
	var r: Dictionary=robots[key];var pose:=transform(r)
	if visual and views.has(key):pose=views[key].global_transform
	var actor=game.fighters[id];actor.position=pose*SEAT;actor.target=actor.position;actor.velocity=pose.basis.z*float(r.speed);actor.blast_velocity=Vector2.ZERO;actor.visual_velocity=Vector3.ZERO;actor.collision_mask=0
	game.players[id].room=Vector3.ZERO
	enforce_pilot(id)
func tick(delta: float) -> void:
	if not multiplayer.is_server():return
	for key in robots:
		var r: Dictionary=robots[key];var pilot: int=r.pilot
		r.exit_lock=maxf(0.,float(r.get("exit_lock",0.))-delta)
		if r.exit_lock<.00001:r.exit_lock=0.
		if pilot!=0 and (not game.players.has(pilot) or game.players[pilot].dead or game.players[pilot].spectator or game.players[pilot].serial!=r.pilot_life or game.match_mode.special.blocked(pilot) or (game.match_mode.kind=="tb" and game.players[pilot].team!=game.match_mode.titanball.ATTACKERS)):leave(pilot,true)
		var remaining: float=r.path.get_baked_length()-r.distance
		# A new pilot may board after a death stops us inside the final braking
		# zone. Plan a smaller acceleration/braking profile from that standstill;
		# the fixed full-speed stopping distance would otherwise forbid restarting.
		if r.speed==0. and r.to_speed==0.:
			r["drive_speed"]=SPEED if r.loop else minf(SPEED,remaining/TRANSITION)
		var drive_speed: float=r.get("drive_speed",SPEED)
		var goal: float=drive_speed if r.pilot!=0 and not game.match_mode.titanball.preparing() and (r.loop or (remaining>.02 and remaining>drive_speed*TRANSITION*.5)) else 0.
		if not is_equal_approx(goal,r.to_speed):r.from_speed=r.speed;r.to_speed=goal;r.transition=0.
		var old: float=r.speed;r.transition=minf(TRANSITION,r.transition+delta);var u: float=r.transition/TRANSITION
		r.speed=lerpf(r.from_speed,r.to_speed,u*u*(3.-2.*u))
		var travel: float=(old+r.speed)*.5*delta
		var next_distance: float=r.distance+travel
		if not r.loop:next_distance=minf(next_distance,r.path.get_baked_length())
		var pose:=Route.sample(r.path,next_distance,r.loop)
		var body: AnimatableBody3D=bodies[key]
		var motion: Vector3=pose.origin-r.position
		if r.state=="blocked" and goal>0. and motion.length()<.01:motion=pose.basis.z*.01
		var victims:=crush_candidates(r,pose,body.get_rid())
		var deployables:=crush_deployables(r,pose,body.get_rid())
		# Defenders underfoot cannot stop the robot by colliding with a leg.
		# Restore every temporary exception before applying damage; walls and allies
		# still block normally, and blocked motion never activates the kill zone.
		var omitted: Array=[]
		for id in victims:
			var actor=game.fighters[id]
			if not actor in body.get_collision_exceptions():body.add_collision_exception_with(actor);omitted.append(actor)
		var blocked:=body.test_move(body.global_transform,motion)
		for actor in omitted:body.remove_collision_exception_with(actor)
		if blocked:
			r.speed=0.;r.from_speed=0.;r.to_speed=0.;r.transition=0.;r.state="blocked"
		else:
			r.distance=next_distance;r.position=pose.origin;r.yaw=rotate_toward(r.yaw,pose.basis.get_euler().y,deg_to_rad(8)*delta)
			r.state="parked" if r.speed<.0001 else "braking" if goal==0 else "walking"
			for id in victims:game._damage(id,r.pilot,100000,"TITAN CRUSH",true,game.fighters[id].position+Vector3.UP*.65,Vector3.DOWN)
			for item in deployables:
				if item.collection=="building":tf.damage_building(item.key,r.pilot,maxi(1,int(tf.buildings[item.key].hp)))
				else:
					tf.charges.erase(item.key)
					game._ability_fx.rpc("explosion",item.position,item.position,game.match_mode.titanball.DEFENDERS)
				game.server_log.record("titan_deployable_crushed",{"robot":r.id,"pilot":r.pilot,"kind":item.kind,"collection":item.collection,"key":item.key,"distance":r.distance},2)
		if r.pilot!=0:pin(r.pilot)
		_tick_cannons(r,delta,body.get_rid())
		_update_body(body,r)
		game.match_mode.titanball.observe(key,r)
func crush_candidates(r: Dictionary,next_pose: Transform3D,body_rid: RID) -> Array:
	var victims: Array=[]
	if not crush_active(r,next_pose):return victims
	var start: Vector3=transform(r)*CRUSH_OFFSET;var end: Vector3=next_pose*CRUSH_OFFSET
	for id in game.players:
		var state: Dictionary=game.players[id]
		if state.dead or state.spectator or state.team!=game.match_mode.titanball.DEFENDERS or not game.fighters.has(id):continue
		var at: Vector3=game.fighters[id].position
		if crush_reaches(at,start,end,body_rid,minf(.8,game.fighters[id].collision_height*.5)):victims.append(id)
	return victims
func crush_active(r: Dictionary,next_pose: Transform3D) -> bool:
	return multiplayer.is_server() and game.match_mode.kind=="tb" and game.active and not game.map_loading and game.intermission<=0 and not game.match_mode.titanball.preparing() and next_pose.origin.distance_squared_to(r.position)>=1e-14
func crush_reaches(at: Vector3,start: Vector3,end: Vector3,body_rid: RID,height: float) -> bool:
	var closest:=Geometry3D.get_closest_point_to_segment(Vector3(at.x,start.y,at.z),start,end)
	if at.y<closest.y-.25 or at.y>closest.y+CRUSH_HEIGHT or Vector2(at.x-closest.x,at.z-closest.z).length()>CRUSH_RADIUS:return false
	var ray:=PhysicsRayQueryParameters3D.create(closest+Vector3.UP*.8,at+Vector3.UP*height,1);ray.exclude=[body_rid]
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func crush_deployables(r: Dictionary,next_pose: Transform3D,body_rid: RID) -> Array:
	var result: Array=[]
	if not crush_active(r,next_pose):return result
	var start: Vector3=transform(r)*CRUSH_OFFSET;var end: Vector3=next_pose*CRUSH_OFFSET
	for key in tf.buildings:
		var b: Dictionary=tf.buildings[key]
		# The shared, map-owned resupply stations are neutral, not Blue deployables.
		if b.team!=game.match_mode.titanball.DEFENDERS or b.get("map_owned",false):continue
		if crush_reaches(b.position,start,end,body_rid,.6):result.append({"collection":"building","key":key,"kind":b.kind,"position":b.position})
	for key in tf.charges:
		var c: Dictionary=tf.charges[key]
		# Settled charges are deployables; airborne projectiles retain normal combat.
		if c.team!=game.match_mode.titanball.DEFENDERS or c.get("velocity",Vector3.ZERO).length_squared()>.25:continue
		if crush_reaches(c.position,start,end,body_rid,.1):result.append({"collection":"charge","key":key,"kind":c.kind,"position":c.position})
	return result
func _update_body(body: AnimatableBody3D,r: Dictionary) -> void:
	body.global_transform=transform(r)
	var body_pose:=_body_pose(r)
	body.get_node("HullCollision").transform=body_pose
	for pair in 2:
		var gun:=body.get_node("CannonCollision"+str(pair)) as CollisionShape3D
		var rotation:=body_pose.basis*Basis(Vector3.RIGHT,r.pitches[pair])
		gun.transform=Transform3D(rotation,body_pose.origin+body_pose.basis*Vector3(2.3362067 if pair==0 else -2.3362067,0,0)+rotation*Vector3(0,0,1.15))

func _body_pose(r: Dictionary) -> Transform3D:
	var phase: float=fposmod(r.distance,STRIDE)/STRIDE*TAU
	var ratio: float=clampf(r.speed/SPEED,0,1)
	var turn:=Basis(Vector3.UP,Tuning.body_yaw(r))
	return Transform3D(turn,Vector3(.05013234*sin(phase)*ratio,7.3625116+.02228104*(1.-cos(phase*4))*ratio,0))
func cannon_origin(r: Dictionary,index: int) -> Vector3:
	var body_pose:=_body_pose(r)
	var pivot:=Vector3(2.3362067 if index<2 else -2.3362067,0,0)
	var offset:=Vector3(0,-.4399755 if index%2==0 else .4399755,2.335103)
	var point: Vector3=body_pose*(pivot+Basis(Vector3.RIGHT,r.pitches[index/2])*offset)
	return transform(r)*point
func _tick_cannons(r: Dictionary,delta: float,body_rid: RID) -> void:
	for i in 2:
		if r.pilot==0 or r.overheated[i] or int(r.targets[i])==0 or game.clock-r.last_fire[i]>tf.SENTRY_INTERVAL+tf.SENTRY_SCAN_INTERVAL:
			r.heat[i]=maxf(0.,r.heat[i]-COOL_RATE*delta)
		if r.overheated[i] and r.heat[i]<=RESTART_HEAT:r.overheated[i]=false
	if r.pilot==0:
		r.body_yaw=move_toward(Tuning.body_yaw(r),Tuning.body_sway(r),AIM_SPEED*delta)
		return
	# Limit acquisition and impact to the route-facing arc, so torso rotation
	# does not add a second lateral cone on top of the fifteen-degree coverage.
	var route_basis: Basis=transform(r).basis
	var anchor: Vector3=transform(r)*_body_pose(r).origin
	if game.clock>=r.scan_at:
		r.scan_at=game.clock+tf.SENTRY_SCAN_INTERVAL
		for pair in 2:
			var origin:=cannon_origin(r,pair*2)
			var filter:=func(target: Vector3):
				var local: Vector3=route_basis.inverse()*(target-anchor)
				var slope: Vector3=target-origin
				return local.z>0 and absf(local.x)<=local.z*tan(CANNON_CONE)+SPLASH_RADIUS and absf(slope.y)<=Vector2(slope.x,slope.z).length()*tan(PITCH_LIMIT)+SPLASH_RADIUS
			r.targets[pair]=tf.sentry_target(origin,r.team,CANNON_RANGE,[body_rid],filter)
	var headings: Array=[]
	for id in r.targets:
		if id==0 or not game.players.has(id) or not tf.sentry_enemy(id,r.team):continue
		var local: Vector3=route_basis.inverse()*(tf.sentry_target_point(id)-anchor)
		headings.append(clampf(atan2(local.x,local.z),-CANNON_CONE,CANNON_CONE))
	var desired_yaw: float=Tuning.body_sway(r)
	if not headings.is_empty():
		desired_yaw=0.
		for angle in headings:desired_yaw+=float(angle)/headings.size()
	r.body_yaw=move_toward(Tuning.body_yaw(r),desired_yaw,AIM_SPEED*delta)
	var aim_basis: Basis=route_basis*_body_pose(r).basis
	for pair in 2:
		var id: int=r.targets[pair]
		if id==0 or not game.players.has(id) or not tf.sentry_enemy(id,r.team):continue
		var target: Vector3=tf.sentry_target_point(id)
		var origin:=cannon_origin(r,pair*2);var local: Vector3=aim_basis.inverse()*(target-origin)
		var desired:=clampf(-atan2(local.y,Vector2(local.x,local.z).length()),-PITCH_LIMIT,PITCH_LIMIT)
		r.pitches[pair]=move_toward(r.pitches[pair],desired,AIM_SPEED*delta)
		if absf(desired-r.pitches[pair])>deg_to_rad(2):continue
		if game.clock<r.ready or game.clock<r.next[pair] or r.overheated[pair]:continue
		var fired:=0
		# Both barrels share a cycle and heat reservoir. Check cover per muzzle,
		# then add heat once after the volley so its second shot is never clipped.
		for index in [pair*2,pair*2+1]:
			origin=cannon_origin(r,index)
			if origin.distance_to(target)>CANNON_RANGE:continue
			var ray:=PhysicsRayQueryParameters3D.create(origin,target,1);ray.exclude=[body_rid]
			if not blast_reaches(id,game.get_world_3d().direct_space_state.intersect_ray(ray)):continue
			cannon_impact(r,index,id,target,body_rid);fired+=1
		if fired>0:
			r.next[pair]=game.clock+tf.SENTRY_INTERVAL;r.last_fire[pair]=game.clock
			r.heat[pair]=minf(100.,r.heat[pair]+HEAT_PER_VOLLEY);r.overheated[pair]=r.heat[pair]>=100.
			game.server_log.record("titan_cannon_volley",{"robot":r.id,"pilot":r.pilot,"pair":pair,"barrels":fired,"heat":r.heat[pair],"target":id},2)
func cannon_impact(r: Dictionary,index: int,id: int,target: Vector3,body_rid: RID) -> void:
	if not multiplayer.is_server():return
	var origin:=cannon_origin(r,index)
	var basis: Basis=transform(r).basis*_body_pose(r).basis
	var anchor: Vector3=transform(r)*_body_pose(r).origin
	var route_local: Vector3=transform(r).basis.inverse()*(target-anchor)
	route_local.x=clampf(route_local.x,-route_local.z*tan(CANNON_CONE),route_local.z*tan(CANNON_CONE))
	var local: Vector3=basis.inverse()*(anchor+transform(r).basis*route_local-origin)
	var vertical_limit:=Vector2(local.x,local.z).length()*tan(PITCH_LIMIT)
	local.y=clampf(local.y,-vertical_limit,vertical_limit)
	var endpoint: Vector3=origin+basis*local.limit_length(CANNON_RANGE)
	var ray:=PhysicsRayQueryParameters3D.create(origin,endpoint,1);ray.exclude=[body_rid]
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	var impact: Vector3=hit.position+hit.normal*.04 if not hit.is_empty() else endpoint
	var direct:=contact_pilot(hit)
	if hit.is_empty() and game.fighters.has(id):
		var actor=game.fighters[id]
		var fraction:=Hit.capsule_fraction(origin-actor.position,endpoint-actor.position,Hit.PLAYER_RADIUS,minf(1.4,actor.collision_height-.25))
		if is_finite(fraction):direct=id;impact=origin.lerp(endpoint,fraction)
	if direct!=0:game._damage(direct,r.pilot,tf.SENTRY_DAMAGE,"TITAN CANNON",false,impact,(impact-origin).normalized(),false,mounted(direct))
	# Exclude the direct victim: the splash must not double the original 12 damage.
	game.variant_combat.blast(impact,r.pilot,tf.SENTRY_DAMAGE,SPLASH_RADIUS,"TITAN CANNON",direct)
	game._ability_fx.rpc("ba2_cannon",origin,impact,r.team)
func contact_pilot(hit: Dictionary) -> int:
	var body=hit.get("collider")
	if not is_instance_valid(body) or not body.has_meta("ba2_id"):return 0
	var key: String=body.get_meta("ba2_id")
	if not robots.has(key) or not hit.has("shape"):return 0
	var owner: int=body.shape_find_owner(hit.shape)
	var shape=body.shape_owner_get_owner(owner)
	if shape.name!="HullCollision":return 0 # Guns and legs have no damage proxy.
	var id: int=robots[key].pilot
	return id if game.players.has(id) and not game.players[id].dead else 0
func trace_pilot(start: Vector3,end: Vector3,radius: float,fraction: float) -> int:
	if robots.is_empty() or not is_finite(fraction):return 0
	var space=game.get_world_3d().direct_space_state
	if radius<=0:
		var ray:=PhysicsRayQueryParameters3D.create(start,end,1);ray.hit_from_inside=true
		return contact_pilot(space.intersect_ray(ray))
	var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius
	query.shape=sphere;query.collision_mask=1;query.margin=.001
	query.transform=Transform3D(Basis.IDENTITY,start)
	if space.intersect_shape(query,1).is_empty():
		query.motion=end-start
		var fractions: PackedFloat32Array=space.cast_motion(query)
		# Contact identity must use the unsafe fraction: the safe point is outside
		# the surface and an overlap query there can miss a convex hull entirely.
		query.transform.origin=start.lerp(end,minf(1.,fractions[1]+.0001/maxf(start.distance_to(end),.001)))
		query.motion=Vector3.ZERO
	var pilot:=0
	for hit in space.intersect_shape(query,16):
		var candidate:=contact_pilot(hit)
		if candidate==0:return 0 # Never reach through an overlapping wall or turret.
		pilot=candidate
	return pilot
func blast_target(id: int,origin: Vector3,fallback: Vector3) -> Vector3:
	var key:=vehicle_for(id)
	if key.is_empty():return fallback
	var pose: Transform3D=transform(robots[key])*_body_pose(robots[key])
	var local: Vector3=pose.affine_inverse()*origin
	var distance: float=(local/HULL_RADII).length()
	return pose*(local/maxf(distance,1.))
func surface_explosion(id: int,origin: Vector3) -> bool:
	if not mounted(id):return false
	# Only numerical contact tolerance, not a splash radius. Swept projectile
	# centres can stop farther out and carry explicit hull-contact identity.
	var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.04
	query.shape=sphere;query.transform.origin=origin;query.collision_mask=1
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query,16):
		if contact_pilot(hit)==id:return true
	return false
func accepts_explosion(id: int,origin: Vector3,hull_impact: int=0) -> bool:
	return not mounted(id) or hull_impact==id or surface_explosion(id,origin)
func blast_reaches(id: int,hit: Dictionary) -> bool:
	return hit.is_empty() or mounted(id) and contact_pilot(hit)==id

func snapshot() -> Array:
	var result: Array=[]
	for row in robots.values():
		var wire: Dictionary=row.duplicate();wire.erase("path");result.append(wire)
	return result
func receive(rows: Array) -> void:
	var before: Array=[]
	for row in robots.values():if row.pilot!=0:before.append(row.pilot)
	var live: Dictionary={}
	for row in rows:
		var key: String=row.id;live[key]=true
		var path: Curve3D=robots[key].path if robots.has(key) else Route.curve(row.points,row.loop)
		robots[key]=row.duplicate(true);robots[key]["path"]=path
		if not bodies.has(key):_make_body(key)
		_update_body(bodies[key],row)
	for key in robots.keys():
		if not live.has(key):
			if bodies.has(key):bodies[key].free();bodies.erase(key)
			if views.has(key):views[key].free();views.erase(key)
			robots.erase(key)
	for id in before:if not mounted(id):_unlock(id)
func draw(delta: float) -> void:
	if game.headless:return
	if is_instance_valid(cockpit):cockpit.deactivate()
	for key in robots:
		if not views.has(key):
			var node:=View.new();game.get_node("Map").add_child(node);node.setup();node.global_transform=transform(robots[key]);views[key]=node
		var r: Dictionary=robots[key];var node: Node3D=views[key]
		node.global_transform=node.global_transform.interpolate_with(transform(r),1.-exp(-delta*15.))
		var camera: Camera3D=game.get_viewport().get_camera_3d()
		var inside:=false
		if camera and r.pilot==multiplayer.get_unique_id():
			var eye: Vector3=transform(r).affine_inverse()*camera.global_position
			inside=absf(eye.x)<2. and eye.y>4.8 and eye.y<10.5 and absf(eye.z)<2.8
		node.update_robot(r,ladder_visible(r),false)
		var foot: int=node.footsteps.advance(float(r.distance),float(r.speed))
		if foot>=0:game.spatial.play("ba2_stomp",node.to_global(node.footsteps.FEET[foot]),-3)
		if r.pilot==multiplayer.get_unique_id():
			if not is_instance_valid(cockpit):cockpit=preload("res://deathmatch/vehicles/ba2/cockpit.gd").new();game.add_child(cockpit);cockpit.setup(game)
			cockpit.update_view(transform(r)*Transform3D(Basis.IDENTITY,SEAT),true,delta,r)
		if r.pilot!=0:pin(r.pilot,not multiplayer.is_server())
func status(id: int) -> String:
	var key:=vehicle_for(id)
	if key.is_empty():return ""
	var r: Dictionary=robots[key];var values: Array=[]
	for i in 2:values.append("HOT" if r.overheated[i] else "%d%%"%roundi(r.heat[i]))
	return " · BA-2 PILOT · JUMP / USE: EXIT · HEAT "+" / ".join(values)+" · "+str(r.state).to_upper()
