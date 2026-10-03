extends SceneTree
const State=preload("res://deathmatch/vr/weapon_wheel_state.gd")
const Icons=preload("res://deathmatch/ui/weapon_icons.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var state=State.new();state.open([2,3,6,8],Vector2.ZERO)
	for i in 1000:state.sample(Vector2.ZERO)
	check(state.opened,"Wheel persists without a timeout")
	state.sample(Vector2(.2,.1));check(state.hover==-1,"Centre noise does not select")
	state.sample(Vector2.RIGHT);check(state.opened and state.hover==1,"Tilt highlights without equipping")
	state.sample(Vector2(.3,0));check(state.opened,"Selection has recenter hysteresis")
	check(state.sample(Vector2.ZERO)==3 and not state.opened,"Recenter confirms highlighted weapon")
	state.open([2,3],Vector2.UP);state.sample(Vector2.UP)
	check(state.hover==-1 and state.waiting_for_center,"Opening off-centre requires neutral first")
	state.sample(Vector2.ZERO);state.sample(Vector2.DOWN);state.close()
	check(state.sample(Vector2.DOWN)==-1 and state.captures_stick,"Cancel consumes held stick without selecting")
	state.sample(Vector2.ZERO);check(not state.captures_stick,"Cancel releases capture after neutral")
	for count in [1,2,8,10,12]:
		var good:=true
		for i in count:
			var angle: float=TAU*i/count;good=good and State.sector(Vector2(sin(angle),cos(angle)),count)==i
		check(good,"Clockwise icon and input sectors agree for %d weapons"%count)
	for slot in [3,5]:
		var angle: float=TAU*slot/8
		state.open(range(8),Vector2.ZERO);state.sample(Vector2(sin(angle),cos(angle)))
		var drift:=Vector2(1 if slot==3 else -1,0)*.8
		state.sample(drift)
		check(state.hover==slot and state.sample(Vector2.ZERO)==slot,"Diagonal return cannot replace the highlighted purchase")
	state.open(range(8),Vector2.ZERO);state.sample(Vector2.DOWN);state.sample(Vector2.RIGHT*.8)
	state.sample(Vector2.RIGHT)
	check(state.hover==2 and state.sample(Vector2.ZERO)==2,"Pushing back to the rim permits deliberate reselection")
	state.open([2],Vector2.ZERO);state.sample(Vector2(NAN,0));check(not state.opened,"Invalid controller sample cancels safely")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	preload("res://deathmatch/tests/fixture.gd").setup(game)
	game.set_process(false);game.set_physics_process(false)
	game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	game.xr_rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);game.xr_rig.setup(game,true)
	var rig=game.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide()
	game._add_player(1,"Wheel test");game.active=true;game.menu_open=false;game.match_mode.kind="dm"
	game.armory.select("doom");game.players[1].owned=[2,3,6,8];game.players[1].weapon=2;game.desired_weapon=2
	game.players[1].dead=false;game.players[1].spectator=false
	var left:=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	var right:=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	left.set_input("primary",Vector2(.8,0));right.set_input("primary",Vector2.ZERO)
	await process_frame
	check(game.bindings.vr.weapon_wheel=="weapon:primary_click","Default wheel uses main-hand joystick click")
	right.set_input("primary_click",true);rig.poll_controls()
	var wheel=rig.weapon_wheel
	check(rig.wheel_open() and wheel.visible,"Right joystick click opens the VR wheel")
	var quad: QuadMesh=wheel.get_node("WheelSurface").mesh
	check(quad.size.x<.5 and quad.size==Vector2.ONE*quad.size.x,"VR wheel fits a compact hand-sized square")
	rig.head.position=Vector3(0,1.65,0);rig.right.position=Vector3(.25,1.2,-.55);rig.left.position=Vector3(-.25,1.2,-.55)
	rig.origin.position=Vector3(.1,.3,-.2);rig.rotation.y=.7;wheel.update(Vector2.ZERO)
	var initial: Vector3=wheel.global_position;var offset: Vector3=initial-rig.right.global_position
	check(offset.y>.15 and offset.y<.3 and Vector2(offset.x,offset.z).length()<.001,"Wheel sits above dominant grip under transformed XR origin")
	var delta:=Vector3(.14,.08,-.12);rig.right.position+=delta;wheel.update(Vector2.ZERO)
	check((wheel.global_position-initial).is_equal_approx(rig.origin.global_basis*delta),"Moving dominant hand translates the open wheel immediately")
	initial=wheel.global_position;rig.left.position+=Vector3(.2,-.1,.1);wheel.update(Vector2.ZERO)
	check(wheel.global_position.is_equal_approx(initial),"Support hand does not drag the weapon wheel")
	rig.head.position+=Vector3(-.1,.05,.1);rig.head.rotation=Vector3(.15,.35,.2);wheel.update(Vector2.ZERO)
	check(wheel.global_position.is_equal_approx(initial),"Head movement does not translate the hand-anchored wheel")
	check(wheel.global_basis.z.dot(wheel.global_position.direction_to(rig.head.global_position))>.999,"Wheel front faces the eyes after head movement")
	var upright: Basis=wheel.global_basis;rig.right.rotation=Vector3(.8,-.4,1.2);wheel.update(Vector2.ZERO)
	check(wheel.global_basis.is_equal_approx(upright),"Wrist roll does not rotate the joystick sectors")
	rig.left_handed=true;wheel.update(Vector2.ZERO)
	check((wheel.global_position-rig.left.global_position).is_equal_approx(offset),"Handedness change moves the open wheel to the left grip")
	initial=wheel.global_position;rig.left.position+=delta;wheel.update(Vector2.ZERO)
	check((wheel.global_position-initial).is_equal_approx(rig.origin.global_basis*delta),"Left-dominant wheel follows left hand motion")
	rig.left_handed=false;rig.rotation=Vector3.ZERO;rig.origin.position=Vector3.ZERO;rig.head.rotation=Vector3.ZERO;rig.right.rotation=Vector3.ZERO
	rig.poll_controls();check(rig.wheel_open(),"Holding click does not repeatedly toggle")
	right.set_input("primary_click",false);rig.poll_controls();wheel.update(Vector2.ZERO)
	right.set_input("trigger",1.0);left.set_input("trigger",1.0)
	var command: Dictionary=rig.command(10)
	check(not command.fire and not command.alt_fire and not command.offhand_fire and not command.melee and not command.input_blocked,"Wheel suppresses combat without blocking locomotion")
	check(command.move.length()>.7,"Left joystick movement remains available")
	var delivery=preload("res://deathmatch/network/movement_delivery.gd").new()
	command.input_life=game.players[1].serial;delivery.sample(command,command.input_life);delivery.annotate(command)
	game._accept_input(1,command)
	var accepted: Dictionary=delivery.consume(game.players[1])
	check(not accepted.is_empty() and accepted.move.length()>.7 and not game.players[1].input_blocked and not game.players[1].fire,"Authority retains movement and suppresses firing while the wheel is open")
	right.set_input("primary",Vector2.RIGHT);wheel.update(Vector2.RIGHT)
	check(rig.control_axis("turn")==Vector2.ZERO and game.desired_weapon==2,"Highlight consumes turning without changing weapon")
	right.set_input("primary",Vector2.ZERO);wheel.update(Vector2.ZERO)
	check(not rig.wheel_open() and game.desired_weapon==3 and rig.command(11).weapon==3,"Joystick selection reaches normal weapon command")
	game._accept_input(1,rig.command(12));check(game.players[1].weapon==3,"Server accepts selected owned weapon through existing input path")
	wheel.toggle(Vector2.ZERO);wheel.update(Vector2.RIGHT);right.set_input("primary_click",true);rig.poll_controls()
	check(not rig.wheel_open() and game.desired_weapon==3,"Second click cancels without changing weapon")
	right.set_input("primary_click",false);rig.poll_controls();wheel.update(Vector2.ZERO)
	rig.left_controls=true;rig.left_handed=true;left.set_input("primary",Vector2.ZERO);left.set_input("primary_click",true);rig.poll_controls()
	right.set_input("primary",Vector2.RIGHT);left.set_input("primary",Vector2.UP);wheel.update(Vector2.UP)
	check(rig.wheel_open() and rig.control_axis("move")==Vector2.RIGHT and rig.control_axis("turn")==Vector2.ZERO,"Mirrored controls use main-hand selection and preserve offhand movement")
	left.set_input("primary_click",false);rig.poll_controls()
	for weapon_left in [false,true]:
		for movement_left in [false,true]:
			rig.left_handed=weapon_left;rig.left_controls=movement_left
			var free=right if weapon_left else left
			free.set_input("primary",Vector2.RIGHT)
			check(rig.control_axis("move")==Vector2.RIGHT and rig.control_axis("turn")==Vector2.ZERO,"Free stick locomotion survives independent weapon/control handedness: "+str([weapon_left,movement_left]))
	wheel.reset();rig.left_controls=false;rig.left_handed=false
	game.armory.select("tribes");game.players[1].owned=[0,2,3];game.desired_weapon=3
	var seq:=100
	for mirrored in [false,true]:
		rig.left_controls=mirrored;rig.left_handed=mirrored
		var move=right if mirrored else left
		left.set_input("primary",Vector2.ZERO);right.set_input("primary",Vector2.ZERO)
		left.set_input("trigger",false);right.set_input("trigger",false)
		move.set_input("primary_click",true);rig.poll_controls()
		var ski: Dictionary=rig.command(seq);ski.input_life=game.players[1].serial;seq+=1
		check(ski.jump and ski.ski and not rig.wheel_open(),"Jump press also enters held ski without opening wheel: "+str(mirrored))
		var wire: Dictionary=preload("res://deathmatch/network/codec.gd").unpack(preload("res://deathmatch/network/input_delivery.gd").pack(ski))
		game._accept_input(1,wire);game._configure_tribes(1,game.players[1])
		game.fighters[1].simulate(Vector2.ZERO,0,false,1.0/60,true)
		check(game.fighters[1].tribes_state.skiing,"Packed input activates authoritative ski: "+str(mirrored))
		game.clock+=.1;game._configure_tribes(1,game.players[1])
		check(game.fighters[1].ski_held,"A short packet gap preserves held ski: "+str(mirrored))
		wheel.toggle(Vector2.ZERO);ski=rig.command(seq);ski.input_life=game.players[1].serial;seq+=1
		check(ski.ski and ski.jump and not ski.input_blocked,"Weapon wheel preserves held ski and jump: "+str(mirrored))
		game._accept_input(1,ski);game._configure_tribes(1,game.players[1])
		check(game.fighters[1].ski_held,"Authority retains skiing while wheel is open: "+str(mirrored))
		move.set_input("primary_click",false);rig.poll_controls();ski=rig.command(seq);ski.input_life=game.players[1].serial;seq+=1
		game._accept_input(1,ski);game._configure_tribes(1,game.players[1])
		check(not ski.jump and not game.fighters[1].ski_held,"Releasing jump ends ski normally: "+str(mirrored))
		wheel.reset()
	rig.left_controls=false;rig.left_handed=false;game.armory.select("doom");game.players[1].owned=[2,3,6,8];game.desired_weapon=3
	wheel.toggle(Vector2.ZERO);wheel.update(Vector2.RIGHT);game.players[1].owned=[2,6,8];wheel.update(Vector2.RIGHT)
	check(wheel.input.waiting_for_center and wheel.input.hover==-1,"Inventory changes rearm selection instead of changing highlighted slot")
	wheel.update(Vector2.ZERO);check(rig.wheel_open() and game.desired_weapon==3,"Inventory change cannot accidentally commit on release")
	for reason in ["dead","spectator","menu","focus","map","intermission"]:
		wheel.reset();wheel.toggle(Vector2.ZERO)
		match reason:
			"dead":game.players[1].dead=true
			"spectator":game.players[1].spectator=true
			"menu":game.menu_open=true
			"focus":rig.focused=false
			"map":game.map_loading=true
			"intermission":game.intermission=1
		wheel.update(Vector2.ZERO);check(not rig.wheel_open() and not wheel.visible,"Wheel cancels on "+reason)
		game.players[1].dead=false;game.players[1].spectator=false;game.menu_open=false;rig.focused=true;game.map_loading=false;game.intermission=0
	for arsenal in ["doom","quake","ut99","cs16"]:
		game.armory.select(arsenal);game.players[1].owned=range(game.armory.table.size())
		var rows: Array=wheel.inventory();var complete:=not rows.is_empty()
		for row in rows:complete=complete and Icons.NAMES.has(row.name) and Icons.texture(row.name)!=null
		check(complete,"Every "+arsenal+" weapon has a generated icon")
	game.match_mode.kind="tf";game.armory.select("quake")
	for role in ["scout","sniper","soldier","demoman","medic","heavy","pyro","spy","engineer"]:
		game.players[1].tf_class=role;game.armory.tf_loadout(game.players[1])
		var complete:=true
		for row in wheel.inventory():complete=complete and Icons.NAMES.has(row.name) and Icons.texture(row.name)!=null
		check(complete,"Class-specific weapon icons: "+role)
	game.match_mode.kind="dm";game.armory.select("doom");game.players[1].owned=[2,3,6]
	game.players[1].ammo=[50,0,20,0]
	var empty: Array=wheel.inventory().filter(func(row):return row.id==3)
	check(empty.size()==1 and not empty[0].usable and empty[0].ammo==0,"Owned empty weapons remain visible with an empty ammo indicator")
	wheel.toggle(Vector2.ZERO);wheel.update(Vector2.RIGHT);rig.on_spawn()
	check(not rig.wheel_open() and not wheel.input.captures_stick,"Respawn resets wheel and capture")
	game.bindings.vr.weapon_wheel="left:primary_click";check(game.bindings.save()==OK,"Wheel binding saves with existing controls")
	var saved=load("res://deathmatch/settings/bindings.gd").new();saved.load_settings()
	check(saved.vr.weapon_wheel=="left:primary_click","Wheel binding reloads")
	game.bindings.vr.weapon_wheel="weapon:primary_click";game.bindings.save()
	for key in Icons.NAMES:
		var icon=Icons.texture(key);check(icon!=null and icon.get_width()>=128 and icon.get_image().has_mipmaps(),"Icon imports: "+key)
	wheel.reset();check(wheel.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closed wheel stops viewport rendering")
	var head_tracker:=XRPositionalTracker.new();head_tracker.name="head";head_tracker.type=XRServer.TRACKER_HEAD;XRServer.add_tracker(head_tracker)
	head_tracker.set_pose("default",rig.head.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	left.set_pose("grip",rig.left.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	right.set_pose("grip",rig.right.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	rig.left_handed=true;wheel.toggle(Vector2.ZERO);rig.simulated=false
	check(rig.can_open_weapon_wheel() and rig.wheel_open(),"Tracked head and both controllers allow a left-dominant wheel")
	left.invalidate_pose("grip");await process_frame;wheel.update(Vector2.ZERO)
	check(not rig.wheel_open() and not wheel.visible,"Dominant grip tracking loss closes the left-hand wheel")
	wheel.toggle(Vector2.ZERO);check(not rig.wheel_open(),"Untracked dominant grip cannot reopen a stranded wheel")
	rig.simulated=true;XRServer.remove_tracker(head_tracker)
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	game.disconnect_game();game.free();print("WEAPON_WHEEL_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
