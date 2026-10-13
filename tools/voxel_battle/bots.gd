extends "res://deathmatch/bots.gd"
func setup(arena: Node) -> void:
	game=arena;teamplay.ai=self;objectives.ai=self;titanball.ai=self
	region=NavigationRegion3D.new();add_child(region)
	NavigationServer3D.map_set_cell_size(region.get_navigation_map(),.3)
	NavigationServer3D.map_set_use_edge_connections(region.get_navigation_map(),false)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(region.get_navigation_map(),.001)
	navigation=preload("res://tools/voxel_battle/jungle_routing.gd").new();navigation.map_source=game.battle_map
	navigation.setup(game,region);map_triggers.setup(self)
	for id in game.players:
		if id<0:brains[id]=new_brain(id)
	var chunks=await preload("res://tools/voxel_battle/jungle_navigation.gd").build(game.battle_map)
	add_child(chunks)
	var old:=region
	for child in chunks.get_children():
		if child is NavigationRegion3D and child.navigation_mesh.get_polygon_count()>0:region=child;break
	navigation.region=region;old.queue_free();ready_to_walk=true
var tick_ms: Array=[]
func tick(delta: float) -> void:
	var begin:=Time.get_ticks_usec()
	super.tick(delta)
	tick_ms.append((Time.get_ticks_usec()-begin)/1000.0)
var boosts:=0
var patrols: Dictionary={}
func choose_weapon(id: int,distance: float,enemy: int=0) -> int:
	var s: Dictionary=game.players[id]
	var primary: int=s.owned[-1]
	var bucket: int=game.armory.data(primary).ammo
	if s.ammo[bucket]>0 or s.cs_reserve[bucket]>0:return primary
	if s.ammo[1]>0 or s.cs_reserve[1]>0:return 2
	return super.choose_weapon(id,distance,enemy)
func plan(id: int,brain: Dictionary) -> void:
	if brain.enemy!=0:
		super.plan(id,brain);return
	if not navigation.ready():return
	var actor=game.fighters[id]
	var points: Array[Vector3]=game.battle_map.routes
	var index: int=patrols.get(id,posmod(-id*7,points.size()))
	if actor.position.distance_to(points[index])<2:index=posmod(index+1,points.size())
	# Continue an authored entry/interior/road circuit until reached. Failed routes
	# are skipped; ordinary navigation and collision still control all movement.
	for attempt in 8:
		var route:=navigation.path(actor.position,points[index],false)
		if not route.is_empty():
			brain.goal=points[index];brain.goal_key="valley:%d"%index;brain.goal_kind="roam";brain.hold=false
			brain.path=route;brain.step=0;brain.route_at=game.clock+.8;patrols[id]=index;return
		index=posmod(index+1,points.size())
	patrols[id]=index
func steer(id: int,brain: Dictionary,delta: float) -> void:
	super.steer(id,brain,delta)
	jetpack_steer(id,brain)
func jetpack_steer(id: int,brain: Dictionary) -> void:
	var actor=game.fighters[id]
	if actor.jetpack_state.cooldown>0 or actor.jetpack_state.mode!=0 or not actor.is_supported():return
	if brain.step>=brain.path.size():return
	var destination: Vector3=brain.path[brain.step]
	var travel: Vector3=destination-actor.position;travel.y=0
	if travel.length()<22 or game.players[id].move.length()<.8:return
	var direction: Vector3=travel.normalized()
	# A clear outdoor corridor and walkable landing are required before takeoff.
	# This prevents blindly boosting into low ceilings, walls, water, or map edges.
	var landing: Vector3=actor.position+direction*32
	var projected:=NavigationServer3D.map_get_closest_point(region.get_navigation_map(),landing)
	if Vector2(projected.x-landing.x,projected.z-landing.z).length()>2 or absf(projected.y-actor.position.y)>3:return
	for height in [1.0,3.0,6.0,8.0]:
		if not navigation.ray(actor.position+Vector3.UP*height,landing+Vector3.UP*height).is_empty():return
	if not navigation.ray(actor.position+Vector3.UP,actor.position+Vector3.UP*8).is_empty():return
	game.players[id].jetpack_pending=true;boosts+=1
