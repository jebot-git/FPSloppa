extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	root.title="ST deployables UI validation";root.size=Vector2i(1280,800);root.position=Vector2i(6000,6000)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Deployable UI",0,100,30,true,"st")
	g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	var r=g.match_mode.tribes;var d=r.deployables;var s: Dictionary=g.players[1];var actor=g.fighters[1]
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(30,1,30))
	Fixture.box(g,Fixture.ORIGIN+Vector3(0,1,-7),Vector3(3,2,1))
	r.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(15,2,15),Vector3(30,20,30))
	actor.position=Fixture.ORIGIN;s.team=0;s.yaw=0;s.pitch=.5;g.menu_open=false
	r.apply_equipment(1,"light",[3,2,4],"camera")
	await physics_frame;await physics_frame
	check(d.deploy(1,actor.position+Vector3.UP*1.6,Vector3(0,-.8,-1).normalized()),"Camera placed in rendered world")
	var key: int=d.next_id-1;g.clock+=2
	r._process(0);var view=r.deployable_view
	check(is_instance_valid(view),"Graphical deployable view created")
	view.watch(key);view.update();var saved_camera: Transform3D=g.camera.global_transform
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	check(view.camera_key==key and view.panel.visible and not view.vr_panel.visible,"Friendly camera opens desktop video panel")
	check(g.camera.global_transform==saved_camera,"Remote video never moves the player's camera")
	check(view.viewport.size==Vector2i(512,288),"Remote camera uses bounded render resolution")
	var image: Image=view.viewport.get_texture().get_image();var colors: Dictionary={}
	for y in range(0,image.get_height(),16):
		for x in range(0,image.get_width(),16):colors[image.get_pixel(x,y).to_html()]=true
	check(colors.size()>4,"Remote viewport renders real scene content")
	image.save_png("res://test-results/st-tribes/research/remote-camera.png")
	s.team=1;view.update();check(view.camera_key<0 and not view.panel.visible,"Team change immediately closes enemy camera");s.team=0
	view.watch(key);s.dead=true;view.update();check(view.camera_key<0,"Death closes camera");s.dead=false
	view.watch(key);d.rows.erase(key);view.update();check(view.camera_key<0,"Destroyed camera closes view")
	var wheel=preload("res://deathmatch/tribes/buy_wheel.gd").new();wheel.open(s);wheel.select(206,r,1)
	var rows: Array=wheel.rows(r,1)
	check(rows.size()==8 and rows.count(null)==0,"All seven deployables fit on one wheel page")
	check(rows.filter(func(row):return row.id in [306,307,308]).all(func(row):return not row.usable),"Light armour disables the three heavy deployable packs")
	var camera_row: Dictionary={"kind":"camera","team":0,"owner":1,"position":Fixture.ORIGIN,"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp("camera"),"energy":0.0,"ready":0.0,"aim":Vector3.FORWARD}
	for i in 15:d.rows[10+i]=camera_row.duplicate()
	d.rows[100]=camera_row.duplicate();d.rows[100].team=1
	wheel.select(207,r,1);var seen: Array=[]
	for i in 8:
		rows=wheel.rows(r,1);check(rows.size()<=8,"Camera wheel page %d stays readable"%i)
		for row in rows:
			if row.id>2000:seen.append(row.id)
		wheel.select(1001,r,1)
	check(seen.size()==15 and 2100 not in seen,"All friendly cameras are reachable; enemy cameras are excluded")
	check(wheel.camera_page==0,"Last camera page wraps back to the first")
	wheel.select(208,r,1);rows=wheel.rows(r,1)
	var fixed=r.stations().defences
	check(rows.size()<=8 and rows.filter(func(row):return row.id>4000).size()==1 and rows.filter(func(row):return row.id>4000).all(func(row):return fixed.rows[row.id-4001].team==s.team),"Turret page exposes the friendly base turret only")
	s.input_blocked=false;wheel.select(rows.filter(func(row):return row.id>4000)[0].id,r,1)
	check(fixed.operated(1)>=0,"Selecting the turret entry claims control through ordinary rules")
	wheel.select(4000,r,1);check(fixed.operated(1)==-1,"Wheel release relinquishes manual control")
	var guns: Array=wheel.guns.duplicate();wheel.select(-1,r,1);check(wheel.guns==guns,"Disabled contact indicator cannot mutate weapon selection")
	d.reset();await physics_frame
	r.apply_equipment(1,"medium",[3,2,4],"turret");r._process(0)
	check(is_instance_valid(view.ghost),"Purchased deployable creates a local placement preview")
	var status=preload("res://deathmatch/ui/player_status.gd")
	d.contacts=[[],[1]];check(status.read(g,1).carrier=="SENSOR: DETECTED","Shared desktop and VR status reports actual detection")
	d.contacts=[[],[]];d.suppressed=[1];check(status.read(g,1).carrier=="SENSOR: JAMMED","Shared status distinguishes suppressed scans")
	g.match_mode.flags[1].carrier=1
	check(status.read(g,1).carrier=="ENEMY FLAG · RETURN HOME · SENSOR: JAMMED","Flag instruction and sensor status fit on the same HUD row")
	g.match_mode.flags[1].carrier=0;d.suppressed=[]
	var pads=r.stations();pads.assets.rows[0].hp=0;pads.assets.update()
	check(pads.rows[0].label.text=="INVENTORY STATION · DISABLED","Damaged station has visible service status")
	check(pads.assets.rows[4].label.text=="PULSE SENSOR · 100%","Fixed pulse sensor has visible durability status")

	wheel.select(209,r,1);rows=wheel.rows(r,1)
	check(rows.size()==7 and [204,210,211,212,213,214,1000].all(func(key):return rows.any(func(row):return row.id==key)),"Field wheel fits repair, transfers and beacon actions")
	r.apply_equipment(1,"heavy",[3,4,7],"energy");s.weapon=7;s.input_blocked=false
	var payload: Dictionary=r.recovery.empty_payload();payload.ammo[2]=37
	r.recovery.create(0,payload,actor.position+Vector3(1,.25,-3),Vector3.ZERO,"ammo")
	r.targeting.beacons[1]={"team":0,"position":actor.position+Vector3(0,.2,-40),"normal":Vector3.UP,"hp":.1*r.Arsenal.UNIT}
	r.targeting.beacons[2]={"team":1,"position":actor.position+Vector3(4,.2,-45),"normal":Vector3.UP,"hp":.1*r.Arsenal.UNIT}
	r._process(0);g.clock+=.2;r.field_view.update()
	check(r.field_view.nodes.size()==3,"Vulkan field view builds two physical beacons and a stored-ammo drop")
	check(r.field_view.markers.has("b1") and not r.field_view.markers.has("b2"),"Only friendly shared target receives aiming UI")
	check(r.field_view.nodes["r1"].get_node("Info").text.contains("37"),"Recovered ammo model displays actual stored count")
	r.targeting.reset();r.recovery.reset();g.clock+=.2;r.field_view.update()
	check(r.field_view.nodes.is_empty() and r.field_view.markers.is_empty(),"Removed world equipment cleans meshes and aiming labels")
	g.match_mode.kind="tdm";view.update();check(not view.ghost.visible,"Leaving ST hides deployment preview")
	print("TRIBES_DEPLOYABLE_UI ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
