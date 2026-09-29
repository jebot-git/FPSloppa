extends SceneTree
const Icons=preload("res://deathmatch/ui/weapon_icons.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var rig
var wheel
var rules
var left: XRControllerTracker
var right: XRControllerTracker
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func select(entry: int):
	var index: int=wheel.entries.find(wheel.entries.filter(func(row):return row.id==entry).front()) if wheel.entries.any(func(row):return row.id==entry) else -1
	check(index>=0,"Wheel exposes action %d"%entry)
	if index<0:return
	var angle: float=TAU*index/wheel.entries.size()
	wheel.update(Vector2(sin(angle),cos(angle)));wheel.update(Vector2.ZERO)
func packet():
	var command: Dictionary=rig.command(g.sequence+1);g.sequence+=1
	g._accept_input(1,command)
func run():
	root.title="ST VR inventory validation";root.size=Vector2i(1280,800);root.position=Vector2i(6000,6000)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance";g.start_host("VR inventory",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);rules=g.match_mode.tribes;rules.set_process(false)
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide();rig.focused=true
	rig.head.position=Vector3(0,1.65,0);rig.left.position=Vector3(-.3,1.15,-.4);rig.right.position=Vector3(.3,1.15,-.4)
	left=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	right=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	left.set_input("primary",Vector2.ZERO);right.set_input("primary",Vector2.ZERO)
	await process_frame;await physics_frame
	wheel=rig.weapon_wheel;var s: Dictionary=g.players[1];s.team=0;s.input_blocked=false;s.dead=false;s.spectator=false
	var actor=g.fighters[1];actor.velocity=Vector3.ZERO
	var pads=rules.stations();rules.energy=[20000,20000,20000]
	var station: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].team==0 and pads.rows[i].kind=="inventory")[0]
	actor.position=pads.rows[station].position
	await physics_frame
	rules._process(0)
	check(wheel.input.opened and wheel.tribes_shop,"Actual Raindance inventory automatically opens VR shop")
	packet();check(s.input_blocked,"Open VR inventory blocks ordinary combat")
	select(202);select(401);select(201);select(302);select(203)
	check(s.tribes_class=="medium" and s.tribes_pack=="repair","Tilt/recenter refits selected armour and pack")
	check(wheel.input.opened and wheel.tribes_shop,"Purchase stays in inventory instead of becoming a weapon wheel")
	g._send_snapshot();wheel.update(Vector2.ZERO)
	check(wheel.input.opened and wheel.tribes_shop,"Authoritative refit snapshot preserves inventory through life-token reset")
	packet();select(209);s.hp=30;s.tribes_kit=true;select(204)
	check(s.hp>30 and not s.tribes_kit and wheel.input.opened,"Repair kit works while menu blocks held controls")
	g.clock+=1;select(214);check(s.tribes_beacons>0 and wheel.tribes_shop,"Beacon purchase remains on field equipment page")
	select(1000);select(207);select(1500)
	check(wheel.input.opened and wheel.tribes_shop,"Disabled sensor indicator cannot close or redirect the wheel")
	select(208)
	var turret: int=range(pads.defences.rows.size()).filter(func(i):return pads.defences.rows[i].team==0)[0]
	select(4001+turret)
	check(not wheel.input.opened and pads.defences.operated(1)==turret,"Turret selection closes wheel and claims manual control")
	rules._process(0);packet()
	for i in 50:
		g.clock+=.05;rules.turret_view.update();pads.defences.tick(.05)
	check(pads.defences.operated(1)==turret and rules.turret_view.key==turret,"Turret control survives the former lease timeout")
	rig.right_aim.rotation=Vector3(.15,-.4,0);right.set_input("trigger",true);g.clock+=.1;rules.turret_view.update()
	check(pads.defences.rows[turret].command.aim.is_equal_approx(-rig.right_aim.global_basis.z),"Turret aims along dominant aim pose, not grip orientation")
	check(pads.defences.rows[turret].command.fire,"VR trigger reaches turret fire")
	left.set_input("ax_button",true);rig.poll_controls();rules.turret_view.update()
	check(pads.defences.operated(1)<0 and rules.turret_view.key<0,"VR Use closes turret without reactivating a pack")
	left.set_input("ax_button",false);right.set_input("trigger",false);rig.poll_controls()
	var d=rules.deployables
	d.rows[1]={"kind":"camera","team":0,"owner":1,"position":actor.position+Vector3(3,1,0),"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp("camera"),"energy":0.0,"ready":0.0,"aim":Vector3.FORWARD}
	d.next_id=2;wheel.toggle(Vector2.ZERO);packet();select(207);select(2001);rules.deployable_view.update()
	check(not wheel.input.opened and rules.deployable_view.camera_key==1 and rules.deployable_view.vr_panel.visible,"Camera survives the last menu-blocked packet and shows VR panel")
	left.set_input("ax_button",true);rig.poll_controls();rules.deployable_view.update()
	check(rules.deployable_view.camera_key<0 and not rules.deployable_view.vr_panel.visible,"VR Use dismisses remote camera")
	left.set_input("ax_button",false);rig.poll_controls()
	wheel.toggle(Vector2.ZERO);select(205);check(wheel.input.opened and not wheel.tribes_shop,"Only explicit Carried Weapons switches to weapon selection")
	wheel.reset()
	var vehicle: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].team==0 and pads.rows[i].kind=="vehicle")[0]
	actor.position=pads.rows[vehicle].position;rules.local_station=-1;s.input_blocked=false
	await physics_frame
	rules._process(0);packet();wheel.update(Vector2.ZERO);rules._process(0)
	check(wheel.input.opened and wheel.tribes_shop and rules.vehicles.station(1)==vehicle,"Vehicle station shop persists while combat is blocked")
	select(5000);check(rules.vehicles.rows.size()==1 and wheel.tribes_shop and wheel.input.opened,"Vehicle purchase succeeds through the VR wheel")
	wheel.reset();rules.vehicles.reset()
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(30,1,30));actor.position=Fixture.ORIGIN
	var remote={"kind":"inventory","team":0,"owner":1,"position":Fixture.ORIGIN+Vector3(0,0,1.25),"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp("inventory"),"energy":700.0,"ready":0.0,"aim":Vector3.FORWARD}
	d.rows[2]=remote;s.input_blocked=false;rules.local_station=-1
	await physics_frame
	rules._process(0);packet();wheel.update(Vector2.ZERO);rules._process(0)
	check(wheel.input.opened and d.station(1)==2 and d.available(1)==700,"Portable station keeps its menu and local energy pool")
	check(not d.can_shop(1,"heavy","energy"),"Menu cannot bypass remote-station armour restrictions")
	select(201);select(303);var reserve: float=remote.energy;var bank: int=rules.energy[0];select(203)
	check(remote.energy!=reserve and rules.energy[0]==bank and s.tribes_pack=="shield","Portable-station refit spends its own reserve, not team energy")
	wheel.reset();d.rows.erase(2)
	# Raindance has inventory and vehicle pads; reuse the service fixture to
	# exercise the command-terminal path used by other ST maps.
	pads.rows[station].kind="command"
	actor.position=pads.rows[station].position;s.input_blocked=false;rules.local_station=-1
	await physics_frame
	rules.command_station_notice();packet();wheel.update(Vector2.ZERO)
	check(rules.pda_open() and not wheel.input.opened and not rules.can_refit(1),"Command terminal opens PDA without granting equipment refit")
	rules.command_view.device="f%d"%turret;rules.command_view.action("control");packet();rules.turret_view.update()
	check(pads.defences.operated(1)==turret and not wheel.input.opened,"Command-terminal turret is usable in VR")
	rules.close_remote_view();rules.turret_view.update()
	wheel.reset();pads.rows[station].kind="inventory";actor.position=pads.rows[station].position;s.input_blocked=false
	await physics_frame
	wheel.toggle(Vector2.RIGHT);wheel.update(Vector2.RIGHT);wheel.update(Vector2.ZERO)
	check(wheel.tribes_inventory.page==0 and wheel.input.opened,"Auto/open off-centre stick must recenter before selecting")
	var icon_ok:=true;var icon_count:=0
	for page in [0,200,201,202,206,207,208,209]:
		wheel.tribes_inventory.page=page
		for row in wheel.inventory():
			var title: String=row.get("icon",row.name);var texture=Icons.texture(title)
			icon_ok=icon_ok and (Icons.TRIBES.has(title) or Icons.NAMES.has(title)) and texture!=null and texture.get_image().has_mipmaps();icon_count+=1
	check(icon_ok,"All %d ST menu entries have mapped mipmapped icons"%icon_count)
	wheel.tribes_inventory.page=0;wheel.update(Vector2.ZERO)
	await process_frame;await RenderingServer.frame_post_draw
	wheel.viewport.get_texture().get_image().save_png("res://test-results/st-vr-inventory/root-menu.png")
	wheel.tribes_inventory.page=209;wheel.update(Vector2.ZERO)
	await process_frame;await RenderingServer.frame_post_draw
	wheel.viewport.get_texture().get_image().save_png("res://test-results/st-vr-inventory/field-menu.png")
	var sheet:=CanvasLayer.new();sheet.layer=100;root.add_child(sheet)
	var screen: Vector2=root.get_visible_rect().size
	var background:=ColorRect.new();background.color=Color("17212a");background.size=screen;sheet.add_child(background)
	var menu_icons: Array=Icons.TRIBES.keys().filter(func(key):return key.begins_with("ST "));menu_icons.sort()
	for i in menu_icons.size():
		var tile:=TextureRect.new();tile.texture=Icons.texture(menu_icons[i]);tile.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tile.size=Vector2(128,128);tile.position=(screen-Vector2(1242,780))*.5+Vector2(42+(i%6)*207,15+(i/6)*195);sheet.add_child(tile)
		var label:=Label.new();label.text=menu_icons[i].trim_prefix("ST ");label.position=tile.position+Vector2(-28,132);label.size=Vector2(190,36);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(label)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/st-vr-inventory/menu-icons.png");sheet.free()
	s.dead=true;wheel.update(Vector2.ZERO);check(not wheel.input.opened,"Death still closes inventory")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	print("ST_VR_INVENTORY ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
