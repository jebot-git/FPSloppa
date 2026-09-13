extends SceneTree
var g
var w
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.mode_maplists["tb"]=["qsrc_dm1"];g.start_host("Lateral tests",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	w=g.match_mode.fortress.walkers;w.configure([{"id":"test","points":[Vector3(1000,0,0),Vector3(1000,0,120)],"team":0}])
	g.match_mode.titanball.advance_time(60.)
	for id in g.players:g.players[id].spectator=id not in [1,-1];g.fighters[id].position=Vector3(1100,0,0)
	var r: Dictionary=w.robots.test
	g.players[1].team=0;g.players[1].input_blocked=false;g.fighters[1].position=w.transform(r)*w.LADDER
	await physics_frame;await physics_frame;check(w.try_board(1,"test"),"Pilot boards isolated coverage fixture")
	check(is_equal_approx(rad_to_deg(w.CANNON_CONE)*2,15.),"Lateral coverage is fifteen degrees total")
	for angle in [-7.4,7.4,-12.,12.]:
		var s: Dictionary=g.players[-1];s.dead=false;s.spectator=false;s.team=1;s.hp=10000;s.armor=0;s.invulnerable=0.;s.tf_disguise={}
		g.fighters[-1].position=Vector3(1000+50*tan(deg_to_rad(angle)),0,50)
		r.body_yaw=signf(angle)*w.Tuning.LATERAL_LIMIT;r.targets=[0,0];r.scan_at=0.;r.ready=0.;r.heat=[0.,0.];r.overheated=[false,false]
		var slow:=true;var bounded:=true
		for i in 240:
			var before: float=r.body_yaw;g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
			slow=slow and absf(r.body_yaw-before)<=w.AIM_SPEED/60.+.000001
			bounded=bounded and absf(w.Tuning.body_yaw(r))<=w.Tuning.LATERAL_LIMIT+.000001
		check(slow and bounded,"%.1f-degree target preserves slow torso rotation and lateral bounds"%angle)
		if absf(angle)<7.5:
			check(s.hp<10000,"Target at %.1f degrees receives cannon support"%angle)
			check(absf(rad_to_deg(r.body_yaw)-angle)<.2,"Torso follows %.1f-degree target"%angle)
		else:check(s.hp==10000 and r.targets==[0,0],"Target at %.1f degrees cannot stack body turn with another aiming cone"%angle)
	# The torso turns without dragging the already authored foot positions.
	var view=preload("res://deathmatch/vehicles/ba2/view.gd").new();g.add_child(view);view.setup()
	var state: Dictionary={"distance":1.3,"speed":.8,"body_yaw":0.,"pitches":[.2,-.1]}
	view.update_robot(state,false,false);var legs: Dictionary={}
	for i in view.skeleton.get_bone_count():
		if view.skeleton.get_bone_name(i).begins_with("Leg."):legs[i]=view.skeleton.get_bone_global_pose(i)
	state.body_yaw=w.Tuning.LATERAL_LIMIT;view.update_robot(state,false,false)
	for i in legs:
		if not view.skeleton.get_bone_global_pose(i).is_equal_approx(legs[i]):print("LEG_DIFFERENCE ",view.skeleton.get_bone_name(i)," parent ",view.skeleton.get_bone_name(view.skeleton.get_bone_parent(i))," before ",legs[i]," after ",view.skeleton.get_bone_global_pose(i))
	check(legs.keys().all(func(i):return view.skeleton.get_bone_global_pose(i).is_equal_approx(legs[i])),"Torso steering preserves every baked leg bone pose")
	FileAccess.open("res://test-results/ba2/gameplay/lateral-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_LATERAL_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
