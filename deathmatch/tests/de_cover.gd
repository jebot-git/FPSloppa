extends SceneTree
## Real BSP collision, automatic sliding doors and moving penetration volumes.
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
var g
var checks:=0
var failures: Array=[]
var timings: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func p(u: float,v: float,z: float) -> Vector3:return Vector3((v-300)*6,z,(400-u)*6)/32.0
func ray(a: Vector3,b: Vector3) -> Dictionary:
	return g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func advance(seconds: float):
	for frame in ceili(seconds*60):
		g.clock+=1.0/60;await physics_frame
func run():
	Engine.physics_ticks_per_second=240;Engine.time_scale=4;Engine.max_physics_steps_per_frame=32
	for id in Maps.IDS:
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=id;g.start_host("Cover audit",0,20,10,true,"de")
		g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
		await physics_frame;await physics_frame
		var runtime=g.get_node("Map/MapRuntime");var ballistics=runtime.ballistics
		check(ballistics.ready and ballistics.brushes.size()>100,"Embedded penetration volumes bind to actual map: "+id)
		var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0)
		# Probe real exposed brush faces against actual collision. Each successful
		# metadata exit must reach a real clear point beyond that same surface.
		var exposed:=0;var passable:=0;var max_candidates:=0;var started:=Time.get_ticks_usec()
		for brush in ballistics.brushes:
			# Avoid grazing a coplanar decorative mullion exactly on its edge.
			var center: Vector3=brush.bounds.position+brush.bounds.size*Vector3(.413,.537,.461)
			for axis in [Vector3.RIGHT,Vector3.FORWARD]:
				var width: float=brush.bounds.size.abs().dot(axis.abs())
				if width<.025 or width>1.4:continue
				var hit:=ray(center-axis*(width*.5+.1),center+axis*(width*.5+.1))
				if hit.is_empty():continue
				exposed+=1
				var exit: Dictionary=ballistics.exit_surface(hit.position,axis,45.0/32,g.get_world_3d().direct_space_state)
				max_candidates=maxi(max_candidates,ballistics.queries)
				if exit.is_empty():continue
				passable+=1
				var reverse:=ray(exit.position,hit.position-axis*.05)
				check(not reverse.is_empty() and reverse.position.distance_to(exit.position)<.012,"Exit agrees with actual outer collision: "+id+" #"+str(passable))
		check(exposed>0 and passable>0,"Real cover supports bounded wall exits: "+id)
		timings.append({"map":id,"probes":exposed,"passable":passable,"max_candidates":max_candidates,"probe_and_physics_usec":Time.get_ticks_usec()-started})
		if id=="de_nuke_rebuilt":
			check(g.gates.size()==8 and ballistics.movers.size()==8,"Four glass assemblies use eight moving leaves")
			var start:=p(430,315,-196);var end:=p(440,315,-196);var direction: Vector3=(end-start).normalized()
			var closed:=ray(start,end)
			check(not closed.is_empty(),"Closed glass door blocks passage ray")
			if not closed.is_empty():
				var passage: Dictionary=ballistics.exit_surface(closed.position,direction,39.0/32)
				check(not passage.is_empty() and absf(float(passage.get("retention",0))-.5)<.001,"Closed glass is penetrable with glass damage loss")
			var pair: Array=g.gates.filter(func(gate):return gate.node.attributes.get("targetname")=="GlassDoor2")
			check(pair.size()==2 and pair.all(func(gate):return absf(gate.travel.length()-2)<.001 and absf(gate.move_seconds-1.28)<.001),"Leaf travel is 64 BSP units at original speed 50")
			g.fighters[1].position=p(430,320,-256)+Vector3.UP*.05;g.fighters[1].velocity=Vector3.ZERO
			await advance(.5)
			for gate in pair:
				var center: Vector3=runtime.node_bounds(gate.node).get_center()
				var moved:=ray(center-direction,center+direction)
				check(not moved.is_empty() and moved.collider==gate.node and not ballistics.exit_surface(moved.position,direction,39.0/32).is_empty(),"Penetration volume follows partially translated glass leaf")
			await advance(1)
			check(pair.all(func(gate):return gate.open and gate.node.position.distance_to(gate.base_position+gate.travel)<.002),"Physical player overlap opens both leaves completely")
			check(ray(start,end).is_empty(),"Open glass doorway has clear collision")
			if not closed.is_empty():check(ballistics.exit_surface(closed.position,direction,39.0/32).is_empty(),"Open door no longer leaves invisible penetration volume in aperture")
			g.fighters[1].position=de.starts[0][0];await advance(.2)
			g.clock=pair[0].until+.1;g._server_tick(1.0/60);await advance(1.5)
			check(pair.all(func(gate):return not gate.open and gate.node.position.distance_to(gate.base_position)<.002),"Doors close after authored wait")
			runtime.triggers.use_target("GlassDoor2",1);await advance(1.5)
			check(pair.all(func(gate):return gate.open),"Target activation reopens paired leaves")
			de.begin_round();await physics_frame
			check(g.gates.all(func(gate):return not gate.open and gate.node.position.distance_to(gate.base_position)<.002),"New DE round resets all leaves and cancels motion")
		g.disconnect_game();g.free();await process_frame
	var report:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"maps":timings}
	FileAccess.open("res://test-results/de-restoration/cover-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DE_COVER_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
