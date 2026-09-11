extends SceneTree
const Swim=preload("res://deathmatch/vr/swim_strokes.gd")
const TPose=preload("res://deathmatch/vr/t_pose.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func stroke(fps: int,up: bool=false) -> Vector3:
	var detector:=Swim.new();var h:=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0));var value:=Vector3.ZERO
	for i in range(fps/2+1):
		var t: float=float(i)/fps
		var motion:=Vector3(0,-t*.6,0) if up else Vector3(0,0,t*.6)
		value=detector.sample(h,Vector3(-.3,1.3,-.4)+motion,Vector3(.3,1.3,-.4),1.0/fps,true)
	return value
func run() -> void:
	var a:=stroke(72);var b:=stroke(144)
	check(a.z<-.5 and a.length()<=1,"A short single-arm pull creates bounded forward propulsion")
	check(a.distance_to(b)<.035,"Swimming response is consistent at 72 and 144 Hz")
	check(stroke(90,true).z<-.5 and absf(stroke(90,true).y)<.001,"A downward stroke follows the view direction without upward lift")
	var swim:=Swim.new();var head:=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0));var l:=Vector3(-.6,1.4,0);var r:=Vector3(.6,1.4,0)
	swim.sample(head,l,r,.02,true)
	var shifted:=head;shifted.origin+=Vector3(.1,0,.1)
	check(swim.sample(shifted,l+Vector3(.1,0,.1),r+Vector3(.1,0,.1),.02,true)==Vector3.ZERO,"Whole-body translation does not count as an arm stroke")
	check(swim.sample(head,l,r,.02,false)==Vector3.ZERO and swim.previous.is_empty(),"Leaving water or losing focus clears swim thrust immediately")
	swim.sample(head,l,r,.02,true)
	check(swim.sample(head,l+Vector3.ONE,r,.02,true)==Vector3.ZERO,"A tracking discontinuity cannot launch the swimmer")
	var pose:=TPose.new();var count:=0
	for i in 200:
		if pose.sample(head,l,r,.02,true):count+=1
	check(count==1 and pose.latched,"Holding an upright T-pose calibrates once, without repeated jingles")
	for i in 60:pose.sample(head,l+Vector3.DOWN*.5,r+Vector3.DOWN*.5,.02,true)
	for i in 150:
		if pose.sample(head,l,r,.02,true):count+=1
	check(count==2,"Lowering arms then holding T-pose permits deliberate recalibration")
	var rejected:=0
	pose=TPose.new()
	for i in 100:
		if pose.sample(head,l,r,.02,false):rejected+=1
	check(rejected==0,"Unavailable body tracking / focus / seated mode cannot calibrate")
	pose=TPose.new();var crouch:=head;crouch.origin.y=1.0
	for i in 100:
		if pose.sample(crouch,l-Vector3.UP*.65,r-Vector3.UP*.65,.02,true):rejected+=1
	check(rejected==0,"Crouching is not accepted as standing calibration")
	pose=TPose.new()
	for i in 100:
		if pose.sample(head,l+Vector3(0,0,-.6),r+Vector3(0,0,-.6),.02,true):rejected+=1
	check(rejected==0,"Arms reaching forward do not accidentally trigger T-pose calibration")
	for hz in [60,72,90,120,144]:
		pose=TPose.new();var triggers:=0
		var tilted:=head;tilted.basis=Basis(Vector3.FORWARD,deg_to_rad(24))
		for i in hz*2:
			var wobble:=sin(float(i)*1.7)*.007
			var a_hand:=Vector3(-.55,1.19+wobble,-.32);var b_hand:=Vector3(.65,1.43-wobble,.20)
			# One brief reach excursion must not discard the whole deliberate hold.
			if i>=hz/2 and i<hz/2+int(hz*.1):a_hand.z=-.48
			if pose.sample(tilted,a_hand,b_hand,1.0/hz,true):triggers+=1
		check(triggers==1,"Relaxed asymmetric T-pose tolerates jitter, head tilt and a brief excursion at %d Hz"%hz)
	pose=TPose.new();var moving:=0
	for i in 200:
		var reach:=.65+sin(i*.3)*.25
		if pose.sample(head,Vector3(-reach,1.4,0),Vector3(reach,1.4,0),.02,true):moving+=1
	check(moving==0,"Repeated fast arm movement is not a held calibration gesture")
	var actor:=Fighter.new();root.add_child(actor);actor.set_process(false);actor.setup(3,"Swimmer",Color.WHITE);actor.quake_movement=true;actor.position=Vector3(1000,100,1000);actor.in_water=true
	for i in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false,Vector3(0,.5,-.8))
	check(actor.velocity.y>0 and actor.velocity.z<-3,"Arm thrust drives the actual water movement simulation upward and forward")
	actor.velocity=Vector3.ZERO;actor.in_water=false
	for i in 10:actor.simulate(Vector2.ZERO,0,false,1.0/60,false,Vector3.UP)
	check(actor.velocity.y<0,"Swim commands cannot give thrust on dry land")
	actor.in_water=true;actor.simulate(Vector2.ZERO,0,false,1.0/60,true,Vector3.DOWN)
	check(actor.velocity.y>5.4,"Held jump still swims up and takes priority over arm motion")
	var model:=Node3D.new();var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();var original:=StandardMaterial3D.new();mesh.material_overlay=original;model.add_child(mesh)
	actor.set_avatar(model,"");actor.set_frozen(true)
	check(mesh.material_override==actor.frost_material and mesh.material_overlay==null and actor.frost_originals.size()==1,"Frozen avatar meshes receive the opaque icy material")
	actor.set_frozen(true,.5);check(actor.frost_originals.size()==1,"Repeated freeze snapshots do not allocate extra overlays")
	actor.set_frozen(false);check(mesh.material_overlay==original and actor.frost_originals.is_empty(),"Thaw restores the model's original overlay exactly")
	actor.set_frozen(true);var replacement:=Node3D.new();var next_mesh:=MeshInstance3D.new();next_mesh.mesh=SphereMesh.new();replacement.add_child(next_mesh);actor.set_avatar(replacement,"")
	check(next_mesh.material_override==actor.frost_material and next_mesh.material_overlay==null,"Changing avatar while frozen retains the visible frozen state")
	actor.free()
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
	g.active=true;g.dedicated=true;g.round_left=600;g.time_limit=600
	g._server_tick(1200)
	check(g.round_left==600 and g.intermission==0,"An empty dedicated server does not consume match time or end the round")
	g.pending_names[42]="Downloading";g.pending_joins[42]=g.clock+120;g._server_tick(30)
	check(g.round_left==600,"A client downloading assets does not start the match timer")
	g.pending_names.clear();g.pending_joins.clear()
	g.players[2]=g._new_state("Ready",2);g._create_fighter(2);g.players[2].spectator=true;g._server_tick(1)
	check(g.round_left==599,"A ready client, including a spectator, starts the dedicated timer")
	g.players[2].spectator=false
	var cmd={"seq":1,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false,"xr":Poses.neutral(),"swim":Vector3(0,20,-20)}
	g._accept_input(2,cmd);check(g.players[2].swim.length()<=1.00001,"Server bounds received VR stroke strength")
	cmd.seq=2;cmd.swim=Vector3(INF,0,0);g._accept_input(2,cmd);check(g.players[2].swim==Vector3.ZERO,"Server rejects non-finite stroke input")
	cmd.seq=3;cmd.swim=Vector3.UP;cmd.erase("xr");g._accept_input(2,cmd);check(g.players[2].swim==Vector3.ZERO,"Desktop or invalid tracking cannot supply arm swimming")
	cmd.seq=4;cmd.xr=Poses.neutral();g._accept_input(2,cmd);g.clock+=1;g._server_tick(.02)
	check(g.players[2].swim==Vector3.ZERO,"Expired network input clears stroke thrust")
	g.fighters[2].free();g.fighters.clear();g.players.clear();var remaining: float=g.round_left;g._server_tick(60)
	check(g.round_left==remaining,"The dedicated match pauses again when the last client leaves")
	g.dedicated=false;g._server_tick(1);check(g.round_left==remaining-1,"Client-hosted timing remains unchanged")
	g.active=false;g.free()
	print("VR_GESTURES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
