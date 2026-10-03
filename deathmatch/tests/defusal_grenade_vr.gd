extends SceneTree
class TestBindings extends "res://deathmatch/settings/bindings.gd":
	var inputs: Dictionary={}
	func vr_pressed(_rig: Node,action: String) -> bool:return inputs.get(action,false)
var g
var de
var rig
var b
var seq:=100
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frame():
	g.clock+=.02;g.players[1].last_input=g.clock
	rig._process(.02);seq+=1;g._accept_input(1,rig.command(seq));de.sample_player(1)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("DE tracked grenades",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	if not is_instance_valid(g.hud):g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0);de.carrier=0;g.menu_open=false;g.local_yaw=0
	g.fighters[1].position=de.starts[0][0];g.players[1].yaw=0.0;g.players[1].input_blocked=false;g.players[1].last_input=g.clock
	b=TestBindings.new();g.bindings=b;b.physical_interactions=true
	var u=de.utility
	for left in [false,true]:
		rig.left_handed=left;rig.head.position=Vector3(0,1.65,0)
		var hand=rig.right if left else rig.left
		var free_hand=rig.left if left else rig.right
		free_hand.transform=Transform3D(Basis(Vector3.UP,.45),Vector3(-.2 if left else .2,1.2,-.35))
		(rig.left_aim if left else rig.right_aim).transform=free_hand.transform
		hand.position=Vector3(.3 if left else -.3,1.8,.15)
		u.cancel(1);u.state(1).shoulder=0;u.state(1).counts=[1,2,1];u.state(1).cooldown=0;b.inputs={};frame();frame()
		b.inputs={"support":true,"offhand_fire":true};frame()
		check(rig.physical_actions.gesture.held and u.state(1).primed and u.state(1).offhand,"TF-style shoulder chord arms offhand grenade, left="+str(left))
		check(is_instance_valid(rig.physical_actions.grenade) and rig.physical_actions.grenade.visible,"Held model and throw guide shown, left="+str(left))
		var grenade_pose: Transform3D=rig.physical_actions.grenade.global_transform
		check(grenade_pose.basis.y.dot(-hand.global_basis.z)>.999,"Grenade top follows the controller thumb axis")
		check(grenade_pose.basis.x.dot(hand.global_basis.x)>(.999) if not left else grenade_pose.basis.x.dot(-hand.global_basis.x)>.999,"Grenade safety lever faces the holding palm")
		check(not rig.command(seq+1).fire and not rig.command(seq+1).offhand_fire,"Held utility blocks both gun triggers")
		for i in 7:hand.position.z-=.06;frame()
		rig.physical_actions.guide_elapsed=0;rig.physical_actions.update_guide(.02)
		var guide_points: PackedVector3Array=rig.physical_actions.guide.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(guide_points.size()==2 and guide_points[0].distance_to((rig.global_transform*rig.sample_pose().weapon).origin)<.001,"Only the aiming-hand guide is drawn, left="+str(left))
		b.inputs={"offhand_fire":true};frame()
		check(u.flying.size()==1 and u.state(1).counts[0]==0,"Swing and grip release emits exactly one purchased HE")
		if not u.flying.is_empty():
			check(u.flying.values()[0].velocity.length()>10 and u.flying.values()[0].velocity.length()<=40.001,"Throw boost preserves bounded offhand power")
			check(u.flying.values()[0].velocity.normalized().dot(-free_hand.basis.z)>.999,"DE throw follows the free hand's aim, independently of throwing direction")
		check(not rig.physical_actions.hint.visible,"DE grenade guide uses geometry without floating text")
		check(not rig.physical_actions.grenade.visible,"Released local model hides")
		u.flying.clear();u.state(1).cooldown=0;u.state(1).counts=[1,2,1]
		var strong_pose: Dictionary=rig.sample_pose()
		check(u.physical_request(1,"arm",strong_pose,Vector3.ZERO) and u.physical_request(1,"throw",strong_pose,Vector3(0,0,-12)),"Authority accepts strong physical swing")
		check(u.flying.size()==1 and is_equal_approx(u.flying.values()[0].velocity.length(),40),"Strong DE swing reaches 40 m/s without the former secondary speed clamp")
		u.flying.clear();u.state(1).cooldown=0;b.inputs={};frame();u.equip(1,2)
		check(u.state(1).shoulder==2 and u.selected(1)==-1 and not de.gun_holstered(1),"VR wheel chooses shoulder smoke without holstering gun")
		hand.position=Vector3(.3 if left else -.3,1.8,.15);frame()
		b.inputs={"support":true,"offhand_fire":true};frame();check(u.state(1).selected==2 and u.state(1).offhand,"Wheel-selected smoke uses same offhand gesture")
		g.menu_open=true;frame();check(u.selected(1)==-1 and u.state(1).counts[2]==1 and not rig.physical_actions.gesture.held,"Menu cancels offhand grenade without consuming it")
		g.menu_open=false;frame();check(not u.state(1).primed,"Closing menu with chord held cannot rearm")
		# Shoulder equipment must take a hand already latched to the M3 pump.
		u.cancel(1);u.state(1).counts=[1,2,1];u.state(1).cooldown=0;b.inputs={};frame()
		g.players[1].weapon=3;g.players[1].owned.append(3);g.desired_weapon=3
		hand.position=Vector3(.3 if left else -.3,1.8,.15)
		rig.physical_reload.pump_held=true;rig.support_aim.engaged=true
		b.inputs={"support":true,"offhand_fire":true};frame()
		check(rig.physical_actions.gesture.held and not rig.physical_reload.pump_held and not rig.support_aim.engaged,"Shoulder grenade takes priority over held shotgun pump")
		check(not rig.command(seq+1).reload_grip and not rig.command(seq+1).xr.get("pump",false),"Shoulder grenade also releases authoritative pump input")
		u.cancel(1);rig.physical_actions.reset();b.inputs={};frame()
		g.voice_enabled=true;g.voice.mode=1
		hand.position=Vector3(.3 if left else -.3,1.1,-.4);b.inputs={"support":true};frame()
		rig.physical_reload.pump_held=true;rig.support_aim.engaged=true
		hand.position=rig.shoulder_radio.shoulder();frame()
		check(rig.shoulder_radio.held and not rig.physical_reload.pump_held and not rig.support_aim.engaged,"Pump hand transfers held grip to shoulder radio")
		check(not rig.command(seq+1).reload_grip,"Radio releases authoritative reload grip")
		b.inputs={};frame()
		b.inputs={};frame();u.state(1).counts=[0,0,0];b.inputs={"support":true,"offhand_fire":true};frame()
		check(not rig.physical_actions.gesture.held and u.selected(1)==-1,"Empty utility rejects physical arm immediately")
	rig.left_handed=false;rig.right.transform=Transform3D(Basis.IDENTITY,Vector3(.2,1.2,-.35))
	rig.right_aim.transform=rig.right.transform
	b.inputs={};u.cancel(1);u.state(1).counts=[1,2,1];u.state(1).cooldown=0
	g.players[1].owned=range(12);g.players[1].ammo=[240,64,300,40];g.players[1].serial+=1;g.players[1].weapon=6;g.desired_weapon=6;frame()
	rig.left.position=preload("res://deathmatch/counterstrike/reload_state.gd").model_pose(rig.sample_pose(),6)*preload("res://deathmatch/counterstrike/models.gd").support(6)
	b.inputs={"support":true,"offhand_fire":true};frame();frame()
	check(rig.support_aim.engaged and not rig.physical_actions.busy() and not u.state(1).primed,"Gripping and triggering at the handguard keeps gun support without arming a grenade")
	b.inputs={};frame();u.state(1).counts=[1,0,0];u.state(1).cooldown=0
	# A separately updated XR aim node must not drag a grip-anchored gun.
	for left in [false,true]:
		rig.left_handed=left;b.inputs={};rig.virtual_stock.reset();rig.support_aim.reset()
		var grip=rig.left if left else rig.right
		var aim=rig.left_aim if left else rig.right_aim
		grip.transform=Transform3D(Basis(Vector3.UP,.2),Vector3(.2,1.25,-.35))
		aim.transform=grip.transform*Transform3D(Basis(Vector3.RIGHT,.1),Vector3(0,.04,-.08))
		frame()
		check(rig.gun.get_parent()==grip and rig.gun.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Local gun follows grip without physics interpolation, left="+str(left))
		var held: Transform3D=rig.gun.global_transform
		aim.position+=Vector3(.02,-.01,.03)
		check(rig.gun.global_transform.is_equal_approx(held),"Late aim translation cannot jitter the held model")
		grip.position+=Vector3(.03,.02,-.04)
		check(rig.gun.global_position.is_equal_approx(held.origin+rig.origin.global_basis*Vector3(.03,.02,-.04)),"Late grip motion moves the gun immediately with the hand")
		var local: Transform3D=grip.global_transform.affine_inverse()*rig.gun.global_transform
		rig.position+=Vector3(1,0,2);rig.rotate_y(.15)
		check((grip.global_transform.affine_inverse()*rig.gun.global_transform).is_equal_approx(local),"Locomotion and turning preserve gun position in the palm")
	var rpc=g.match_mode.fortress.physical;var pose: Dictionary=rig.sample_pose();var sequence: int=rig.physical_actions.sequence+100
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial-1,sequence,"arm",pose,Vector3.ZERO),"Stale life rejects DE physical arm")
	check(rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence,"arm",pose,Vector3.ZERO),"Fresh physical arm accepted")
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence,"throw",pose,Vector3.ZERO),"Duplicate physical sequence cannot throw")
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence+1,"throw",pose,Vector3(NAN,0,0)) and u.selected(1)==-1,"Nonfinite stroke cancels held equipment")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/classic-de/grenade-vr.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("DE_GRENADE_VR_RESULT ",JSON.stringify(result))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
