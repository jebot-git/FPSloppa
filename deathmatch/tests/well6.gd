extends SceneTree
## Real Well6 entities, floor collision and lift passengers, without rendered assets.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Runtime=preload("res://deathmatch/maps/runtime.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var game
var runtime
var failures: Array=[]
var report: Dictionary={"spawns":[],"flags":[],"elevators":[]}
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func floor_hit(p: Vector3,distance: float=10.0) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.01,p-Vector3.UP*distance,1))
func actor_at(p: Vector3,id: int):
	var actor=Fighter.new();actor.setup(id,"Well6 audit",Color.WHITE);actor.quake_movement=true;actor.collision_mask=1
	game.add_child(actor);actor.position=p;return actor
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false);game.dedicated=true;game.lobby.enabled=false
	for child in game.get_node("Map").get_children():child.free()
	for key in ["gates","lifts","spawn_points","spawn_yaws","pickups"]:game.get(key).clear()
	game.players.clear();game.fighters.clear();game.map_objectives.clear();game.ctf_spawns=[[],[]];game.tf_resupply=[[],[]];game.tf_capture.clear()
	var level=Maps.read(args[0]);check(level!=null,"Well6 imports")
	if not level:finish(args[1]);return
	preload("res://deathmatch/server/geometry.gd").strip(level)
	game.get_node("Map").add_child(level)
	runtime=Runtime.new();game.get_node("Map").add_child(runtime);runtime.configure(game,level,args[0]);runtime.set_physics_process(false)
	game.match_mode.kind="tf";game.match_mode.reset();game.active=true
	await physics_frame;await physics_frame
	report.console_engine=OS.has_feature("dedicated_server");report.map_sha256=FileAccess.get_sha256(args[0])
	check(game.ctf_spawns[0].size()==8 and game.ctf_spawns[1].size()==8,"Eight native spawns per team")
	for team in 2:
		for p in game.ctf_spawns[team]:
			var hit:=floor_hit(p)
			var gap: float=p.y-hit.position.y if not hit.is_empty() else INF
			report.spawns.append({"team":team,"position":xyz(p),"floor_gap":gap})
			check(gap>=0 and gap<.08,"Native team spawn starts on floor")
		var flag: Vector3=game.match_mode.bases[team];var hit:=floor_hit(flag)
		var gap: float=flag.y-hit.position.y if not hit.is_empty() else INF
		report.flags.append({"team":team,"position":xyz(flag),"floor_gap":gap})
		check(gap>=0 and gap<.08,"Key flag starts on floor")
		check(flag.distance_to(Vector3(107.5,0,0) if team==0 else Vector3(-107.125,0,.0625))<15,"Uses actual key objective, not fallback spawn")
	check(not Runtime.is_tf_flag({"classname":"item_tfgoal","owned_by":"1","mdl":"progs/backpack.mdl","goal_no":"1"},{1:true}),"Backpack is not mistaken for flag")
	check(not Runtime.is_tf_flag({"classname":"item_tfgoal","owned_by":"1","mdl":"progs/w_s_key.mdl","goal_no":"9"},{1:true}),"Unreferenced key is not mistaken for flag")
	await elevators()
	await joining_elevator()
	finish(args[1])
func joining_elevator() -> void:
	for i in game.gates.size():
		var gate: Dictionary=game.gates[i]
		if not gate.get("elevator",false):continue
		if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
		gate.node.position=gate.base_position;gate.open=false
		game._gate_state(i,true)
		var middle: Vector3=gate.base_position+gate.travel*.5
		game._sync_elevators([[i,middle]])
		check(gate.node.position.distance_to(middle)<.01,"Late join resumes the elevator at the authoritative position")
		for frame in ceili(gate.move_seconds*.5*60)+5:await physics_frame
		check(gate.node.position.distance_to(gate.base_position+gate.travel)<.01,"Late join completes only the remaining elevator travel")
		report.late_join=true
		break
func elevators() -> void:
	var riders: Array=[]
	for gate in game.gates:
		if not gate.get("elevator",false):continue
		var bounds: AABB=runtime.node_bounds(gate.node)
		var start:=Vector3(bounds.get_center().x,bounds.end.y+.03,bounds.get_center().z)
		for region in runtime.regions:
			if region.data.get("target","")!=gate.node.attributes.get("targetname",""):continue
			for shape in region.area.get_children():
				if shape is CollisionShape3D and shape.shape is BoxShape3D:start=shape.global_position
		var hit:=floor_hit(start)
		check(not hit.is_empty() and hit.collider==gate.node,"Elevator surface is solid and boardable")
		if not hit.is_empty():start=hit.position+Vector3.UP*.03
		var id:=100+riders.size();var actor=actor_at(start,id)
		game.players[id]=game._new_state("Lift rider",id);game.players[id].team=0;game.players[id].hp=10000;game.fighters[id]=actor
		var row: Dictionary={"gate":gate,"actor":actor,"start":start,"peak":start.y,"triggered":false,"returned":false}
		riders.append(row)
	check(riders.size()==4,"Four trigger-operated tower elevators")
	# Exercise the actual overlapping trigger and normal authority tick. The old
	# door test teleported a probe to the brush centre, far below its boardable top.
	for frame in 760:
		await physics_frame
		game.clock+=1.0/60.0
		runtime._physics_process(1.0/60.0)
		game._server_tick(1.0/60.0)
		for row in riders:
			row.peak=maxf(row.peak,row.actor.position.y)
			row.triggered=row.triggered or row.gate.open
			if row.peak>row.start.y+1 and absf(row.actor.position.y-row.start.y)<.15:row.returned=true
	for row in riders:
		var rise: float=row.peak-row.start.y
		check(row.triggered,"Boarding activates elevator trigger")
		check(absf(rise-row.gate.travel.y)<.3,"Elevator carries rider through full travel")
		check(row.returned,"Elevator returns with its rider")
		report.elevators.append({"model":row.gate.node.attributes.model,"triggered":row.triggered,"travel":row.gate.travel.y,"rider_rise":rise,"returned":row.returned,"move_seconds":row.gate.move_seconds})
		game.players.erase(row.actor.peer_id);game.fighters.erase(row.actor.peer_id);row.actor.free()
func finish(path: String) -> void:
	report.passed=failures.is_empty();report.failures=failures
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("WELL6_RESULT ",JSON.stringify(report))
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
