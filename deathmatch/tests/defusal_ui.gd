extends SceneTree
var g
var rig
var wheel
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func select(item: int):
	var index: int=wheel.entries.map(func(row):return row.id).find(item)
	check(index>=0,"Wheel offers "+str(item))
	if index<0:return
	var angle: float=TAU*index/wheel.entries.size()
	wheel.update(Vector2(sin(angle),cos(angle)));wheel.update(Vector2.ZERO)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Shop UI",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide()
	g.menu_open=false;g.hud.show_menu(false)
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);wheel=rig.weapon_wheel;wheel.toggle(Vector2.ZERO)
	check(wheel.shopping and rig.wheel_open() and wheel.entries.size()==5,"Right-click wheel becomes categorized shop during preparation")
	rig.right.position=Vector3(.28,1.1,-.6);wheel.update(Vector2.ZERO)
	var before: Vector3=wheel.global_position
	rig.right.position+=Vector3(.2,.12,-.08);wheel.update(Vector2.ZERO)
	check((wheel.global_position-before).is_equal_approx(rig.origin.global_basis*Vector3(.2,.12,-.08)),"Open buy wheel follows dominant hand while browsing")
	select(200);check(rig.wheel_open() and wheel.page==200,"Tilt/recenter opens sidearms category without closing")
	rig.left_handed=true;rig.left.position=Vector3(-.3,1.15,-.6);wheel.update(Vector2.ZERO)
	check(absf(wheel.global_position.x-rig.left.global_position.x)<.001,"Buy submenu follows left dominance without changing categories")
	rig.left_handed=false
	select(10);check(de.account(1).cash==150 and g.players[1].owned==[0,10],"Wheel selection purchases through production authority")
	check(rig.wheel_open() and g.desired_weapon==10,"Buy wheel persists for more purchases and equips new sidearm")
	g.clock+=.2;select(2);check(de.account(1).cash==150 and not g.players[1].owned.has(2),"Unaffordable wheel entry cannot grant equipment")
	select(1000);check(wheel.page==0 and rig.wheel_open(),"Back entry returns to purchase categories")
	var original_position: Vector3=g.fighters[1].position
	var original_team: int=g.players[1].team
	var original_owned: Array=g.players[1].owned.duplicate()
	var original_cash: int=de.account(1).cash
	for team in [0,1]:
		g.players[1].team=team;g.fighters[1].position=de.spawns(team)[0]
		for left in [false,true]:
			rig.left_handed=left
			for item in [9,6 if de.role(1)==0 else 7]:
				de.credit(1,16000);g.players[1].owned=[0,10];g.clock+=.2
				wheel.page=201;wheel.entries=wheel.inventory();wheel.input.open(wheel.entries.map(func(row):return row.id),Vector2.ZERO);wheel.refresh_view()
				var index: int=wheel.entries.map(func(row):return row.id).find(item)
				var point: Vector2=wheel.view.ring_point(TAU*index/wheel.entries.size(),286)-wheel.view.CENTER
				var stick:=Vector2(point.x,-point.y).normalized()
				wheel.update(stick)
				check(wheel.input.hover==index and wheel.view.rows[index].id==item,"Displayed buy angle highlights the matching weapon: "+str([team,left,item]))
				wheel.update(Vector2(signf(stick.x)*.8,0));wheel.update(Vector2.ZERO)
				check(g.players[1].owned.has(item) and g.desired_weapon==item,"Diagonal release buys AWP/rifle rather than adjacent P90/MP5: "+str([team,left,item]))
	g.fighters[1].position=original_position;g.players[1].team=original_team;g.players[1].owned=original_owned;g.players[1].weapon=10;g.desired_weapon=10;de.account(1).cash=original_cash;rig.left_handed=false
	wheel.toggle(Vector2.ZERO);check(not rig.wheel_open(),"Second joystick press dismisses shop")
	wheel.toggle(Vector2.ZERO);g.clock=de.phase_end;de.tick(0);wheel.update(Vector2.ZERO)
	check(not rig.wheel_open() and not wheel.input.captures_stick,"Preparation ending closes shop and releases the stick")
	wheel.toggle(Vector2.ZERO);check(not wheel.shopping and wheel.entries.map(func(row):return row.id)==[0,10],"Live round restores ordinary owned-weapon wheel")
	wheel.close()
	var was: bool=rig.virtual_stock_enabled;rig.turn_panel.stock.pressed.emit()
	check(rig.virtual_stock_enabled!=was and rig.turn_panel.stock.text.contains("ON" if rig.virtual_stock_enabled else "OFF"),"VR menu toggles virtual stock immediately")
	check(rig.Preferences.read_settings().virtual_stock==rig.virtual_stock_enabled,"VR menu stock choice persists")
	var panel=load("res://deathmatch/ui/defusal_panel.gd").new();g.add_child(panel);panel.setup(de)
	de.phase="prepare";de.phase_end=g.clock+15;panel.toggle()
	check(panel.opened and panel.view.rows.size()==5,"Desktop purchase panel uses the same categorized wheel")
	panel.select(202);check(panel.view.rows.any(func(row):return row.id==100),"Desktop equipment category exposes armor")
	panel.handle_key(KEY_ESCAPE);check(not panel.opened,"Desktop Escape closes purchase panel")
	g.players[1].dead=true;g.players[1].respawn_at=INF;g.hud._process(.016)
	check(g.hud.center_message.text.contains("SPECTATING") and g.hud.center_message.text.contains("DEAD VOICE ONLY"),"Desktop death HUD does not promise an unavailable respawn")
	rig._process(.016)
	check(rig.status_hud.values.wait_for_round,"VR death HUD waits for the next round")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_UI_RESULT ",JSON.stringify(result));panel.free();g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
