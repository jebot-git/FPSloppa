extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var errors: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for z in range(ceili(Landscape.CENTERS[2].z+70),ceili(Landscape.EXTENT/2)+1,2):
		var x: float=Landscape.CENTERS[2].x+sin(maxf(0,z-Landscape.CENTERS[2].z-68)*.003)*28
		check(Landscape.water_mask(x,z)>.99,"continuous harbour to map edge")
		check(absf(Landscape.surface(x,z).x-Landscape.SEA_LEVEL)<.001,"continuous sea level")
		check(not Landscape.planting_allowed(Vector2(x,z)),"no submerged vegetation")
	check(not Landscape.in_water(Landscape.CENTERS[2]+Vector3(0,.3,55)),"quay safe")
	check(not Landscape.in_water(Landscape.CENTERS[2]+Vector3(49,.3,103)),"pier safe")
	check(not Landscape.in_water(Landscape.CENTERS[2]+Vector3(0,3,200)),"jetpack above water safe")
	var game=load("res://tools/voxel_battle/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	game.dedicated=true;game.max_clients=2;game.bot_population.count_target=2;game.selected_map="voxel_jungle"
	game.match_mode.configure({"sv_gametype":"tdm","sv_friendlyfire":0})
	game.start_host("Water probe",0,100,10,true,"tdm","cs")
	var deadline:=Time.get_ticks_msec()+120000
	while not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("Water probe navigation timed out");quit(1);return
		await physics_frame
	await physics_frame;await physics_frame
	var submerged_vertices:=0
	for vertex in game.bots.region.navigation_mesh.get_vertices():
		if Landscape.in_water(vertex):submerged_vertices+=1
	check(submerged_vertices==0,"navigation has no lethal-water vertices")
	var id: int=game.players.keys()[0];var state: Dictionary=game.players[id]
	var actor=game.fighters[id]
	actor.position=Landscape.CENTERS[2]+Vector3(49,.3,103)
	game._check_water();check(not state.dead,"real fighter on pier survives")
	var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Landscape.CENTERS[2]+Vector3(0,-1.4,200),Landscape.CENTERS[2]+Vector3(0,-4.4,200),1))
	check(hit.is_empty(),"no walkable underwater collider")
	actor.position=Landscape.CENTERS[2]+Vector3(0,-2.3,200);state.armor=200;state.invulnerable=game.clock+100
	var deaths: int=state.deaths;var enemy_score: int=game.match_mode.scores[1-state.team]
	game._check_water()
	check(state.dead and state.hp==0,"water immediately kills through armor and spawn protection")
	check(state.deaths==deaths+1,"water death counted once")
	check(state.respawn_at==game.clock+2,"normal TDM respawn scheduled")
	check(game.match_mode.scores[1-state.team]==enemy_score,"water grants no enemy frag")
	game._check_water();check(state.deaths==deaths+1,"water does not repeat a dead fighter kill")
	game._spawn(id);check(not state.dead and not Landscape.in_water(actor.position),"respawn returns to dry spawn")
	var report:={"checks":checks,"errors":errors,"water_level":Landscape.SEA_LEVEL,"extends_to_z":Landscape.EXTENT/2,"killzone":"authoritative immediate environmental death"}
	DirAccess.make_dir_recursive_absolute("res://test-results/jungle-terrain")
	FileAccess.open("res://test-results/jungle-terrain/water.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WATER_VALIDATION ",JSON.stringify(report));game.free();await process_frame;quit(0 if errors.is_empty() else 1)
