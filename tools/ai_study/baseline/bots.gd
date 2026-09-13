extends Node
## Authority-only practice AI. Decisions produce ordinary player inputs;
## movement, pickups, abilities, damage and objectives remain server-owned.
var game
var region: NavigationRegion3D
var brains: Dictionary={}
var ready_to_walk:=false
var teamplay=preload("res://tools/ai_study/baseline/teamplay.gd").new()
var navigation=preload("res://tools/ai_study/baseline/navigation.gd").new()
func setup(arena: Node) -> void:
	game=arena;teamplay.ai=self
	region=NavigationRegion3D.new()
	add_child(region)
	var cached: String=preload("res://deathmatch/assets/paths.gd").folder("maps")+"navigation/"+game.current_map+".res"
	if ResourceLoader.exists(cached):
		region.navigation_mesh=load(cached)
		ready_to_walk=true
	else:
		var mesh:=new_mesh()
		if game.current_map.begins_with("ad_arena_"):mesh.cell_size=.25
		region.navigation_mesh=mesh
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,game.get_node("Map").get_child(0))
		NavigationServer3D.bake_from_source_geometry_data_async(mesh,data,func(): ready_to_walk=true)
	var nav_map: RID=region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(nav_map,region.navigation_mesh.cell_size)
	var ad_map: bool=game.current_map.begins_with("ad_arena_")
	NavigationServer3D.map_set_use_edge_connections(nav_map,not ad_map)
	if NavigationServer3D.has_method("map_set_merge_rasterizer_cell_scale"):NavigationServer3D.call("map_set_merge_rasterizer_cell_scale",nav_map,region.navigation_mesh.get_meta("merge_rasterizer_cell_scale",.1 if ad_map or game.current_map in ["as_hislop","as_hislop_tiny","as_hislop_layout_test"] or game.current_map.ends_with("hispeed_concept") else 1.0))
	navigation.setup(game,region)
	for id in game.players:
		if id<0:brains[id]=new_brain(id)
static func new_mesh() -> NavigationMesh:
	var mesh:=NavigationMesh.new()
	mesh.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask=1
	mesh.agent_radius=.4
	mesh.agent_height=1.7
	mesh.agent_max_climb=.5
	mesh.agent_max_slope=48
	mesh.cell_size=.2
	mesh.cell_height=.1
	return mesh

func new_brain(id: int) -> Dictionary:
	var position: Vector3=game.fighters[id].position
	return {
		"next":game.clock+posmod(-id,5)*.04,"plan_at":0.0,"goal":position,"goal_key":"","goal_kind":"roam",
		"last":position,"stuck":0.0,"path":PackedVector3Array(),"step":0,"route_at":0.0,
		"enemy":0,"seen_at":0.0,"seen_position":position,"memory_until":0.0,"serial":game.players[id].serial,
		"watch":position,"ambush_until":0.0,"ambush_at":0.0,"visible":[],"avoid":{},"support":0,"role":"attack","hold":false,
		"boost_until":0.0,"boost_shots":0,"boost_at":0.0,"rocket_route":false,"dodge":Vector3.ZERO,"dodge_until":0.0,
		"reaction":randf_range(.24,.44),"weapon_at":0.0,"observed_velocity":Vector3.ZERO,"aim_error":Vector3.ZERO,"error_at":0.0,
		"strafe_at":0.0,"strafe":1.0,"progress_at":game.clock,"progress_position":position,
		"recover_until":0.0,"recover_direction":Vector3.ZERO,"recover_jump":false,"recover_prone":false,"action_at":0.0,
		"translocate_at":game.clock+3,"disc_until":0.0,"disc_goal":position,"pad_until":0.0,"pad_end":position,"drop_until":0.0,"drop_end":position,
	}

func tick(delta: float) -> void:
	if not multiplayer.is_server():return
	if ready_to_walk:
		navigation.install_links();navigation.update_jump_links()
	teamplay.tick()
	for id in brains.keys():
		if not game.players.has(id) or not game.fighters.has(id):brains.erase(id)
	for id in game.players:
		if id>=0 or not game.fighters.has(id):continue
		var s: Dictionary=game.players[id]
		if not brains.has(id) or brains[id].serial!=s.serial:brains[id]=new_brain(id)
		var brain: Dictionary=brains[id]
		if s.dead or s.spectator or game.match_mode.special.blocked(id):
			s.move=Vector2.ZERO;s.fire=false;s.alt_fire=false;s.offhand_fire=false;s.jump=false;s.swim=Vector3.ZERO;continue
		s.last_input=game.clock;s.room=Vector3.ZERO;s.offhand_fire=false;s.input_blocked=false
		if game.clock>=brain.next:
			brain.next=game.clock+.2
			perceive(id,brain)
			if game.clock>=brain.plan_at:
				plan(id,brain);brain.plan_at=game.clock+.8
		combat(id,brain,delta)
		steer(id,brain,delta)

func alive(id: int) -> bool:
	return game.players.has(id) and game.fighters.has(id) and not game.players[id].dead and not game.players[id].spectator
func eye(id: int) -> Vector3:
	return game.fighters[id].position+Vector3.UP*game.fighters[id].eye_height()
func target_position(id: int) -> Vector3:
	return game.fighters[id].position+Vector3.UP*game.fighters[id].torso_height()
func visible(id: int,other: int) -> bool:
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye(id),target_position(other),3,[game.fighters[id].get_rid()]))
	return hit.is_empty() or hit.collider==game.fighters[other]
func perceive(id: int,brain: Dictionary) -> void:
	var s: Dictionary=game.players[id]
	var previous: int=brain.enemy
	var best:=0;var score:=-INF
	brain.visible=[]
	for other in game.players:
		if other==id or not alive(other) or game.match_mode.same_team(id,other) or game.match_mode.special.frozen.has(other) or game.match_mode.fortress.cloaked(other):continue
		if game.match_mode.kind=="tf" and game.players[other].get("tf_disguise",{}).get("team",-1)==s.team:continue
		var distance: float=eye(id).distance_to(target_position(other))
		if distance>60:continue
		# Nearby opponents can be heard; distant enemies must enter the field of
		# view. Never acquire a silent distant opponent through the back of the head.
		var bearing: Vector3=target_position(other)-eye(id)
		if other!=previous and distance>6 and absf(angle_difference(s.yaw,atan2(-bearing.x,-bearing.z)))>deg_to_rad(110):continue
		if not visible(id,other):continue
		brain.visible.append(other)
		var value:=35.0/(1+distance*.08)+(8 if other==previous else 0)+(12 if game.match_mode.fortress.carrying(other) else 0)
		# A radio call must not distract a bot from an immediate melee threat.
		if distance<4:value+=20
		value+=teamplay.focus_bonus(id,other)
		if value>score:score=value;best=other
	brain.enemy=best
	if best!=0:
		if previous!=best:
			brain.seen_at=game.clock;brain.weapon_at=0
			if teamplay.focus_bonus(id,best)>0:teamplay.count("focus_choices")
		brain.seen_position=game.fighters[best].position;brain.memory_until=game.clock+3
		brain.observed_velocity=game.fighters[best].velocity
		if game.clock>=brain.error_at:
			brain.error_at=game.clock+randf_range(.3,.55)
			brain.aim_error=Vector3(randf_range(-1,1),randf_range(-.65,.65),randf_range(-1,1))*.009
	elif previous!=0:brain.plan_at=0
	teamplay.observe(id,brain)
	perceive_projectiles(id,brain)

func team_rank(id: int) -> int:
	var members: Array=[]
	for other in game.players:
		if other<0 and alive(other) and game.match_mode.same_team(id,other):members.append(other)
	members.sort()
	return maxi(0,members.find(id))
func candidate(rows: Array,key: String,kind: String,position: Vector3,value: float,hold: bool=false,support: int=0) -> void:
	if value>0 and position.is_finite():rows.append({"key":key,"kind":kind,"position":position,"value":value,"hold":hold,"support":support})
func item_value(id: int,pickup: Dictionary) -> float:
	var s: Dictionary=game.players[id]
	var maximum: float=game.match_mode.fortress.max_health(id)
	match pickup.kind:
		"health","bonus":
			if game.match_mode.kind!="tf" and (pickup.kind=="bonus" or pickup.item==100):maximum=200
			if s.hp>=maximum:return 0
			return (150.0 if s.hp<game.match_mode.fortress.max_health(id)*.35 else 55.0)*(1-float(s.hp)/maximum)+minf(pickup.item,50)*.3
		"armor":return maxf(0,pickup.item*100-s.armor)*.4
		"weapon":
			if game.match_mode.kind=="tf":return 0
			if not pickup.item in s.owned:return 55.0 if pickup.item>2 else 12.0
			var ammo: int=game.armory.data(pickup.item).ammo
			return ammo_value(id,ammo)*.5 if ammo>=0 else 0.0
		"ammo":return ammo_value(id,pickup.item)
	return 0
func ammo_value(id: int,ammo: int) -> float:
	var s: Dictionary=game.players[id]
	var usable:=false
	for weapon in s.owned:
		if game.match_mode.fortress.weapon_data(id,weapon).ammo==ammo:usable=true;break
	if game.match_mode.kind=="tf" and ammo==3 and s.tf_class in ["engineer","spy"]:usable=true
	if not usable or s.ammo[ammo]>=game.armory.max_ammo()[ammo]:return 0
	return 70.0*(1-clampf(float(s.ammo[ammo])/([80,20,8,100][ammo]),0,1))

func mode_goals(id: int,brain: Dictionary,rows: Array) -> void:
	var mode=game.match_mode;var s: Dictionary=game.players[id]
	var rank:=team_rank(id)
	brain.role="defend" if rank%3==1 or s.get("tf_class","") in ["engineer","sniper"] else "attack"
	if mode.freeze_tag():
		for friend in mode.special.frozen:
			if mode.same_team(id,friend):candidate(rows,"thaw:%s"%friend,"thaw",game.fighters[friend].position,135,true,friend)
	if mode.kind=="koth":candidate(rows,"hill","objective",mode.hill,100,true)
	if mode.kind in ["ctf","tf"] and s.team in [0,1] and mode.flags.size()==2:
		var own: Dictionary=mode.flags[s.team];var flag: Dictionary=mode.flags[1-s.team]
		if flag.carrier==id:
			candidate(rows,"capture","capture",mode.captures[s.team],240,true)
		elif alive(flag.carrier) and mode.same_team(id,flag.carrier):
			candidate(rows,"escort:%s"%flag.carrier,"escort",teamplay.escort_point(id,flag.carrier),115,true,flag.carrier)
		else:candidate(rows,"flag","objective",flag.position,100 if brain.role=="attack" else 55)
		if own.dropped:
			# Classic TF flags return on a timer, not friendly touch. Defenders
			# cover the dropped flag; attackers keep pursuing the enemy objective.
			if mode.kind=="tf":candidate(rows,"flag:defend","defend",defense_point(id,own.position),145 if brain.role=="defend" else 55,true)
			else:candidate(rows,"return","objective",own.position,180)
		elif alive(own.carrier):
			# Flags are public objective information, unlike unseen combat targets.
			candidate(rows,"intercept","intercept",game.fighters[own.carrier].position,170)
		elif brain.role=="defend":candidate(rows,"defend","defend",defense_point(id,mode.bases[s.team]),95,true)
	if mode.kind=="as":
		var assault=mode.assault
		if not assault.finished and not assault.switching and assault.stage<assault.objectives.size():
			var objective: Dictionary=assault.objectives[assault.stage]
			if s.team==assault.attacking:
				candidate(rows,"as:%s"%assault.stage,"destroy" if int(objective.get("health",0))>0 else "objective",objective.position,160,int(objective.get("health",0))>0)
				var next_checkpoint:=2147483647
				for row in game.map_assault:
					if row.kind=="info_as_checkpoint" and int(row.get("checkpoint",0))>assault.checkpoint:next_checkpoint=mini(next_checkpoint,int(row.checkpoint))
				for row in game.map_assault:
					if row.kind=="info_as_checkpoint" and int(row.get("checkpoint",0))==next_checkpoint:
						candidate(rows,"checkpoint:%s"%next_checkpoint,"checkpoint",row.position,175)
			else:candidate(rows,"as:defend:%s"%assault.stage,"defend",defense_point(id,objective.position),145,true)
	if mode.kind!="tf":return
	var role: String=s.get("tf_class","")
	if role=="medic":
		for friend in game.players:
			if friend==id or not alive(friend) or not mode.same_team(id,friend):continue
			var missing: float=1-float(game.players[friend].hp)/mode.fortress.max_health(friend)
			if missing>0 or mode.fortress.burning(friend):candidate(rows,"heal:%s"%friend,"heal",game.fighters[friend].position,80+missing*100+(40 if mode.fortress.burning(friend) else 0),true,friend)
	if role=="engineer":
		for key in mode.fortress.buildings:
			var b: Dictionary=mode.fortress.buildings[key]
			if b.team==s.team and b.hp<150 and s.ammo[3]>=10 and not b.has("objective"):
				candidate(rows,"repair:%s"%key,"repair",b.position,100+(150-b.hp)*.3,true,key)
	var need: float=maxf(1-float(s.hp)/mode.fortress.max_health(id),1-float(s.armor)/maxf(1,mode.fortress.definition(id).armor))
	for ammo in range(4):need=maxf(need,ammo_value(id,ammo)/70.0)
	if need>.25:
		var stations: Array=game.tf_resupply[s.team] if s.team in [0,1] else []
		if stations.is_empty():stations=mode.spawns(s.team)
		for index in stations.size():candidate(rows,"supply:%s"%index,"supply",stations[index],need*115,true)
		for key in mode.fortress.buildings:
			var b: Dictionary=mode.fortress.buildings[key]
			if b.team==s.team and b.kind=="dispenser" and game.clock>=b.ready:candidate(rows,"dispenser:%s"%key,"supply",b.position,need*115,true)

func defense_point(id: int,anchor: Vector3) -> Vector3:
	# Distinct nearby firing positions avoid stacking defenders on a button/flag.
	var best:=anchor;var value:=-INF
	for index in range(8):
		var angle:=TAU*float(posmod(index+team_rank(id)*3,8))/8
		var point:=anchor+Vector3(cos(angle),0,sin(angle))*4
		point=navigation.project_local(point)
		if point.distance_to(anchor)>7 or navigation.hazardous(point) or not navigation.ray(point+Vector3.UP*1.2,anchor+Vector3.UP).is_empty():continue
		var score: float=-game.fighters[id].position.distance_to(point)*.1
		for friend in brains:
			if friend!=id and alive(friend) and game.match_mode.same_team(id,friend):score-=maxf(0,3-point.distance_to(brains[friend].goal))*4
		if score>value:value=score;best=point
	return best

func cover_goals(id: int,brain: Dictionary,rows: Array) -> void:
	if brain.enemy==0:return
	var s: Dictionary=game.players[id]
	var retreat: bool=s.hp<game.match_mode.fortress.max_health(id)*.45 or brain.visible.size()>2
	if not retreat:return
	var origin: Vector3=game.fighters[id].position
	var threat: Vector3=target_position(brain.enemy)
	for index in range(12):
		var angle:=TAU*index/12.0
		var point:=origin+Vector3(cos(angle),0,sin(angle))*(3.0 if index%2==0 else 6.0)
		point=navigation.project_local(point)
		if point.distance_to(origin)>8 or point.distance_to(origin)<1 or navigation.hazardous(point):continue
		var floor_hit: Dictionary=navigation.ray(point+Vector3.UP*.4,point-Vector3.UP*.7)
		if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
		if navigation.ray(threat,point+Vector3.UP*.8).is_empty():continue
		candidate(rows,"cover:%s"%index,"cover",point,170 if s.hp<35 else 110,true)

func travel_weight(kind: String,distance: float) -> float:
	# A distant team objective must not lose forever to nearby consumables on
	# large Assault maps. Local scavenging still uses the full route distance.
	if kind in ["objective","checkpoint","destroy","capture","defend","intercept","escort"]:return 1+minf(distance,45)*.02
	return 1+distance*.07

func plan(id: int,brain: Dictionary) -> void:
	var rows: Array=[]
	var origin: Vector3=game.fighters[id].position
	for key in brain.avoid.keys():
		if brain.avoid[key]<=game.clock:brain.avoid.erase(key)
	mode_goals(id,brain,rows)
	cover_goals(id,brain,rows)
	teamplay.goals(id,brain,rows)
	for index in game.pickups.size():
		var pickup: Dictionary=game.pickups[index]
		# Arrive near a known respawn, but never wait a full pickup cycle.
		var wait_time: float=maxf(0,pickup.get("respawn",INF)-game.clock) if not pickup.available else 0.0
		if wait_time>3 or game.match_mode.fixed_loadout():continue
		if teamplay.consider_pickup(id,pickup) and teamplay.leaving_pickup(id,pickup):continue
		candidate(rows,"item:%s"%index,"item",pickup.position,item_value(id,pickup)/(1+wait_time*.3))
	if brain.enemy!=0:candidate(rows,"enemy:%s"%brain.enemy,"enemy",brain.seen_position,65)
	elif game.clock<brain.memory_until:candidate(rows,"search","search",brain.seen_position,45)
	for index in game.spawn_points.size():
		var point: Vector3=game.spawn_points[index]
		if origin.distance_to(point)>2:candidate(rows,"roam:%s"%index,"roam",point,8.0+posmod(index-id,3))
	# Cheap distance ranking first, then exact route costs for only six goals.
	for row in rows:
		row.score=row.value/travel_weight(row.kind,origin.distance_to(row.position))
		if row.key==brain.goal_key:row.score*=1.18
		if brain.avoid.has(row.key) or navigation.hazardous(row.position):row.score=0;continue
		for friend in brains:
			if friend==id or not alive(friend) or not game.match_mode.same_team(id,friend):continue
			if brains[friend].goal_key==row.key and row.kind in ["item","heal","repair","thaw","checkpoint","defend","guard","ambush"]:row.score*=.35
	rows.sort_custom(func(a,b):return a.score>b.score)
	var chosen: Dictionary={};var best:=-INF;var route:=PackedVector3Array()
	for index in mini(6,rows.size()):
		var row: Dictionary=rows[index]
		if row.score<=0:continue
		var trial: PackedVector3Array=navigation.path(origin,row.position,game.match_mode.fortress.speed(id)>=.6)
		var distance: float=navigation.cost(origin,row.position,trial)
		row.rocket=false
		if can_rocket_jump(id,brain,row.position) and (not is_finite(distance) or distance>25):
			trial=PackedVector3Array([origin,row.position]);distance=origin.distance_to(row.position)+10;row.rocket=true
		if not is_finite(distance):continue
		var value: float=row.score*travel_weight(row.kind,origin.distance_to(row.position))/travel_weight(row.kind,distance)
		# Penalize exposed routes only against currently observed enemies.
		if row.kind in ["cover","item","supply","capture","heal"]:
			for enemy in brain.visible:
				if navigation.ray(target_position(enemy),(trial[trial.size()/2] if not trial.is_empty() else origin.lerp(row.position,.5))+Vector3.UP).is_empty():value*=.8
		if value>best:best=value;chosen=row;route=trial
	if chosen.is_empty():
		brain.path=PackedVector3Array();brain.goal=origin;brain.goal_key="";brain.goal_kind="idle";brain.hold=true;brain.support=0
		return
	teamplay.selected(id,brain,chosen)
	brain.goal=chosen.position;brain.goal_key=chosen.key;brain.goal_kind=chosen.kind;brain.hold=chosen.hold;brain.support=chosen.support
	brain.path=route;brain.step=0;brain.route_at=game.clock+.8;brain.rocket_route=chosen.get("rocket",false)

func melee_weapon(id: int,weapon: int) -> bool:
	var data: Dictionary=game.match_mode.fortress.weapon_data(id,weapon)
	return int(data.get("ammo",0))<0 and float(data.get("range",100))<4
func ideal_range(id: int,weapon: int) -> float:
	var data: Dictionary=game.match_mode.fortress.weapon_data(id,weapon)
	if melee_weapon(id,weapon):return maxf(.6,float(data.range)*.65)
	if float(data.get("range",100))<20:return float(data.range)*.7
	if int(data.get("pellets",1))>1:return clampf(55/maxf(1,float(data.get("spread",1))),5,18)
	return 18.0 if float(data.get("speed",0))>0 else 24.0
func choose_weapon(id: int,distance: float) -> int:
	var s: Dictionary=game.players[id]
	var best: int=s.weapon;var value:=-INF
	for weapon in s.owned:
		if not game.match_mode.fortress.can_fire(id,weapon):continue
		var data: Dictionary=game.match_mode.fortress.weapon_data(id,weapon)
		if data.get("kind","")=="translocator":continue
		# Estimate useful damage from the actual class/profile data, not Doom's
		# slot numbers (Quake grenades and UT shock occupy shotgun slots).
		var damage: float=float(data.damage)*(1+float(data.get("dice",1)))*.5*int(data.get("pellets",1))
		var spread: float=tan(deg_to_rad(float(data.get("spread",0))))*distance
		var accuracy: float=1.0/(1.0+pow(spread/.65,2))
		var score: float=sqrt(damage/maxf(.1,float(data.cycle)))*8*accuracy
		if float(data.get("speed",0))>0:score/=1+distance/float(data.speed)*.55
		if data.get("kind","") in ["grenade","bio"]:score/=1+pow(distance/15,2)
		if melee_weapon(id,weapon):score=90 if distance<data.range else -20
		if explosive_weapon(id,weapon) and distance<float(data.get("blast_radius",9 if weapon==8 else 5))+1:score=-100
		if game.armory.effective()=="quake" and weapon==8 and game.fighters[id].in_water:score=-1000
		if data.has("range") and distance>data.range:score=-30
		if weapon==s.weapon and score>0:score*=1.12
		if score>value:value=score;best=weapon
	return best
func aim(id: int,point: Vector3,rate: float=.7) -> bool:
	var s: Dictionary=game.players[id]
	var direction: Vector3=(point-eye(id)).normalized()
	var yaw:=atan2(-direction.x,-direction.z)
	s.yaw=lerp_angle(s.yaw,yaw,rate);s.pitch=lerpf(s.pitch,asin(clampf(direction.y,-1,1)),rate)
	return absf(angle_difference(s.yaw,yaw))<.12 and absf(s.pitch-asin(clampf(direction.y,-1,1)))<.12
func explosive_weapon(id: int,weapon: int) -> bool:
	var data: Dictionary=game.match_mode.fortress.weapon_data(id,weapon)
	return float(data.get("splash",0))>0 or game.armory.effective()=="doom" and weapon in [6,8]
func safe_shot(id: int,point: Vector3,explosive: bool=false) -> bool:
	var origin:=eye(id)
	var radius: float=game.match_mode.fortress.weapon_data(id,game.players[id].weapon).get("blast_radius",9 if game.players[id].weapon==8 else 5.76)
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point,3,[game.fighters[id].get_rid()]))
	if not hit.is_empty():
		if hit.collider is CharacterBody3D and "peer_id" in hit.collider and game.match_mode.same_team(id,hit.collider.peer_id):return false
		if explosive and origin.distance_to(hit.position)<radius:return false
	if explosive:
		if origin.distance_to(point)<radius:return false
		for friend in game.players:
			if friend!=id and alive(friend) and game.match_mode.same_team(id,friend) and game.fighters[friend].position.distance_to(point)<radius:return false
	return true
func combat(id: int,brain: Dictionary,delta: float=.2) -> void:
	var s: Dictionary=game.players[id]
	s.fire=false;s.alt_fire=false
	if game.clock<brain.boost_until:return
	if translocator_input(id,brain,delta):return
	if brain.goal_kind=="destroy" and game.match_mode.kind=="as":
		var assault=game.match_mode.assault
		if assault.can_advance(id) and assault.stage<assault.objectives.size():
			var point: Vector3=assault.objectives[assault.stage].position+Vector3.UP*.85
			# Shoot the active objective even while defenders are visible, unless
			# a nearby enemy presents an immediate threat.
			if eye(id).distance_to(point)<30 and (brain.enemy==0 or eye(id).distance_to(target_position(brain.enemy))>6) and navigation.ray(eye(id),point).is_empty():
				s.alt_fire=false;s.weapon=choose_weapon(id,eye(id).distance_to(point));s.fire=aim(id,point,1-exp(-10*delta)) and safe_shot(id,point,explosive_weapon(id,s.weapon))
				return
	if brain.enemy!=0 and alive(brain.enemy):
		var point:=target_position(brain.enemy)
		var distance: float=eye(id).distance_to(point)
		if game.clock>=brain.weapon_at or not game.match_mode.fortress.can_fire(id,s.weapon):
			s.weapon=choose_weapon(id,distance);brain.weapon_at=game.clock+.2
		var data: Dictionary=game.match_mode.fortress.weapon_data(id,s.weapon)
		var alternate:=alternate_fire(id,distance,brain)
		if alternate:data=data.duplicate();data.merge(data.get("alt",{}),true)
		if float(data.get("speed",0))>0:
			var flight: float=minf(.8,distance/data.speed)
			var predicted: Vector3=point+brain.observed_velocity*flight*.85
			predicted.y+=.5*float(data.get("gravity",0))*flight*flight
			if navigation.ray(eye(id),predicted).is_empty():point=predicted
		point+=brain.aim_error*minf(distance,40)
		var aligned:=aim(id,point,1-exp(-10*delta))
		var safe: bool=safe_shot(id,point,explosive_weapon(id,s.weapon) or float(data.get("splash",0))>0)
		if game.armory.effective()=="quake" and s.weapon==8 and game.fighters[id].in_water:safe=false
		s.fire=aligned and game.clock-brain.seen_at>brain.reaction and distance<=data.get("range",100.0) and safe
		if alternate:s.alt_fire=s.fire;s.fire=false
		# Releasing a charged weapon fires it. Cancel through the same blocked
		# input used by menus if the lane has become unsafe before release.
		if game.variant_combat.charging.has(id):
			if not safe:s.input_blocked=true;s.fire=false;s.alt_fire=false
			elif float(game.variant_combat.charging[id].time)>.55 and s.weapon in [1,6]:s.fire=false;s.alt_fire=false
	if brain.enemy==0 and game.variant_combat.charging.has(id):s.input_blocked=true
	if game.match_mode.kind=="tf" and game.clock>=brain.action_at:
		brain.action_at=game.clock+.2;class_action(id,brain)

func translocator_input(id: int,brain: Dictionary,delta: float) -> bool:
	var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if game.armory.effective()!="ut99" or not 11 in s.owned or game.match_mode.kind=="as" or brain.enemy!=0 or game.match_mode.fortress.carrying(id) or actor.in_water:return false
	var combat_system=game.variant_combat
	if game.clock<brain.disc_until and combat_system.discs.has(id):
		var disc: Dictionary=game.projectiles.get(combat_system.discs[id],{})
		if disc.is_empty():return false
		if disc.get("stuck",false):
			var point: Vector3=disc.position
			var floor_hit:=navigation.ray(point+Vector3.UP*.15,point-Vector3.UP*.5)
			var useful: bool=point.distance_to(brain.goal)+3<actor.position.distance_to(brain.goal)
			if useful and point.distance_to(brain.disc_goal)<2.5 and not floor_hit.is_empty() and floor_hit.normal.y>.7 and not navigation.hazardous(point) and navigation.landing_clear(point):
				s.weapon=11;s.alt_fire=true;return true
			brain.disc_until=0
		return false
	if game.clock<brain.translocate_at or not actor.is_supported() or brain.goal_kind in ["cover","defend","heal","repair","destroy","guard","ambush"]:return false
	var offset: Vector3=brain.goal-actor.position;offset.y=0
	if offset.length()<9 or absf(brain.goal.y-actor.position.y)>1:return false
	var destination: Vector3=actor.position+offset.normalized()*minf(14,offset.length())
	var floor_hit:=navigation.ray(destination+Vector3.UP*.6,destination-Vector3.UP)
	if floor_hit.is_empty() or floor_hit.normal.y<.7 or navigation.hazardous(floor_hit.position):return false
	destination=floor_hit.position
	if not navigation.ray(eye(id),destination+Vector3.UP).is_empty():return false
	# Solve the low ballistic arc. The real projectile and server hull test make
	# the final landing decision; a wall impact is never a teleport destination.
	var distance:=Vector2(destination.x-actor.position.x,destination.z-actor.position.z).length()
	var height: float=destination.y-(actor.position.y+1.45)
	var speed:=18.0;var gravity:=19.0
	var discriminant:=pow(speed,4)-gravity*(gravity*distance*distance+2*height*speed*speed)
	if discriminant<=0:return false
	var pitch:=atan((speed*speed-sqrt(discriminant))/(gravity*distance))
	var point: Vector3=eye(id)+offset.normalized()*distance+Vector3.UP*tan(pitch)*distance
	s.weapon=11
	if aim(id,point,1-exp(-10*delta)) and absf(s.pitch-pitch)<.02 and s.cooldown<=0:
		s.fire=true;brain.translocate_at=game.clock+7;brain.disc_until=game.clock+2;brain.disc_goal=destination
	return true

func alternate_fire(id: int,distance: float,brain: Dictionary) -> bool:
	if game.armory.effective()!="ut99":return false
	var s: Dictionary=game.players[id]
	# Once charging, retain that fire mode until release.
	if game.variant_combat.charging.has(id):return game.variant_combat.charging[id].alt
	match s.weapon:
		0:return true # Immediate melee jab; charge is too slow for a passing duel.
		1:return distance>4 and distance<12
		2,5:return distance<8
		3:return distance>7 and distance<16 and posmod(int(game.clock* .5)-id,3)==0
		4:return distance>10 and distance<25
		6:return brain.seen_position.y<game.fighters[id].position.y-3 and distance<16
		7:return distance<16
		10:return distance>4 and distance<10
	return false

func class_action(id: int,brain: Dictionary) -> void:
	var tf=game.match_mode.fortress;var s: Dictionary=game.players[id]
	var role: String=s.tf_class
	var enemy: int=brain.enemy
	var distance: float=eye(id).distance_to(target_position(enemy)) if enemy!=0 else INF
	if role=="medic" and brain.goal_kind=="heal" and alive(brain.support):
		if distance>3 and eye(id).distance_to(target_position(brain.support))<5.8 and visible(id,brain.support):
			s.fire=false;s.alt_fire=false
			if aim(id,target_position(brain.support),1):tf.action(id)
	elif role=="engineer":
		if brain.goal_kind=="repair" and tf.buildings.has(brain.support):
			var point: Vector3=tf.buildings[brain.support].position+Vector3.UP*.7
			if eye(id).distance_to(point)<3.4 and navigation.ray(eye(id),point).is_empty():
				s.fire=false;s.alt_fire=false;aim(id,point,1);tf.action(id)
		elif enemy==0 and brain.goal_kind=="defend" and game.fighters[id].position.distance_to(brain.goal)<5:
			var owned: Array=[]
			for b in tf.buildings.values():
				if b.owner==id:owned.append(b.kind)
			s.tf_tool="dispenser" if "sentry" in owned else "sentry"
			if not s.tf_tool in owned:
				s.pitch=0;tf.action(id)
	elif role=="scout":
		if game.fighters[id].position.distance_to(brain.goal)>10 and not brain.goal_kind in ["cover","defend"]:tf.action(id)
	elif role=="sniper":
		if enemy!=0 and distance>12 and s.fire and brain.stuck<.2:tf.action(id)
	elif role=="heavy":
		if enemy!=0 and distance<22 and brain.goal_kind!="capture":tf.action(id)
	elif role=="spy":
		if enemy==0 and not tf.carrying(id) and not tf.cloaked(id) and s.get("tf_disguise",{}).is_empty():tf.action(id)
	elif role in ["soldier","demoman","pyro"]:
		if role=="demoman" and tf.charges.has(id):
			var charge: Dictionary=tf.charges[id]
			for other in brain.visible:
				if game.fighters[other].position.distance_to(charge.position)<4 and safe_blast(id,charge.position):tf.action(id);break
		elif enemy!=0 and distance>5 and distance<16 and s.fire and safe_blast(id,game.fighters[enemy].position):tf.action(id)
func safe_blast(id: int,point: Vector3) -> bool:
	for other in game.players:
		if alive(other) and (other==id or game.match_mode.same_team(id,other)) and game.fighters[other].position.distance_to(point)<4.5:return false
	return true

func stop_radius(brain: Dictionary) -> float:
	match brain.goal_kind:
		"heal":return 3.5
		"repair":return 2.4
		"escort":return 3.0
		"destroy":return 8.0
		"thaw":return .85
		"supply":return .8
		"defend","cover","guard","ambush":return .65
		"objective":return 1.0 if game.match_mode.kind=="koth" else .4
	return .35
func steer(id: int,brain: Dictionary,delta: float) -> void:
	var s: Dictionary=game.players[id];var actor=game.fighters[id]
	s.jump=false;s.swim=Vector3.ZERO;s.slow=false;s.crouch=false;s.prone=false
	var travel: Vector3=brain.goal-actor.position
	var remaining: float=travel.length()
	var at_goal: bool=remaining<stop_radius(brain) and (brain.hold or brain.goal_kind in ["item","objective","capture"])
	if brain.goal_kind in ["heal","repair","destroy","escort"] and at_goal:
		at_goal=navigation.ray(eye(id),brain.goal+Vector3.UP).is_empty()
	var riding_lift:=false
	if brain.step<brain.path.size():
		while brain.step<brain.path.size()-1 and actor.position.distance_to(brain.path[brain.step])<.65:brain.step+=1
		travel=brain.path[brain.step]-actor.position
		var link: Dictionary=navigation.active_link(actor.position,brain.path[brain.step])
		if not link.is_empty():
			travel=(link.end if link.kind in ["jump","drop"] else link.entry)-actor.position
			if link.kind=="drop":
				brain.drop_end=link.end;brain.drop_until=game.clock+1.5;brain.plan_at=game.clock+1.5
			if link.kind=="pad" and actor.velocity.y>10:
				brain.pad_end=link.end;brain.pad_until=game.clock+4;brain.plan_at=game.clock+3
			if link.kind=="jump" and actor.is_supported() and not actor.jump_held:s.jump=true
			if link.kind=="lift" and actor.position.y<link.end.y-.45:
				var platform: Vector3=link.entry+Vector3.UP*(link.lift.node.position.y-link.lift.base)
				if Vector2(actor.position.x-platform.x,actor.position.z-platform.z).length()<.45:
					travel=Vector3.ZERO;riding_lift=true
				elif platform.y>actor.position.y+.55:travel=Vector3.ZERO;riding_lift=true
	if at_goal:travel=Vector3.ZERO
	if at_goal or riding_lift:
		brain.progress_at=game.clock;brain.progress_position=actor.position
	elif game.clock-brain.progress_at>2.0:
		if actor.position.distance_to(brain.progress_position)<.75:
			brain.recover_direction=recovery_direction(actor.position,travel,id,brain)
			# A swimmer/blast victim can wedge under a thin bridge with its
			# forward probes starting inside the ceiling. Crawl out using the
			# ordinary stance input instead of repeatedly walking into the slab.
			brain.recover_prone=not navigation.ray(actor.position+Vector3.UP*.1,actor.position+Vector3.UP*1.1).is_empty()
			brain.recover_until=game.clock+.65
			brain.avoid[brain.goal_key]=game.clock+3;brain.plan_at=0;brain.path=PackedVector3Array()
		brain.progress_at=game.clock;brain.progress_position=actor.position
	var desired:=Vector3(travel.x,0,travel.z)
	if desired.length()>.1:desired=desired.normalized()
	# Keep useful weapon distance without abandoning objective routes for a duel.
	if brain.enemy!=0 and brain.goal_kind=="enemy":
		var distance: float=actor.position.distance_to(game.fighters[brain.enemy].position)
		var ideal: float=ideal_range(id,s.weapon)
		if distance<ideal*.65:desired=-desired
		elif distance<ideal*1.25:
			if game.clock>=brain.strafe_at:
				brain.strafe_at=game.clock+randf_range(.55,1.6);brain.strafe=1.0 if randf()>.5 else -1.0
			desired=desired.cross(Vector3.UP)*brain.strafe
	if brain.enemy==0 and brain.goal_kind not in ["heal","repair","destroy"] and desired.length()>.1:
		s.yaw=lerp_angle(s.yaw,atan2(-desired.x,-desired.z),minf(1,delta*10))
	if at_goal and brain.enemy==0 and brain.goal_kind in ["guard","ambush"]:
		aim(id,brain.watch+Vector3.UP,1-exp(-6*delta))
		s.crouch=brain.goal_kind=="ambush"
	if game.clock<brain.dodge_until:desired=brain.dodge;at_goal=false
	if game.clock<brain.recover_until:desired=brain.recover_direction;at_goal=false
	# Separate teammates locally while retaining the chosen route.
	if not at_goal:
		for friend in game.fighters:
			if friend==id or not alive(friend) or not game.match_mode.same_team(id,friend):continue
			var offset: Vector3=actor.position-game.fighters[friend].position;offset.y=0
			if offset.length()>.05 and offset.length()<1.2:desired+=offset.normalized()*(1.2-offset.length())*.8
		desired=desired.limit_length(1)
	if actor.in_water:
		var stroke:=Vector3(desired.x,clampf(travel.y*.8,-1,1),desired.z).limit_length(1)
		if actor.underwater and travel.y>=-.2:stroke.y=maxf(.6,stroke.y)
		s.swim=Basis(Vector3.UP,-s.yaw)*stroke
		s.jump=travel.y>.25 and not actor.jump_held
	elif desired.length()>.1:
		var forward:=desired.normalized()
		var look: Vector3=actor.position+forward*1.0
		var low:=not navigation.ray(actor.position+Vector3.UP*.4,look+Vector3.UP*.4).is_empty()
		var middle:=not navigation.ray(actor.position+Vector3.UP*.9,look+Vector3.UP*.9).is_empty()
		var high:=not navigation.ray(actor.position+Vector3.UP*1.55,look+Vector3.UP*1.55).is_empty()
		if high and not middle:s.crouch=true
		elif middle and not low:s.prone=true
		var landing: Dictionary=navigation.ray(look+Vector3.UP*.6,look-Vector3.UP*2.2)
		var safe_floor: bool=not landing.is_empty() and landing.normal.y>.65 and not navigation.hazardous(landing.position)
		if actor.is_supported():
			if not safe_floor:
				var beyond: Vector3=actor.position+forward*3.0
				var floor_hit: Dictionary=navigation.ray(beyond+Vector3.UP, beyond-Vector3.UP*1.2)
				if not floor_hit.is_empty() and floor_hit.normal.y>.7 and not navigation.hazardous(floor_hit.position) and navigation.jump_clear(actor.position,floor_hit.position,9.4*actor.speed_multiplier):
					s.jump=not actor.jump_held
				else:desired=Vector3.ZERO;brain.stuck+=delta
			elif low and not middle and navigation.jump_clear(actor.position,actor.position+forward*2.5,9.4*actor.speed_multiplier):s.jump=not actor.jump_held
			elif not high and not middle and not low and remaining>7 and travel.length()>5 and not s.crouch and not s.prone and brain.goal_kind not in ["cover","defend","heal","repair","guard","ambush"]:
				# Release every airborne frame; a fresh press on landing preserves
				# Quake momentum without bypassing the jump edge/queue rules.
				var ahead: Vector3=actor.position+forward*4.0
				var floor_hit: Dictionary=navigation.ray(ahead+Vector3.UP*.6,ahead-Vector3.UP)
				if not floor_hit.is_empty() and not navigation.hazardous(floor_hit.position) and navigation.jump_clear(actor.position,floor_hit.position,9.4*actor.speed_multiplier):s.jump=not actor.jump_held
		if low and middle and not s.prone:
			var side:=forward.cross(Vector3.UP)*(1 if id%2==0 else -1)
			if navigation.ray(actor.position+Vector3.UP,actor.position+side+Vector3.UP).is_empty():desired=(forward+side).normalized()
		# Brake before a close corner; air control opposes unwanted sideways drift.
		if not actor.is_supported():
			var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
			var lateral:=velocity-forward*velocity.dot(forward)
			desired=(desired-lateral*.09).limit_length(1)
		elif travel.length()<2 and remaining>2:desired*=.6
	if at_goal and brain.goal_kind=="cover":s.crouch=true
	if at_goal and brain.goal_kind=="defend" and brain.enemy!=0:
		s.crouch=true
		if s.get("tf_class","")=="sniper" and actor.position.distance_to(brain.seen_position)>20:s.prone=true;s.crouch=false
	if brain.rocket_route and can_rocket_jump(id,brain,brain.goal) and actor.is_supported() and s.cooldown<=0:
		brain.boost_until=game.clock+.35;brain.boost_at=game.clock+5;brain.boost_shots=s.shots
		brain.plan_at=game.clock+2;brain.rocket_route=false
		s.jump=not actor.jump_held
	if game.clock<brain.boost_until:
		s.weapon=6;s.pitch=-1.45;s.fire=s.shots==brain.boost_shots
		# Leave the muzzle over solid ground for the takeoff shot.
		desired*=.2
	elif game.clock<brain.boost_at-3 and not actor.is_supported():
		# Brake above the landing rather than sailing over it with blast momentum.
		var horizontal:=Vector3(actor.velocity.x,0,actor.velocity.z)
		var offset:=Vector3(brain.goal.x-actor.position.x,0,brain.goal.z-actor.position.z)
		desired=(offset*.7-horizontal*.18).limit_length(1)
	if game.clock<brain.drop_until:
		var offset:=Vector3(brain.drop_end.x-actor.position.x,0,brain.drop_end.z-actor.position.z)
		var horizontal:=Vector3(actor.velocity.x,0,actor.velocity.z)
		desired=(offset*.9-horizontal*.18).limit_length(.6);s.jump=false
		if actor.is_supported() and actor.position.y<brain.drop_end.y+.5:brain.drop_until=0;brain.plan_at=0
	if game.clock<brain.recover_until and not brain.recover_direction.is_zero_approx():
		desired=brain.recover_direction
		if brain.recover_jump and actor.is_supported():s.jump=not actor.jump_held
	if game.clock<brain.recover_until and brain.recover_prone:s.prone=true;s.crouch=false;s.jump=false
	if game.clock<brain.pad_until:
		var horizontal:=Vector3(actor.velocity.x,0,actor.velocity.z)
		var offset:=Vector3(brain.pad_end.x-actor.position.x,0,brain.pad_end.z-actor.position.z)
		# Rise clear of the roof edge, then steer and brake over the landing.
		desired=Vector3.ZERO if actor.velocity.y>0 and actor.position.y<brain.pad_end.y+.35 else (offset*.9-horizontal*.2).limit_length(1)
		if actor.is_supported() and actor.position.y>brain.pad_end.y-.5:brain.pad_until=0;brain.plan_at=0
	var local: Vector3=Basis(Vector3.UP,-s.yaw)*desired
	s.move=Vector2(local.x,local.z).limit_length(1)
	if not at_goal and not riding_lift and travel.length()>.1 and actor.position.distance_to(brain.last)<delta*.5:brain.stuck+=delta
	elif actor.position.distance_to(brain.last)>delta:brain.stuck=maxf(0,brain.stuck-delta*2)
	else:brain.stuck=0
	if riding_lift:brain.stuck=0;brain.plan_at=game.clock+.8
	if brain.stuck>1.5:
		brain.avoid[brain.goal_key]=game.clock+6;brain.plan_at=0;brain.stuck=0
		brain.path=PackedVector3Array()
	if at_goal and brain.goal_kind in ["item","objective","capture","checkpoint"]:brain.plan_at=minf(brain.plan_at,game.clock+.2)
	brain.last=actor.position

func recovery_direction(position: Vector3,travel: Vector3,id: int,brain: Dictionary={}) -> Vector3:
	brain.recover_jump=false
	var forward:=Vector3(travel.x,0,travel.z).normalized()
	if forward.is_zero_approx():forward=Vector3.FORWARD
	# Back out of a snag, then retry the route. Check the floor and a torso-height
	# wall before issuing ordinary movement; never warp or force a respawn.
	for angle in [PI,PI*.5*(1 if id%2==0 else -1),-PI*.5*(1 if id%2==0 else -1),PI*.75,-PI*.75]:
		var direction:=forward.rotated(Vector3.UP,angle)
		var point:=position+direction*1.2
		var floor_hit:=navigation.ray(point+Vector3.UP*.6,point-Vector3.UP*6.5)
		if not floor_hit.is_empty() and floor_hit.normal.y>.7 and not navigation.hazardous(floor_hit.position) and navigation.ray(position+Vector3.UP,point+Vector3.UP).is_empty():
			var obstacle: bool=floor_hit.position.y>position.y+.4 or not navigation.ray(position+Vector3.UP*.35,point+Vector3.UP*.35).is_empty()
			if obstacle and not navigation.jump_clear(position,floor_hit.position):continue
			brain.recover_jump=obstacle
			return direction
	return Vector3.ZERO

func can_rocket_jump(id: int,brain: Dictionary,goal: Vector3) -> bool:
	var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if game.armory.effective()!="doom" or game.clock<brain.boost_at or brain.enemy!=0 or actor.in_water or s.invulnerable>game.clock or s.charge>0:return false
	if not 6 in s.owned or s.ammo[2]<2 or s.hp<90 or s.armor<25 or game.match_mode.fortress.carrying(id):return false
	var rise: float=goal.y-actor.position.y
	var distance:=Vector2(goal.x-actor.position.x,goal.z-actor.position.z).length()
	if rise<1.5 or rise>4 or distance>5 or distance<1:return false
	for friend in game.players:
		if friend!=id and alive(friend) and game.match_mode.same_team(id,friend) and actor.position.distance_to(game.fighters[friend].position)<6:return false
	if navigation.hazardous(goal):return false
	var floor_hit: Dictionary=navigation.ray(goal+Vector3.UP*.2,goal-Vector3.UP*.5)
	if floor_hit.is_empty() or floor_hit.normal.y<.8:return false
	# Require a clear overhead corridor for the full blast arc (vertical speed is
	# capped at 20 by Fighter). The actual takeoff spends a rocket and health.
	for index in range(6):
		var point: Vector3=actor.position.lerp(goal,index/5.0)
		var bottom: Vector3=actor.position+Vector3.UP*1.7 if index==0 else point+Vector3.UP*1.7
		if not navigation.ray(bottom,Vector3(point.x,actor.position.y+12,point.z)).is_empty():return false
	return true

func perceive_projectiles(id: int,brain: Dictionary) -> void:
	var origin:=target_position(id)
	for projectile in game.projectiles.values():
		if projectile.owner==id or game.match_mode.same_team(id,projectile.owner):continue
		var offset: Vector3=origin-projectile.position
		if offset.length()>10 or not navigation.ray(eye(id),projectile.position).is_empty():continue
		var direction: Vector3=projectile.get("direction",Vector3.ZERO)
		if projectile.has("velocity"):direction=projectile.velocity.normalized()
		if direction.dot(offset.normalized())<.8:continue
		var side:=direction.cross(Vector3.UP).normalized()
		if side.is_zero_approx():continue
		if side.dot(offset)<0:side=-side
		for sign_value in [1,-1]:
			var dodge: Vector3=side*sign_value
			var point: Vector3=game.fighters[id].position+dodge*2
			var floor_hit: Dictionary=navigation.ray(point+Vector3.UP*.5,point-Vector3.UP)
			if not floor_hit.is_empty() and floor_hit.normal.y>.7 and not navigation.hazardous(floor_hit.position) and navigation.ray(eye(id),point+Vector3.UP).is_empty():
				brain.dodge=dodge;brain.dodge_until=game.clock+.35;return
