extends Node
## Offline authority-only bots. Their input uses the same movement, ammo and damage code.
var game
var region: NavigationRegion3D
var brains: Dictionary={}
var ready_to_walk:=false
func setup(arena: Node) -> void:
	game=arena
	region=NavigationRegion3D.new()
	add_child(region)
	var cached: String=preload("res://deathmatch/assets/paths.gd").folder("maps")+"navigation/"+game.current_map+".res"
	if ResourceLoader.exists(cached):
		region.navigation_mesh=load(cached)
		ready_to_walk=true
	else:
		var mesh:=new_mesh()
		region.navigation_mesh=mesh
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,game.get_node("Map").get_child(0))
		NavigationServer3D.bake_from_source_geometry_data_async(mesh,data,func(): ready_to_walk=true)
	for id in game.players:
		if id<0: brains[id]={"next":game.clock+randf()*.2,"goal":game.fighters[id].position,"last":game.fighters[id].position,"stuck":0.0,"path":PackedVector3Array(),"step":0,"route_at":0.0,"enemy":0,"seen_at":0.0}
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
func tick(_delta: float) -> void:
	for id in brains:
		var s: Dictionary=game.players[id]
		if s.dead or game.match_mode.special.blocked(id): continue
		var brain: Dictionary=brains[id]
		if game.clock<brain.next: continue
		brain.next=game.clock+.2
		s.last_input=game.clock
		s.fire=false;s.jump=false;s.room=Vector3.ZERO
		var actor: CharacterBody3D=game.fighters[id]
		var eye:=actor.position+Vector3.UP*1.4
		var enemy:=0
		var nearest:=35.0
		for other in game.players:
			if other==id or game.players[other].dead or game.players[other].spectator or game.match_mode.same_team(id,other) or game.match_mode.special.frozen.has(other): continue
			var target: Vector3=game.fighters[other].position+Vector3.UP*1.1
			var distance:=eye.distance_to(target)
			if distance>=nearest: continue
			var query:=PhysicsRayQueryParameters3D.create(eye,target,3,[actor.get_rid()])
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider==game.fighters[other]: enemy=other;nearest=distance
		if enemy!=brain.enemy: brain.seen_at=game.clock
		brain.enemy=enemy
		if enemy!=0:
			brain.goal=game.fighters[enemy].position
			var direction: Vector3=(brain.goal+Vector3.UP*1.1-eye).normalized()
			var aim:=atan2(-direction.x,-direction.z)
			s.yaw=lerp_angle(s.yaw,aim,.65)
			s.pitch=clampf(asin(direction.y)+randf_range(-.025,.025),-1.3,1.3)
			s.fire=game.clock-brain.seen_at>.35 and absf(angle_difference(s.yaw,aim))<.12
			# Prefer collected weapons; never grant equipment or ammunition.
			for weapon in [5,4,3,7,2]:
				if weapon in s.owned and game.W.can_fire(weapon,s.ammo): s.weapon=weapon;break
		if actor.position.distance_to(brain.goal)<1.2 or brain.stuck>1.2:
			var choices: Array=[]
			for pickup in game.pickups:
				if pickup.available: choices.append(pickup.position)
			brain.goal=choices.pick_random() if not choices.is_empty() else game.spawn_points.pick_random()
			brain.stuck=0.0;brain.route_at=0.0
		if game.match_mode.kind=="ft":
			for friend in game.match_mode.special.frozen:
				if game.match_mode.same_team(id,friend):brain.goal=game.fighters[friend].position;break
		var travel: Vector3=brain.goal-actor.position
		if ready_to_walk and game.clock>=brain.route_at:
			brain.path=NavigationServer3D.map_get_path(region.get_navigation_map(),actor.position,brain.goal,true)
			brain.step=0;brain.route_at=game.clock+.6
		if brain.step<brain.path.size():
			while brain.step<brain.path.size()-1 and actor.position.distance_to(brain.path[brain.step])<.8: brain.step+=1
			travel=brain.path[brain.step]-actor.position
		if enemy==0 and travel.length()>.1: s.yaw=lerp_angle(s.yaw,atan2(-travel.x,-travel.z),.7)
		var local: Vector3=Basis(Vector3.UP,-s.yaw)*travel
		s.move=Vector2(local.x,local.z).normalized()*.75
		if enemy!=0 and nearest<5 and s.weapon!=1: s.move=Vector2(sin(game.clock+id)*.65,.25)
		if game.match_mode.kind=="ft":
			for friend in game.match_mode.special.frozen:
				if game.match_mode.same_team(id,friend) and game.match_mode.nearby(id,game.fighters[friend].position,1.2):s.move=Vector2.ZERO
		brain.stuck=brain.stuck+.2 if actor.position.distance_to(brain.last)<.15 else 0.0
		s.jump=brain.stuck>.4 and not actor.jump_held
		brain.last=actor.position
