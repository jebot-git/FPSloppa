extends SceneTree
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Stock=preload("res://deathmatch/vr/virtual_stock.gd")
const Preferences=preload("res://deathmatch/vr/preferences.gd")
var g
var de
var checks:=0
var failures: Array=[]
var seq:=100
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func send(id: int,pose: Dictionary,grip: bool=false,tap: bool=false,trigger: bool=false,blocked: bool=false):
	seq+=1;g.clock+=.2
	g._accept_input(id,{"seq":seq,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":g.players[id].weapon,"slow":false,"respawn":false,"xr":pose,"de_grip":grip,"de_tap":tap,"de_trigger":trigger,"input_blocked":blocked})
	de.sample_player(id)
func pose_at(weapon: Transform3D,left_handed: bool=false) -> Dictionary:
	var pose: Dictionary=Poses.neutral();pose.left_handed=left_handed;pose.weapon=weapon
	pose["left" if left_handed else "right"]=weapon
	pose.offhand_weapon=Transform3D(Basis.IDENTITY,Vector3(-.3,1.0,-.3))
	pose["right" if left_handed else "left"]=pose.offhand_weapon
	return pose
func touch(id: int,pose: Dictionary,digit: int):
	var tip: Vector3=de.base_pose(id).affine_inverse()*de.bomb_pose()*Contact.key_point(digit)
	pose.offhand_weapon=Transform3D(Basis.IDENTITY,tip+Vector3(0,0,.055));pose["right" if pose.left_handed else "left"]=pose.offhand_weapon
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("VR defusal",0,20,10,true,"de")
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false);de=g.match_mode.defusal
	await physics_frame;await physics_frame
	de.tick(0);g.clock=de.phase_end;de.tick(0)
	de.carrier=1;g.players[1].yaw=0.0;g.fighters[1].position=de.sites[0]+Vector3(0,0,.8)
	var pose: Dictionary=pose_at(Transform3D(Basis.IDENTITY,Vector3(0,1.27,-.24)))
	send(1,pose,true)
	check(de.held and not g.players[1].xr.is_empty(),"Validated primary grip draws bomb from chest carrier")
	check(de.combat_blocked(1),"Held bomb holsters firing and melee")
	check(not de.request(1,"digit",de.arm_code[0],g.map_epoch,de.round_id,g.players[1].serial,1),"VR cannot bypass spatial contacts with a keypad RPC")
	var before: int=de.arm_index;send(1,pose,true,true)
	check(de.arm_index==before,"Trigger far from keypad cannot enter a digit")
	for i in 4:
		pose.offhand_weapon.origin=Vector3(-.6,1,-.1);pose.left=pose.offhand_weapon;send(1,pose,true)
		touch(1,pose,de.arm_code[de.arm_index]);send(1,pose,true,true)
	check(de.arm_index==4 and de.armed_until>g.clock,"Four offhand keypad contacts arm the VR bomb")
	var mount: Transform3D=de.placement(1).get("pose",Transform3D(Basis(Vector3.RIGHT,-PI/2),de.sites[0]+Vector3.UP*.08))
	pose.head.origin.y=.95
	pose.weapon=de.base_pose(1).affine_inverse()*mount*Contact.HOLD.affine_inverse();pose.right=pose.weapon
	send(1,pose,true)
	check(de.planted and de.planted_site==0,"Pressing the armed bomb against the site floor plants it")
	g.players[-1].yaw=0.0;g.fighters[-1].position=de.sites[0]+Vector3(0,0,.7)
	var ct: Dictionary=pose_at(Transform3D(Basis.IDENTITY,Vector3(-.17,1,-.12)),true)
	ct.head.origin.y=.95
	for i in 3:
		touch(-1,ct,de.defuse_code[de.defuse_index]);send(-1,ct,false,true)
		ct.offhand_weapon.origin=Vector3(.6,1,-.1);ct.right=ct.offhand_weapon;send(-1,ct)
	check(de.defuse_index==3 and de.defuser==-1,"Left-handed offhand keypad entry uses mirrored controller roles")
	g.players[-1].input_blocked=true;de.sample_player(-1)
	check(de.defuse_index==0 and de.defuser==0,"Menu/focus block interrupts defusal progress")
	de.account(-1).kit=true
	ct=pose_at(Transform3D(Basis.IDENTITY,Vector3(-.17,1,-.12)),true);send(-1,ct,true)
	check(de.account(-1).tool,"CT draws purchased cutters with primary grip")
	send(-1,ct,true,false,true)
	check(de.cut_mask==0,"Cutters cannot cut remotely")
	for wire in 3:
		var tip: Vector3=de.base_pose(-1).affine_inverse()*de.bomb_pose()*Contact.WIRES[wire]
		ct.weapon=Transform3D(Basis.IDENTITY,tip+Vector3(0,0,.18));ct.left=ct.weapon
		send(-1,ct,true,false,false);send(-1,ct,true,false,true)
	check(de.phase=="post" and de.cut_mask==7 and g.match_mode.scores[1]==1,"Three spatial cutter contacts and trigger squeezes defuse")
	var stock=Stock.new();var head:=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0))
	for left_handed in [false,true]:
		var hand:=Transform3D(Basis.IDENTITY,Vector3(-.18 if left_handed else .18,1.42,-.16))
		var support:=Transform3D(Basis.IDENTITY,hand.origin+Vector3(0,0,-.33))
		for w in Stock.LONG_GUNS:
			var solved: Transform3D=stock.solve(hand,support,head,w,left_handed,true)
			check(stock.engaged and Poses.valid_transform(solved) and solved.origin==hand.origin,"Stock stabilizes slot %d with unchanged firing origin (%s hand)"%[w,"left" if left_handed else "right"])
		for w in [0,1,2,10]:check(stock.solve(hand,support,head,w,left_handed,true)==hand and not stock.engaged,"Stock bypasses knife/pistol "+str(w))
		check(stock.solve(hand,support,head,6,left_handed,false)==hand and not stock.engaged,"Offhand release/reload/tracking loss disengages stock")
		var remote:=hand;remote.origin+=Vector3(0,0,-1)
		check(stock.solve(remote,support,head,6,left_handed,true)==remote and not stock.engaged,"Stock cannot engage away from shoulder")
	var config: String="/tmp/fps-stock-"+str(OS.get_process_id())+".cfg"
	check(not Preferences.read_settings(config).virtual_stock,"Virtual stock defaults off")
	check(Preferences.save_settings({"virtual_stock":true},config)==OK and Preferences.read_settings(config).virtual_stock,"VR stock setting persists")
	var settings:=ConfigFile.new();settings.load(config);settings.set_value("vr","virtual_stock","invalid");settings.save(config)
	check(not Preferences.read_settings(config).virtual_stock,"Malformed stock preference safely defaults off")
	DirAccess.remove_absolute(config)
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/vr.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_VR_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
