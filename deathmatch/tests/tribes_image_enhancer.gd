extends SceneTree
const Enhancer=preload("res://deathmatch/tribes/image_enhancer.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var zoom:=Enhancer.new()
	for base in [65.0,85.0,110.0,120.0]:
		for amount in Enhancer.LEVELS:
			var fov:=Enhancer.zoom_fov(base,amount)
			check(is_equal_approx(tan(deg_to_rad(base)*.5)/tan(deg_to_rad(fov)*.5),amount),"True perspective magnification %s/%s"%[base,amount])
	zoom.update(true,true);check(zoom.active and zoom.magnification()==2,"Hold enters 2x")
	for amount in [5,10,20,2]:zoom.cycle();check(zoom.magnification()==amount,"Range cycles to %d"%amount)
	zoom.cycle(-1);check(zoom.magnification()==20,"Range wraps backwards")
	zoom.update(true,false);check(not zoom.active,"Blocked state exits zoom")
	zoom.update(true,true);check(not zoom.active,"Blocked trigger cannot resume until released")
	zoom.update(false,true);zoom.update(true,true);check(zoom.magnification()==20,"Release permits re-entry at remembered range")
	zoom.update(false,false);zoom.update(true,true);check(not zoom.active,"Unavailable tracking input is not mistaken for a trigger release")
	zoom.reset();check(not zoom.active and zoom.index==0,"Session reset restores default range")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Image enhancer checks",0,100,30,true,"tdm","tribes");g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	var rules=g.match_mode.tribes;var state: Dictionary=g.players[1];zoom=rules.enhancer
	g.menu_open=false;state.dead=false;state.spectator=false;state.fire=false;state.alt_fire=true
	for slot in 12:
		state.weapon=slot
		check(zoom.allowed(),"Image enhancer available with Tribes slot %d"%slot)
		rules.combat.tick_input(1,0)
		check(state.weapon_zoom,"Authority accepts shared zoom for slot %d"%slot)
	for key in ["dead","spectator"]:
		state[key]=true;check(not zoom.allowed(),key+" disables enhancer");state[key]=false
	for key in ["menu_open","map_loading","quitting"]:
		g.set(key,true);check(not zoom.allowed(),key+" disables enhancer");g.set(key,false)
	g.intermission=1;check(not zoom.allowed(),"Intermission disables enhancer");g.intermission=0
	var key:=InputEventKey.new();key.physical_keycode=g.bindings.keys.zoom_range;key.pressed=true
	check(rules.desktop_input(key) and zoom.index==1,"Bound range action reaches enhancer")
	key.echo=true;check(not rules.desktop_input(key) and zoom.index==1,"Key repeat cannot cycle ranges")
	# Real rig input routing with synthetic controller events, including the
	# offhand equipment chord and left-handed bindings. No headset required.
	var rig=preload("res://deathmatch/vr/rig.gd").new();g.add_child(rig);rig.set_process(false)
	rig.game=g;rig.enabled=true;rig.simulated=true;g.xr_rig=rig
	rig.origin=XROrigin3D.new();rig.add_child(rig.origin)
	rig.head=XRCamera3D.new();rig.origin.add_child(rig.head)
	rig.head.global_position=g.fighters[1].global_position+Vector3.UP*1.45
	rig.setup_controllers();rig.blackout=MeshInstance3D.new();rig.add_child(rig.blackout);rig.blackout.hide()
	rig.gun=Node3D.new();rig.add_child(rig.gun)
	var hand_mesh:=MeshInstance3D.new();hand_mesh.mesh=BoxMesh.new();hand_mesh.layers=5;rig.add_child(hand_mesh)
	var trackers: Array=[]
	for side in ["left_hand","right_hand"]:
		var tracker:=XRControllerTracker.new();tracker.name=side;XRServer.add_tracker(tracker);trackers.append(tracker)
	var visor=preload("res://deathmatch/vr/tribes_visor.gd").new();rig.add_child(visor);visor.setup(rig)
	state.weapon=3;state.yaw=0;state.pitch=0
	zoom.update(false,true);trackers[0].set_input("trigger",1.0)
	visor.update_rig()
	check(zoom.active and visor.screen.visible,"VR support trigger opens visor with disc launcher")
	check(hand_mesh.layers==visor.Optic.SCOPE_LAYER,"Local hands are masked from visor camera")
	check(visor.overlay.aim_visible,"VR aim is projected into the magnified image")
	var old_range: int=zoom.index
	rig.gun.free();rig.gun=Node3D.new();rig.add_child(rig.gun);state.weapon=2;visor.update_rig()
	check(zoom.active and zoom.index==old_range and visor.masked_weapon_id==rig.gun.get_instance_id(),"Replacing the weapon while zoomed keeps range and refreshes visibility masks")
	var range_before: int=zoom.index;var grenade_before: int=state.tribes_grenade
	rig.cycle_equipment(1)
	check(zoom.index==posmod(range_before+1,4) and state.tribes_grenade==grenade_before,"Zoom chord routes stick to range without selecting a grenade")
	state.yaw=PI;visor.update_rig();check(not visor.overlay.aim_visible,"Weapon aimed behind visor has no false central crosshair");state.yaw=0
	trackers[0].set_input("grip",1.0);visor.update_rig()
	check(not zoom.active and not visor.screen.visible,"Equipment grip chord closes visor")
	check(hand_mesh.layers==5,"Closing visor restores original visibility layers")
	trackers[0].set_input("grip",0.0);visor.update_rig();check(not zoom.active,"Grip release cannot reopen a held zoom trigger")
	trackers[0].set_input("trigger",0.0);visor.update_rig()
	rig.left_handed=true;trackers[1].set_input("trigger",1.0);visor.update_rig()
	check(zoom.active,"Left-handed visor uses right support trigger")
	rig.focused=false;visor.update_rig()
	check(not zoom.active and visor.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Focus loss suspends all visor rendering")
	rig.focused=true;visor.update_rig();check(not zoom.active,"Focus recovery requires trigger release")
	trackers[1].set_input("trigger",0.0);visor.update_rig()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	rig.enabled=false;g.xr_rig=null;rig.free()
	for arsenal in ["cs16","ut99","doom","quake"]:
		g.armory.select(arsenal);check(not zoom.allowed(),"No visor in "+arsenal)
	check(preload("res://deathmatch/settings/bindings.gd").KEYS.use==KEY_E and preload("res://deathmatch/settings/bindings.gd").KEYS.prone==KEY_Z,"Existing Use and prone bindings retained")
	g.disconnect_game();g.free()
	var report:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/tribes-image-enhancer/logic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIBES_IMAGE_ENHANCER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
