extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_battery_tank.gd")
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Fixture.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Frontier",28814,10,1,false)
	game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED
	game._add_player(2,"Enemy");game.players[1].team=0;game.players[2].team=1
	var actor=game.fighters[1];check(actor.cs16_enabled and not actor.quake_movement and is_equal_approx(actor.movement_speed(),250.0/32),"CS movement defaults independently of UT99 class weapons")
	check(not game.has_method("set_cq_movement"),"CQ exposes no movement profile toggle")
	game._add_player(3,"Late join");check(game.fighters[3].cs16_enabled and not game.fighters[3].quake_movement and game.fighters[3].body_shape.shape is CylinderShape3D,"New players always use CS cylinders")
	var admin=preload("res://deathmatch/server/rcon.gd").new();admin.game=game
	check(admin.execute("movement quake").has("error") and actor.cs16_enabled and actor.body_shape.shape is CylinderShape3D,"Retired RCON command cannot enable Quake")
	check(admin.execute("status").movement=="cs","RCON reports fixed CS movement");admin.free()
	var config=preload("res://deathmatch/server/config.gd")
	var retired_config:Dictionary=config.parse('set sv_cq_quake_movement "1"')
	check(not config.DEFAULTS.has("sv_cq_quake_movement") and not retired_config.has("error") and not retired_config.values.has("sv_cq_quake_movement"),"Legacy config loads without restoring retired option")
	var old_snapshot:Dictionary=game.match_mode.snapshot();old_snapshot.cq_movement={"quake":true};game.match_mode.receive(old_snapshot)
	check(actor.cs16_enabled and not actor.quake_movement,"Legacy movement snapshot cannot select Quake")
	check(game.match_mode.objectives.sites.size()==11,"All eleven jungle POIs have capture areas")
	var geometry=preload("res://tools/voxel_battle/architecture.gd").new();geometry.generate()
	for zone in 11:
		var site:Dictionary=game.match_mode.objectives.sites[zone];var p:Vector3=site.position
		var room:Dictionary=site.building;var local:Vector3=p-game.match_mode.objectives.Landscape.CENTERS[zone]-room.center
		check(absf(local.x)+3<room.size.x*.5 and absf(local.z)+3<room.size.y*.5,"Capture cylinder enclosed within covered room "+site.name)
		var capsule:=AABB(p+Vector3(-.3,.02,-.3),Vector3(.6,1.65,.6));var clear:=true
		for box in geometry.boxes:
			if box.kind==zone and capsule.intersects(AABB(game.match_mode.objectives.Landscape.CENTERS[zone]+box.center-box.size*.5,box.size)):clear=false
		check(clear,"Capture center has human-sized clearance "+site.name)
	# Fixture geometry is flat, so put one objective on its actual test floor.
	game.match_mode.objectives.sites[0].position=Vector3(10,.03,-10)
	game.fighters[1].position=Vector3(10,.03,-10);game.fighters[2].position=Vector3(15,.03,-10);game.fighters[3].position=Vector3(30,.03,-10)
	for id in game.players:game.players[id].invulnerable=0;game.players[id].fire=false;game.players[id].move=Vector2.ZERO
	await physics_frame;await physics_frame
	check(game.match_mode.objectives.present(1,0),"Living on-foot player can capture")
	game.classes.downed[1]={"remaining":10};check(not game.match_mode.objectives.present(1,0),"Incapacitated player cannot capture");game.classes.downed.clear()
	game.battery_tanks.rows[0].pilot=1;check(not game.match_mode.objectives.present(1,0),"Seated crew cannot capture");game.battery_tanks.rows[0].pilot=0
	var wall:=StaticBody3D.new();wall.position=Vector3(11,.9,-10);var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.2,2,4);collider.shape=shape;wall.add_child(collider);game.get_node("Map").add_child(wall)
	game.fighters[1].position=Vector3(12,.03,-10);await physics_frame;check(not game.match_mode.objectives.present(1,0),"Capture cannot pass through a wall");wall.free()
	game.fighters[1].position=Vector3(10,.03,-10);await physics_frame
	game.match_mode.tick(10);check(game.match_mode.objectives.rules.owners[0]==0 and game.match_mode.scores==[0,0],"Authority captures covered POI after ten seconds")
	game.match_mode.tick(10);check(game.match_mode.scores==[1,0],"Authoritative holding income")
	game.match_mode.killed(2,1);check(game.match_mode.scores==[2,0],"One owned POI gives one enemy kill point")
	game.match_mode.killed(1,1);check(game.match_mode.scores==[2,0],"Suicide gives no territory points")
	game.players[2].team=0;game.match_mode.killed(2,1);check(game.match_mode.scores==[2,0],"Friendly kill gives no territory points");game.players[2].team=1
	game.round_left=.01;game.clock+=.1;game._server_tick(.1);check(game.intermission==0 and game.round_left==.01,"Configured time limit cannot end first-to-200 CQ")
	game.match_mode.objectives.rules.scores=[199,0];game.match_mode.killed(2,1);check(game.intermission>0 and game.match_mode.scores==[200,0] and game.round_message.begins_with("RED WINS"),"Kill reaching 200 ends round with correct winner")
	game.match_mode.reset();game.intermission=0;check(game.match_mode.scores==[0,0] and game.match_mode.objectives.rules.owners.all(func(owner):return owner==-1),"Restart clears scores, capture progress and ownership")
	check(not preload("res://deathmatch/server/config.gd").parse(FileAccess.get_file_as_string("res://tools/voxel_battle/cq_classes.cfg")).has("error"),"Dedicated CQ config accepts fixed CS movement")
	var normal_cfg:String=FileAccess.get_file_as_string("res://tools/voxel_battle/cq_classes.cfg")
	var experimental_cfg:String=FileAccess.get_file_as_string("res://tools/voxel_battle/cq_classes_64_unsupported.cfg")
	check(config.parse(normal_cfg).values.sv_cq_maxclients==32 and config.parse("").values.sv_cq_maxclients==32,"CQ defaults remain 32 slots")
	check(config.parse(experimental_cfg).values.sv_cq_maxclients==64,"Explicit unsupported configuration accepts 64 slots")
	check(config.parse(experimental_cfg.replace('sv_cq_maxclients "64"','sv_cq_maxclients "65"')).has("error"),"CQ configuration rejects more than 64 slots")
	check(not config.frontier_capacity(32).unsupported and config.frontier_capacity(32).warning.is_empty(),"32-slot configuration has no unsupported notice")
	check(config.frontier_capacity(33).unsupported and not config.frontier_capacity(64).warning.is_empty(),"All capacities above 32 are explicitly unsupported")
	game.disconnect_game();game.dedicated=true;game.max_clients=64;game.start_host("Unsupported capacity",28814,100,15,false)
	check(game.active and game.max_clients==64 and game.network_player_limit()==64,"Dedicated frontier preserves explicitly selected 64-slot limit")
	var capacity_admin=preload("res://deathmatch/server/rcon.gd").new();capacity_admin.game=game
	var server_status:Dictionary=capacity_admin.execute("status")
	check(server_status.capacity==64 and server_status.capacity_policy.unsupported and server_status.capacity_policy.supported_limit==32,"RCON reports unsupported capacity and supported ceiling")
	capacity_admin.free()
	print("CQ_FRONTIER_INTEGRATION_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
