extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
class BodyTracking extends "res://deathmatch/vr/tracking.gd":
	func sample() -> Dictionary:
		return {"hips":rig.origin.transform*Transform3D(Basis.IDENTITY,Vector3(0,.65,0)),"left_foot":rig.origin.transform*Transform3D(Basis.IDENTITY,Vector3(-.15,.05,0)),"right_foot":rig.origin.transform*Transform3D(Basis.IDENTITY,Vector3(.15,.05,0)),"left_curls":PackedFloat32Array([0,0,0,0,0])}
var g
var rig
var de
var actor
var checks:=0
var failures: Array=[]
var sequence:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frame():
	g.clock+=1.0/60;actor.stepped_last_frame=true;rig._process(1.0/60);sequence+=1
	var cmd: Dictionary=g.NetCodec.unpack(g.NetCodec.pack(rig.command(sequence)),8192)
	g._accept_input(1,cmd);g._update_crouch(1,g.players[1].xr);de.sample_player(1)
func point_finger(local: Vector3):
	var pose: Dictionary=rig.sample_pose()
	var side: String="right" if rig.left_handed else "left"
	var target: Vector3=rig.global_transform.affine_inverse()*(de.bomb_pose()*local)
	rig.get(side).position+=target-Contact.fingertip(pose)
	(rig.right_aim if rig.left_handed else rig.left_aim).transform=rig.get(side).transform
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Crouch defusal",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);Fixture.setup(g)
	if not is_instance_valid(g.hud):g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0);de.phase="live";de.phase_end=g.clock+300;de.planted=true;de.carrier=0;de.fuse_end=g.clock+45
	actor=g.fighters[1];actor.position=Fixture.point();actor.stepped_last_frame=true;actor.in_water=false
	g.players[1].team=1-de.attacking;g.players[1].yaw=0;g.players[1].dead=false;g.local_yaw=0;g.menu_open=false
	de.bomb_position=actor.position+Vector3(0,.102,-.5);de.bomb_basis=Basis(Vector3.RIGHT,-PI/2)
	check(de.crouch_defuse_assist(1,true) and not de.crouch_defuse_assist(1,false),"Assist requires crouching beside a floor bomb")
	g._update_crouch(1,{}, {"crouch":true});check(actor.stance=="prone" and is_equal_approx(actor.eye_height(),.48),"Desktop crouch lowers viewpoint and enters prone")
	var remote=g.fighters[-1];remote.receive_locomotion(actor.locomotion_state());check(remote.stance=="prone","Prone body stance replicates through existing locomotion state")
	g._update_crouch(1,{},{});check(actor.stance=="stand","Desktop standing restores normal height")
	for condition in ["attacker","dead","spectator","unplanted","post","wall","high","water","air","far"]:
		var team: int=g.players[1].team
		match condition:
			"attacker":g.players[1].team=de.attacking
			"dead":g.players[1].dead=true
			"spectator":g.players[1].spectator=true
			"unplanted":de.planted=false
			"post":de.phase="post"
			"wall":de.bomb_basis=Basis.IDENTITY
			"high":de.bomb_position.y+=1
			"water":actor.in_water=true
			"air":actor.stepped_last_frame=false
			"far":actor.position.z+=2
		check(not de.crouch_defuse_assist(1,true),"No posture assist for "+condition)
		g.players[1].team=team;g.players[1].dead=false;g.players[1].spectator=false;de.planted=true;de.phase="live";de.bomb_basis=Basis(Vector3.RIGHT,-PI/2);actor.in_water=false;actor.stepped_last_frame=true;actor.position=Fixture.point();de.bomb_position=actor.position+Vector3(0,.102,-.5)
	actor.position.z+=.5;check(not de.crouch_defuse_assist(1,true) and de.crouch_defuse_assist(1,true,true),"Distance hysteresis avoids posture flicker at the boundary");actor.position=Fixture.point()
	var wall:=Fixture.box(g,Fixture.point()+Vector3(0,.5,-.25),Vector3(2,1,.06))
	await physics_frame;check(not de.crouch_defuse_assist(1,true),"A wall blocks proximity assist");wall.free();await physics_frame
	g.bindings.physical_crouch=true;g.bindings.physical_prone=false
	rig.head.position=Vector3(0,1.65,0);rig.left.position=Vector3(-.2,1.2,-.35);rig.right.position=Vector3(.2,1.2,-.35)
	rig.left_aim.transform=rig.left.transform;rig.right_aim.transform=rig.right.transform
	frame();check(rig.defusal_lowering==0,"Standing VR user is not lowered")
	rig.head.position.y=1.05;frame();check(rig.defusal_lowering>0 and rig.defusal_lowering<.06,"VR viewpoint enters assist smoothly")
	for i in 25:frame()
	var pose: Dictionary=rig.sample_pose()
	check(not pose.is_empty() and is_equal_approx(pose.head.origin.y,.48) and actor.stance=="prone","Crouching VR user reaches low viewpoint and authoritative prone collider")
	check((pose.left.origin-pose.head.origin).is_equal_approx(rig.left.position-rig.head.position),"Head and hands lower together without changing physical reach")
	check(is_equal_approx(rig.crouch_height,1.15),"Assist does not feed its own offset back into physical crouch detection")
	var normal_tracking=rig.tracking
	var body:=BodyTracking.new();rig.add_child(body);body.rig=rig;body.enabled=false;rig.tracking=body
	pose=rig.sample_pose();check(not pose.is_empty() and not pose.body.has("hips") and not pose.body.has("left_foot") and pose.body.has("left_curls"),"Full-body crouch trackers yield to prone animation while fingers remain tracked")
	rig.tracking=normal_tracking;body.free()
	for left in [false,true]:
		rig.left_handed=left;de.defuse_index=0;de.defuser=0;de.key_at=0;de.input_edges.clear()
		var key: Vector3=Contact.key_point(int(de.defuse_code[0]));key.z=.12;point_finger(key);frame();frame()
		key.z=.083;point_finger(key);frame()
		check(de.defuse_index==1,"Lowered tracked fingertip presses the floor keypad, left="+str(left))
		var hand=rig.right if left else rig.left
		check(hand.position.y>.45,"Keypad reach does not require touching the physical floor")
		g.clock+=.3
	if "--render" in OS.get_cmdline_user_args():await capture_posture()
	rig.head.position.y=1.65;frame();check(rig.defusal_lowering>0 and not rig.defusal_posture,"Standing begins a smooth return")
	for i in 30:frame()
	check(rig.defusal_lowering==0 and actor.stance=="stand" and is_equal_approx(rig.sample_pose().head.origin.y,1.65),"Standing fully restores tracking origin and body")
	rig.head.position.y=1.05
	for i in 25:frame()
	actor.position.z+=2
	for i in 30:frame()
	check(rig.defusal_lowering==0 and actor.stance=="crouch","Leaving the bomb returns to ordinary crouch")
	actor.position=Fixture.point()
	for i in 25:frame()
	de.phase="post"
	for i in 30:frame()
	check(rig.defusal_lowering==0,"Round end releases the assist")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/posture.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_POSTURE_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)

func capture_posture():
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	var hash: String=g.avatars.library.selected
	var avatar=g.avatars.library.create_avatar(hash);actor.set_avatar(avatar,hash)
	actor.local_player=false;actor.show_alive(true,false);actor.xr_pose=rig.sample_pose()
	for i in 30:actor._process(1.0/60);avatar._process(1.0/60);avatar.solver._process_modification_with_delta(1.0/60)
	check(avatar.stance=="prone" and avatar.gait.prone_blend>.99,"Rendered avatar enters the existing prone animation")
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	for node in [rig.panel,rig.keyboard,rig.status_surface,rig.blackout,rig.damage_overlay,rig.weapon_wheel]:node.hide()
	for pointer in rig.pointers:pointer.enabled=false;pointer.hide()
	for guide in rig.aim_guides:guide.hide()
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(6,6);g.add_child(floor_mesh);floor_mesh.position=Fixture.point()
	var material:=StandardMaterial3D.new();material.albedo_color=Color("56616b");floor_mesh.material_override=material
	var camera:=Camera3D.new();g.add_child(camera);camera.position=Fixture.point()+Vector3(1.6,1.25,-1.6);camera.look_at(Fixture.point()+Vector3(0,.3,-.2));camera.make_current()
	camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("27313c");camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE;camera.environment.ambient_light_energy=.8
	de.draw()
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/defusal/posture.png")
	actor.local_player=true;actor.set_local_body(true);camera.queue_free();floor_mesh.queue_free()
