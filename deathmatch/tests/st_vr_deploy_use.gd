extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Equipment=preload("res://deathmatch/tribes/equipment.gd")
var g
var rig
var rules
var preview
var left: XRControllerTracker
var right: XRControllerTracker
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func packet():
	g.sequence+=1;g._accept_input(1,rig.command(g.sequence))
func button(action: String,pressed: bool):
	var binding: PackedStringArray=g.bindings.vr[action].split(":")
	var hand=rig.game.bindings.controller(rig,binding[0]);var tracker=left if hand==rig.left else right
	tracker.set_input(binding[1],float(pressed) if binding[1] in ["grip","trigger"] else pressed)
func frame():
	rig.physical_actions.update(.02,true);packet()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Deploy Use",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);rules=g.match_mode.tribes;rules.set_process(false)
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(rig);g.xr_rig=rig;rig.setup(g,true)
	rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide();rig.focused=true;rig.origin_offset=Vector3.ZERO
	left=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	right=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(80,1,80))
	rules.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(40,2,40),Vector3(80,30,80))
	var s: Dictionary=g.players[1];s.team=0;s.dead=false;s.spectator=false;g.menu_open=false;g.local_yaw=0;s.yaw=0
	g.fighters[1].position=Fixture.ORIGIN;g.fighters[1].velocity=Vector3.ZERO;rig.position=Fixture.ORIGIN
	rig.head.position=Vector3(0,1.65,0)
	preview=load("res://deathmatch/tribes/deployable_view.gd").new();g.add_child(preview);preview.setup(rules)
	await process_frame;await physics_frame
	for mirrored in [false,true]:
		for action in ["use","offhand_fire","rebound_use"]:
			rules.deployables.reset();rules.combat.held.clear();rig.physical_actions.reset();rig.control_edges.clear()
			for tracker in [left,right]:
				tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("ax_button",false);tracker.set_input("by_button",false)
			rig.left_handed=mirrored;rig.left_controls=mirrored
			g.bindings.vr.use="weapon:ax_button" if action=="rebound_use" else "move:ax_button"
			rules.apply_equipment(1,"medium",[3,2,4],"turret");g.desired_weapon=3;s.input_blocked=false;g.clock+=1
			var offhand=rig.right if mirrored else rig.left;var gunhand=rig.left if mirrored else rig.right;var aim=rig.left_aim if mirrored else rig.right_aim;var offaim=rig.right_aim if mirrored else rig.left_aim
			gunhand.position=Vector3(.3 if not mirrored else -.3,1.2,-.3);gunhand.basis=Basis.IDENTITY;aim.transform=gunhand.transform
			offhand.transform=Equipment.mount(rig.sample_pose(),"pack");offaim.transform=offhand.transform
			await physics_frame
			frame();button("support",true);frame()
			var label: String=("left dominant " if mirrored else "right dominant ")+action
			check(rig.physical_actions.equipment.item=="pack" and rules.combat.held.get(1,{}).get("item")=="pack","Chest grip holds checked pack: "+label)
			offhand.position=Vector3(.35 if mirrored else -.35,1.2,-.4);offhand.basis=Basis.looking_at(Vector3.UP,Vector3.FORWARD);offaim.transform=offhand.transform
			frame()
			var input_action: String="offhand_fire" if action=="offhand_fire" else "use"
			button(input_action,true)
			if input_action=="use":rig.poll_controls()
			else:frame()
			check(s.tribes_pack=="turret" and not rig.physical_actions.equipment.used and rules.deployables.rows.is_empty(),"Rejected placement retains pack for retry: "+label)
			offaim.transform=Transform3D(Basis.looking_at(Vector3(0,-.6,-1).normalized(),Vector3.UP),offhand.position);frame()
			var expected: Dictionary=rules.deployables.placement(1,offhand.global_position,-offaim.global_basis.z)
			check(not expected.is_empty(),"Offhand aim has clear placement while grip and gun point away: "+label)
			preview.update()
			check(is_instance_valid(preview.ghost) and preview.ghost.visible and preview.ghost.global_position.is_equal_approx(expected.get("position",Vector3.INF)),"Displayed ghost follows offhand aim, not grip: "+label)
			var held: Node3D=rig.physical_actions.equipment.models.pack
			check((-held.global_basis.z).dot(-offaim.global_basis.z)>.999 and held.global_position.distance_to(offhand.global_position)<.041,"Held pack faces along aim and stays at palm: "+label)
			if input_action=="use":rig.poll_controls()
			else:frame()
			check(rules.deployables.rows.is_empty(),"Held activation button cannot repeatedly deploy: "+label)
			button(input_action,false)
			if input_action=="use":rig.poll_controls()
			else:frame()
			button(input_action,true)
			if input_action=="use":rig.poll_controls()
			else:frame()
			check(rules.deployables.rows.size()==1 and s.tribes_pack=="none","Fresh activation deploys exactly one pack: "+label)
			if not rules.deployables.rows.is_empty() and not expected.is_empty():check(rules.deployables.rows.values()[0].position.is_equal_approx(expected.position),"Deployment matches offhand preview: "+label)
			button(input_action,false);rig.poll_controls();button(input_action,true);rig.poll_controls()
			check(rules.deployables.rows.size()==1,"Consumed held pack cannot activate another item: "+label)
	# Accessibility path: Use without a held pack keeps the original aimed deployment.
	rules.deployables.reset();rules.combat.held.clear();rig.physical_actions.reset();rig.control_edges.clear();rig.left_handed=false;rig.left_controls=false;g.bindings.vr.use="move:ax_button"
	for tracker in [left,right]:tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("ax_button",false)
	rules.apply_equipment(1,"medium",[3,2,4],"turret");s.input_blocked=false;g.clock+=1
	rig.right.position=Vector3(.3,1.2,-.4);rig.right_aim.transform=Transform3D(Basis.looking_at(Vector3(0,-.6,-1).normalized(),Vector3.UP),rig.right.position)
	await physics_frame
	frame();button("use",true);rig.poll_controls()
	check(rules.deployables.rows.size()==1,"Use without a held pack retains ordinary weapon-aim deployment")
	var old_pose: Dictionary=preload("res://deathmatch/vr/poses.gd").neutral()
	check(Equipment.hand_frame(old_pose)==old_pose.left,"Older recorded poses retain grip fallback")
	old_pose.offhand_weapon=Transform3D(Basis(Vector3.RIGHT,.7),old_pose.left.origin+Vector3.RIGHT*.2)
	check(Equipment.hand_frame(old_pose).origin==old_pose.left.origin,"Aim offset cannot detach held pack from palm")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	print("ST_VR_DEPLOY_USE ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
