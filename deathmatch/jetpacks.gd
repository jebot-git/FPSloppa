extends RefCounted
## Authority chooses a small layout once per map/round; clients receive its exact
## positions before applying the ordinary pickup availability bitset.
const MODES=["dm","tdm","ctf","ig","if","ft"]
var game
func enabled() -> bool:return game.armory.effective()!="tribes" and game.match_mode.jetpacks and game.match_mode.kind in MODES and not game.lobby.active()
func allowed(p: Dictionary) -> bool:
	if game.match_mode.defusal.enabled():return p.get("dropped",false) and p.kind=="weapon"
	return enabled() if p.kind=="jetpack" else not game.match_mode.fixed_loadout()
func clear() -> void:
	for i in range(game.pickups.size()-1,-1,-1):
		if game.pickups[i].kind!="jetpack":continue
		var node=game.pickups[i].get("node")
		if is_instance_valid(node):node.free()
		game.pickups.remove_at(i)
func clear_player(id: int) -> void:
	if game.players.has(id):game.players[id].jetpack=false;game.players[id].jetpack_pending=false
	if game.fighters.has(id):game.fighters[id].configure_jetpack(false);game.fighters[id].reset_jetpack();game.fighters[id].reset_tribes()
func configure_player(id: int,blocked: bool=false) -> void:
	var s: Dictionary=game.players[id]
	game.fighters[id].configure_jetpack(enabled() and s.get("jetpack",false) and not s.dead and not s.spectator and not game.match_mode.special.blocked(id) and game.intermission<=0,blocked)
func collect(id: int) -> bool:
	var s: Dictionary=game.players[id]
	if not enabled() or s.get("jetpack",false) or s.dead or s.spectator or game.match_mode.special.blocked(id):return false
	s.jetpack=true;s.jetpack_pending=false;game.fighters[id].reset_jetpack();configure_player(id)
	return true
func positions() -> Array:
	var result: Array=[]
	for p in game.pickups:
		if p.kind=="jetpack":result.append(p.position)
	return result
func add(at: Vector3) -> void:
	var p:={"kind":"jetpack","item":0,"position":at,"available":true,"respawn":0.0,"node":null,"title":"JETPACK · DOUBLE-TAP JUMP"}
	if not game.headless:p.node=game._pickup_art(p)
	game.pickups.append(p)
func receive(value: Variant) -> void:
	var next: Array=[]
	if enabled() and value is Array:
		for point in value.slice(0,2 if game.match_mode.kind=="ctf" else 1):
			if point is Vector3 and point.is_finite() and not next.any(func(other):return point.distance_to(other)<2):next.append(point)
	if positions()==next:return
	clear()
	for point in next:add(point)
func rebuild() -> void:
	clear()
	if not enabled():return
	var used: Array=[]
	var teams: Array=[0,1] if game.match_mode.kind=="ctf" and game.match_mode.bases.size()==2 else [-1]
	for team in teams:
		var candidates: Array=[]
		var base: Vector3=game.match_mode.bases[team] if team>=0 else Vector3.ZERO
		for p in game.pickups:
			if p.kind=="jetpack" or team>=0 and p.position.distance_squared_to(base)>p.position.distance_squared_to(game.match_mode.bases[1-team]):continue
			candidates.append({"point":p.position,"rank":p.position.distance_squared_to(base) if team>=0 else 0.0 if p.kind=="health" and p.item==100 else 100.0})
		candidates.sort_custom(func(a,b):return a.rank<b.rank)
		var spawns: Array=game.spawn_points.filter(func(point):return team<0 or point.distance_squared_to(base)<=point.distance_squared_to(game.match_mode.bases[1-team]))
		if team>=0:spawns.sort_custom(func(a,b):return a.distance_squared_to(base)<b.distance_squared_to(base))
		for point in spawns:candidates.append({"point":point,"rank":INF})
		var selected: Variant=null
		for row in candidates:
			selected=site(row.point,used,team)
			if selected!=null:break
		# Spawn floors are authored playable anchors, including during the first
		# frame before freshly instanced collision is registered with physics.
		if selected==null:
			for point in spawns:
				if used.all(func(other):return point.distance_to(other)>2):selected=point;break
		if selected!=null:used.append(selected);add(selected)
func site(seed: Vector3,used: Array,team: int) -> Variant:
	var space=game.get_world_3d().direct_space_state
	for offset in [Vector3(1.7,0,0),Vector3(-1.7,0,0),Vector3(0,0,1.7),Vector3(0,0,-1.7),Vector3.ZERO]:
		var point: Vector3=seed+offset
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,point-Vector3.UP*2,1))
		if hit.is_empty() or hit.normal.y<.75:continue
		point=hit.position+Vector3.UP*.05
		if team>=0 and point.distance_squared_to(game.match_mode.bases[team])>point.distance_squared_to(game.match_mode.bases[1-team]):continue
		if used.any(func(other):return point.distance_to(other)<2) or game.pickups.any(func(p):return p.position.distance_to(point)<1.35):continue
		var shape:=CapsuleShape3D.new();shape.radius=.35;shape.height=1.65
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=point+Vector3.UP*.84
		if space.intersect_shape(query,1).is_empty():return point
	return null
