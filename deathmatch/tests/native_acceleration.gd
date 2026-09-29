extends SceneTree
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Hits=preload("res://deathmatch/hit_detection.gd")
const Grid=preload("res://deathmatch/projectile_targets.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var checks:=0
var failures: Array=[]
var rng:=RandomNumberGenerator.new()
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label);push_error(label)
func vector(scale: float) -> Vector3:return Vector3(rng.randf_range(-scale,scale),rng.randf_range(-scale,scale),rng.randf_range(-scale,scale))
func same(a: float,b: float) -> bool:return (not is_finite(a) and not is_finite(b)) or absf(a-b)<.00002
func run() -> void:
	rng.seed=918244
	var native=Runtime.projectiles()
	check(native!=null and Runtime.pose()!=null,"Native classes available")
	if native==null:quit(1);return
	for trial in 10000:
		var start:=vector(3);var end:=vector(3);var half:=vector(.5).abs()+Vector3.ONE*.02
		if trial%7==0:end=start
		if trial%11==0:end.x=start.x;end.z=start.z
		var radius: float=[0.,.14,.16,.3][trial%4]
		check(same(Hits.box_fraction(start,end,half,radius),native.box_fraction(start,end,half,radius)),"Box sweep parity "+str(trial))
		var height:=rng.randf_range(.65,1.65);var yaw:=rng.randf_range(-PI,PI)
		check(same(Hits.player_fraction(start,end,height,yaw,radius),native.player_fraction(start,end,height,yaw,radius)),"Stance sweep parity "+str(trial))
	var players: Dictionary={};var fighters: Dictionary={};var previous: Dictionary={}
	for i in 32:
		var id:=32-i;players[id]={"dead":i%11==0,"spectator":i%13==0,"serial":2}
		var fighter:=Node3D.new();fighter.position=vector(30);fighters[id]=fighter
		previous[id]={"serial":1 if i%5==0 else 2,"position":fighter.position+vector(10)}
	fighters[2].position=Vector3(INF,0,0);fighters[3].position=Vector3(1e7,0,0)
	var grid:=Grid.new();grid.build(players,fighters,previous);native.build(players,fighters,previous)
	for trial in 4000:
		var start:=vector(45);var end:=start+vector(15);var radius:=rng.randf_range(0,.4)
		if trial%100==0:end=Vector3(1e7,0,0)
		if trial%101==0:radius=INF
		check(grid.candidates(start,end,radius)==native.candidates(start,end,radius),"Candidate order/overflow parity "+str(trial))
	for fighter in fighters.values():fighter.free()
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("Native parity",0,100,60,true);game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
	for id in game.players:
		game.players[id].invulnerable=0;game.fighters[id].position=Fixture.point(0 if id==1 else 1,-3 if id==-1 else 8)
	await physics_frame
	for trial in 1000:
		var start:=Fixture.point()+vector(5)+Vector3.UP;var end:=Fixture.point()+vector(5)+Vector3.UP
		var radius: float=[0.,.14,.16,.3][trial%4]
		var past: Dictionary={-1:{"serial":game.players[-1].serial,"position":Fixture.point(-1,-3),"height":1.65}} if trial%2 else {}
		var a: Dictionary=game._trace_reference(start,end,1,0.,radius,past)
		var b: Dictionary=game._trace(start,end,1,0.,radius,past)
		check(a.keys()==b.keys(),"Trace result fields "+str(trial))
		check(a.id==b.id and a.hit==b.hit and a.headshot==b.headshot and a.position.distance_to(b.position)<.0001,"Authoritative world/cover/relative motion trace parity "+str(trial))
		if a.has("surface_normal"):check(a.surface_normal.distance_to(b.get("surface_normal",Vector3.INF))<.0001,"Surface normal parity")
	game.disconnect_game();game.free()
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.5,30);camera.make_current()
	var library:=Library.new();library.entries["sample_d"]={"path":"res://vrm/sample_d.vrm"}
	var rigs: Array=[]
	for i in 2:
		var actor:=Node3D.new();world.add_child(actor)
		var rig=Loader.create_avatar(library,"sample_d");actor.add_child(rig);rig.set_process(false);rig.motion.pause();rig.solver.active=false;rig.eyes.active=false;rig.mouth.set_process(false);rig.set_weapon(2,"doom");rig.grounded=false
		if i==0:rig.solver.native_pose=null;rig.solver.pose_blend.native_pose=null
		rigs.append(rig)
	for frame in 180:
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
		pose.head.basis=Basis(Vector3.UP,sin(frame*.1)*.8)
		pose.left.origin+=Vector3(sin(frame*.1)*.2,sin(frame*.05)*.2,0)
		if frame%60>=30:pose.body={"hips":Transform3D(Basis(Vector3.UP,.2),Vector3(0,.9,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.13,.1,-.1)),"left_curls":PackedFloat32Array([.2,.4,.6,.8,1.])}
		for rig in rigs:
			rig.xr_pose=pose.duplicate(true) if frame<120 else {};rig.first_person=frame>=60 and frame<90;rig.aim_pitch=sin(frame*.04)*.7;rig.pain=.2 if frame>100 else 0
			if frame==100:rig.get_parent().position.x=5
			rig.solver._process_modification_with_delta(1./90)
		for index in rigs[0].skeleton.get_bone_count():
			var a: Transform3D=rigs[0].skeleton.get_bone_pose(index);var b: Transform3D=rigs[1].skeleton.get_bone_pose(index)
			check(a.origin.distance_to(b.origin)<.0001 and absf(a.basis.get_rotation_quaternion().dot(b.basis.get_rotation_quaternion()))>.99999,"Pose native/reference parity frame %d bone %d"%[frame,index])
	rigs.clear();world.free();library.free()
	print("NATIVE_ACCELERATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
