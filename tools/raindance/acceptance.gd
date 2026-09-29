extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const KEY="ctf_raindance"
var g
var failures: Array=[]
var report: Dictionary={"checks":[],"terrain":{},"routes":[],"landings":[],"flag_flythroughs":[]}
func _initialize():run.call_deferred()
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func check(ok: bool,label: String):
	report.checks.append({"check":label,"pass":ok})
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func run():
	var bsp:="res://maps/"+KEY+".bsp"
	check(Loader.validate(bsp).is_empty(),"Native BSP29 importer validates map")
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Raindance/probes.json"))
	var authored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Raindance/manifest.json"))
	report.bsp_sha256=FileAccess.get_sha256(bsp)
	check(authored.bsp_sha256==report.bsp_sha256,"Manifest matches compiled map")
	var row: Dictionary={}
	for item in Loader.catalog():
		if item.id==KEY:row=item;break
	check(not row.is_empty() and row.modes==["st"] and row.get("experimental",false),"Experimental map appears in dedicated ST catalog")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map=KEY;g.start_host("Raindance acceptance",0,100,15,true,"st")
	g.set_process(false);g.set_physics_process(false)
	check(g.active and g.current_map==KEY,"Native CTF match starts on Raindance")
	await physics_frame;await physics_frame
	check(g.ctf_spawns[0].size()==8 and g.ctf_spawns[1].size()==8,"Eight spawns on each team")
	var ground_mesh: NavigationMesh=load("res://maps/navigation/ctf_raindance.res")
	check(preload("res://tools/raindance/navigation_cleanup.gd").edge_owners(ground_mesh).values().all(func(owners):return owners.size()<=2),"Ground navigation has no over-owned edges")
	check(g.map_objectives.has("red") and g.map_objectives.has("blue"),"Both flag objectives imported")
	if not g.headless:check(g.get_node("Overview").far>1000,"Overview can see the complete terrain extent")
	var level: Node=g.get_node("Map").get_child(0)
	check(level.get_meta("baked_light_rgb",false),"Embedded coloured lighting loads")
	check(level.get_meta("baked_light_invalid_faces",-1)==0 and level.get_meta("baked_light_overflow_faces",-1)==0,"No invalid or overflowing lightmap faces")
	var space: PhysicsDirectSpaceState3D=g.get_world_3d().direct_space_state
	var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
	for group in [probes.spawns,probes.flags,probes.stations]:
		for point in group:
			var p:=v(point.position)
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=p+Vector3.UP*.85
			check(space.intersect_shape(query).is_empty(),"Capsule clearance at "+str(p))
			var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*.3,1))
			check(not floor_hit.is_empty(),"Supporting floor at "+str(p))
	# Two-metre samples check the compiled faces at diagonal seams and valleys.
	# Architecture covering terrain is recorded separately from terrain error.
	var tested:=0;var max_error:=0.;var covered:=0;var holes: Array=[]
	for route in probes.routes:
		var route_holes:=0;var route_covered:=0
		for array in route.samples:
			var p:=v(array)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,300,p.z),Vector3(p.x,-25,p.z),1))
			tested+=1
			if hit.is_empty():holes.append(str(p));route_holes+=1;continue
			var error: float=hit.position.y-p.y
			if error>.08:covered+=1;route_covered+=1
			else:max_error=maxf(max_error,absf(error))
		report.routes.append({"route":route.name,"length_m":route.length,"samples":route.samples.size(),"holes":route_holes,"samples_under_architecture":route_covered})
	report.terrain={"samples":tested,"holes":holes,"max_uncovered_height_error_m":max_error,"samples_under_architecture":covered}
	check(holes.is_empty() and max_error<.08,"All route samples have continuous compiled terrain")
	# Swept capsule contact at representative valley samples, independent of the
	# future ski controller. This verifies collision, not momentum preservation.
	for route in probes.routes:
		for index in [route.samples.size()/3,route.samples.size()*2/3]:
			var p:=v(route.samples[int(index)])
			var ground:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,300,p.z),Vector3(p.x,-25,p.z),1))
			if ground.is_empty():continue
			for speed in [30.,60.,100.]:
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
				query.transform.origin=ground.position+Vector3.UP*1.3;query.motion=Vector3.DOWN*speed/60.
				var fraction:=space.cast_motion(query)
				var passed: bool=fraction.size()==2 and fraction[0]<1.
				report.landings.append({"speed_m_s":speed,"pass":passed,"safe_fraction":fraction[0] if fraction.size()==2 else -1})
	check(report.landings.size()==18 and report.landings.all(func(r):return r.pass),"Swept capsule lands at 30/60/100 m/s without tunnelling")
	for team in [0,1]:
		var angle:=0.0
		for yaw in [angle]:
			var axis:=Vector3(cos(yaw),0,-sin(yaw))
			for speed in [30.,60.,100.]:
				var p:=v(probes.flags[team].position)+Vector3.UP*1.0-axis*12.
				var remaining:=24.;var clear:=true
				while remaining>0:
					var step:=minf(remaining,speed/60.)
					var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=p;query.motion=axis*step
					var fraction:=space.cast_motion(query)
					if fraction.size()!=2 or fraction[0]<.999:clear=false;break
					p+=axis*step;remaining-=step
				report.flag_flythroughs.append({"team":team,"speed_m_s":speed,"axis":str(axis),"pass":clear})
	check(report.flag_flythroughs.all(func(r):return r.pass),"Covered flag shelves have clear lateral fly-throughs")
	# Exercise the real authoritative CTF rules at actual imported objectives.
	for id in g.players:g.players[id].spectator=true
	g.players[1].spectator=false;g.players[1].dead=false
	for team in [0,1]:
		g.players[1].team=team
		for flag in [0,1]:g.match_mode.return_flag(flag)
		g.fighters[1].position=g.match_mode.bases[1-team];g.match_mode.tick(.05)
		check(g.match_mode.flags[1-team].carrier==1,"Team %d can take enemy flag"%team)
		var before: int=g.match_mode.scores[team]
		g.fighters[1].position=g.match_mode.bases[team];g.match_mode.tick(.05)
		check(g.match_mode.scores[team]==before+1,"Team %d can capture flag"%team)
	var ai=g.bots;ai.tribes.routes.build()
	for team in [0,1]:
		for spawn in g.ctf_spawns[team]:
			check(not ai.tribes.routes.path(spawn,g.match_mode.bases[1-team]).is_empty(),"Terrain graph connects team %d spawn to enemy shelf"%team)
		for fixture in g.match_mode.tribes.stations().rows:
			if fixture.team!=team:continue
			check(not ai.tribes.routes.path(g.ctf_spawns[team][0],fixture.position).is_empty(),"Bunker portal connects to "+str(team)+" "+fixture.kind)
	check(g.match_mode.tribes.stations().navigation_points.size()==probes.portals.size(),"Authored indoor and shelf portals reach runtime")
	for point in probes.portals:
		var p:=v(point)
		var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.12,p-Vector3.UP*.2,1))
		check(not floor_hit.is_empty() and floor_hit.normal.y>.65,"Navigation portal has nearby supporting floor at "+str(p))
	for fixture in g.match_mode.tribes.stations().generators:
		var hit: Dictionary=g._trace(fixture.frame*Vector3(0,0,4),fixture.frame.origin,1)
		check(hit.get("generator",-1)==fixture.team,"Generator housing can be shot/repaired "+str(fixture.team))
	report.failures=failures
	report.limitations=["No Tribes controller, ski momentum or jet energy implementation is tested.","Ground navigation does not provide skiing or jetpack AI.","Physical headset performance and competitive route balance are unmeasured."]
	FileAccess.open("res://test-results/st-raindance/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("RAINDANCE_ACCEPTANCE ",JSON.stringify({"checks":report.checks.size(),"failures":failures}))
	g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
