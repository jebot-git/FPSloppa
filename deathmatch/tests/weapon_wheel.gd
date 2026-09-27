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
	check(game.bindings.vr.weapon_wheel=="right:primary_click","Default wheel uses physical right joystick click")
	right.set_input("primary_click",true);rig.poll_controls()
	var wheel=rig.weapon_wheel
	check(rig.wheel_open() and wheel.visible,"Right joystick click opens the VR wheel")
	rig.poll_controls();check(rig.wheel_open(),"Holding click does not repeatedly toggle")
	right.set_input("primary_click",false);rig.poll_controls();wheel.update(Vector2.ZERO)
	right.set_input("trigger",1.0);left.set_input("trigger",1.0)
	var command: Dictionary=rig.command(10)
	check(not command.fire and not command.alt_fire and not command.offhand_fire and not command.melee and command.input_blocked,"Wheel suppresses combat commands")
	check(command.move.length()>.7,"Left joystick movement remains available")
	right.set_input("primary",Vector2.RIGHT);wheel.update(Vector2.RIGHT)
	check(rig.control_axis("turn")==Vector2.ZERO and game.desired_weapon==2,"Highlight consumes turning without changing weapon")
	right.set_input("primary",Vector2.ZERO);wheel.update(Vector2.ZERO)
	check(not rig.wheel_open() and game.desired_weapon==3 and rig.command(11).weapon==3,"Joystick selection reaches normal weapon command")
	game._accept_input(1,rig.command(12));check(game.players[1].weapon==3,"Server accepts selected owned weapon through existing input path")
	wheel.toggle(Vector2.ZERO);wheel.update(Vector2.RIGHT);right.set_input("primary_click",true);rig.poll_controls()
	check(not rig.wheel_open() and game.desired_weapon==3,"Second click cancels without changing weapon")
	right.set_input("primary_click",false);rig.poll_controls();wheel.update(Vector2.ZERO)
	rig.left_controls=true;rig.left_handed=true;right.set_input("primary_click",true);rig.poll_controls()
	right.set_input("primary",Vector2.RIGHT);wheel.update(Vector2.RIGHT)
	check(rig.wheel_open() and rig.control_axis("move")==Vector2.ZERO and rig.control_axis("turn")==Vector2.ZERO,"Mirrored controls keep physical right selection and consume conflicting axes")
	wheel.reset();rig.left_controls=false;rig.left_handed=false
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
	game.bindings.vr.weapon_wheel="right:primary_click";game.bindings.save()
	for key in Icons.NAMES:
		var icon=Icons.texture(key);check(icon!=null and icon.get_width()==128,"Icon imports: "+key)
	wheel.reset();check(wheel.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closed wheel stops viewport rendering")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	game.disconnect_game();game.free();print("WEAPON_WHEEL_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
