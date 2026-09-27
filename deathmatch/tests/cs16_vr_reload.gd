extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
const Models=preload("res://deathmatch/counterstrike/models.gd")
var g
var cs
var seq:=0
var checks:=0
var failures: Array=[]
var pose: Dictionary
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func prepare(w: int,left: bool=false):
	g.clock+=5;g.armory.select("cs16");g.variant_combat.reset();g.intermission=0
	var s: Dictionary=g.players[1]
	s.merge({"weapon":w,"owned":range(12),"ammo":[240,64,300,40],"hp":100,"dead":false,"spectator":false,"invulnerable":0,"cooldown":0.0,"fire":false,"held":false,"alt_fire":false,"reload":false,"reload_grip":false,"input_blocked":false,"last_input":g.clock,"vr_device":true},true)
	pose=Poses.neutral();pose.left_handed=left;pose.weapon=Transform3D(Basis.IDENTITY,Vector3(-.3 if left else .3,1.1,-.3));pose["left" if left else "right"]=pose.weapon
	step(Reload.pouch(pose).origin,false)
func step(hand: Vector3,grip: bool=false,eject: bool=false,dt: float=.06,blocked: bool=false,basis: Basis=Basis.IDENTITY):
	g.clock+=dt;seq+=1;var s: Dictionary=g.players[1]
	s.cooldown=maxf(0,s.cooldown-dt);s.held=false
	pose["right" if pose.left_handed else "left"]=Transform3D(basis,hand);pose.offhand_weapon=pose["right" if pose.left_handed else "left"]
	g._accept_input(1,{"seq":seq,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false,"reload":eject,"reload_grip":grip,"input_blocked":blocked,"xr":pose})
	cs.tick_input(1,dt)
func point(local: Vector3) -> Vector3:return Reload.model_pose(pose,g.players[1].weapon)*local
func magazine():
	var bag:=Reload.pouch(pose).origin
	step(bag);step(bag,true)
	check(cs.physical(1).carry==1,"Pouch supplies a held magazine only after ejection")
	step(point(Reload.MAG_POINTS[g.players[1].weapon]),true,false,.20)
	step(point(Reload.MAG_POINTS[g.players[1].weapon]))
func cycle():
	var w: int=g.players[1].weapon;var local: Vector3=Reload.RACK_POINTS[w]
	step(point(local));step(point(local),true)
	var stroke:=.105 if w==3 else .10 if w==9 else .065
	step(point(local+Vector3.BACK*stroke),true,false,.12)
	if Reload.manual_cycle(w):step(point(local),true,false,.12)
	else:step(point(local+Vector3.BACK*stroke),false)
	step(point(local))
func cover(amount: float):
	step(point(Reload.cover_point(cs.physical(1).cover)))
	step(point(Reload.cover_point(cs.physical(1).cover)),true)
	step(point(Reload.cover_point(amount)),true,false,.15)
	step(point(Reload.cover_point(amount)))
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("VR reload tests",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	for w in [1,2,5,6,7,9,10,11]:
		prepare(w,w%2==0);var before: Array=g.players[1].ammo.duplicate();var cap: int=g.armory.data(w).magazine
		step(Reload.pouch(pose).origin,true)
		check(cs.physical(1).carry==0,Models.NAMES[w]+" cannot draw a second magazine while one is seated")
		step(Reload.pouch(pose).origin,false,true)
		check(not cs.physical(1).mag and cs.state(1).clips[w]==0 and not cs.shoot(1),Models.NAMES[w]+" ejection removes the magazine and blocks firing")
		check(not cs.begin_reload(1),Models.NAMES[w]+" VR cannot invoke the timed desktop reload")
		step(Reload.pouch(pose).origin,false,false,5)
		check(cs.state(1).clips[w]==0,Models.NAMES[w]+" waiting cannot refill an ejected weapon")
		magazine()
		check(cs.physical(1).mag and cs.state(1).clips[w]==cap and not cs.physical(1).ready and not cs.shoot(1),Models.NAMES[w]+" inserted magazine still requires chambering")
		cycle()
		check(cs.physical(1).ready and g.players[1].ammo==before,Models.NAMES[w]+" offhand rack chambers without creating ammo")
		check(cs.shoot(1),Models.NAMES[w]+" fires after the physical reload")
	prepare(3);check(cs.shoot(1),"Loaded M3 fires its first shell")
	step(point(Reload.RACK_POINTS[3]),false,false,1)
	check(not cs.shoot(1) and not cs.physical(1).ready,"M3 cannot fire again just by waiting")
	step(point(Reload.RACK_POINTS[3]),true)
	step(point(Reload.RACK_POINTS[3]+Vector3.BACK*.105),true,false,.12)
	check(not cs.shoot(1),"M3 back stroke alone does not chamber")
	step(point(Reload.RACK_POINTS[3]+Vector3.BACK*.105),false)
	check(not cs.physical(1).ready,"Releasing the pump does not substitute for the forward stroke")
	cycle();check(cs.physical(1).ready and cs.shoot(1),"Full offhand pump cycle enables the next M3 shot")
	prepare(3);step(point(Reload.RACK_POINTS[3]),true);cs.shoot(1)
	step(point(Reload.RACK_POINTS[3]),true)
	step(point(Reload.RACK_POINTS[3]+Vector3.BACK*.105),true,false,.12);step(point(Reload.RACK_POINTS[3]),true,false,.12)
	check(cs.physical(1).ready,"M3 fore-end held during the shot can pump without re-gripping")
	prepare(9);cs.shoot(1);step(point(Reload.RACK_POINTS[9]),false,false,2)
	check(not cs.shoot(1),"AWP bolt must also be manually cycled after each VR shot")
	cycle();check(cs.shoot(1),"Manual AWP bolt cycle enables next round")
	for w in [3,4]:
		prepare(w);cs.state(1).clips[w]=0;cs.physical(1).ready=false
		var total: Array=g.players[1].ammo.duplicate();var bag:=Reload.pouch(pose).origin
		step(bag,true);check(cs.physical(1).carry==2,"Tube shotgun pouch supplies one shell")
		step(point(Reload.MAG_POINTS[w]),true,false,.20);step(point(Reload.MAG_POINTS[w]))
		check(cs.state(1).clips[w]==1 and g.players[1].ammo==total and not cs.shoot(1),"One inserted shell requires chambering without creating ammo")
		cycle();check(cs.shoot(1),"Tube shotgun fires after shell insertion and its correct manual action")
	prepare(8);var total: Array=g.players[1].ammo.duplicate()
	step(point(Reload.COVER_POINT),false,true)
	check(cs.physical(1).mag,"Closed M249 feed cover prevents box replacement")
	cover(1);check(cs.physical(1).cover>.9 and not cs.shoot(1),"Lifting M249 feed cover opens the tray and blocks fire")
	step(point(Reload.cover_point(1)),false,true)
	check(not cs.physical(1).mag,"M249 box ejects with its feed cover open")
	magazine();check(cs.state(1).clips[8]==100 and cs.physical(1).cover>.9,"New ammo box seats through the open feed tray")
	cycle();check(not cs.physical(1).ready,"M249 cannot chamber with its cover open")
	cover(0);check(cs.physical(1).cover<.05 and not cs.shoot(1),"Closing feed cover still requires charging handle")
	cycle();check(g.players[1].ammo==total and cs.shoot(1),"Closed and charged M249 fires without duplicated ammo")
	prepare(6);step(Reload.pouch(pose).origin,false,true);step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	step(point(Reload.MAG_POINTS[6]),true,false,.20,true)
	check(not cs.physical(1).mag and cs.physical(1).carry==0,"Opening a menu cancels a carried magazine without inserting it")
	g.players[1].weapon=7;cs.state(1);g.players[1].weapon=6
	check(not cs.physical(1).mag and cs.state(1).clips[6]==0,"Holstering cannot restore an ejected magazine")
	prepare(7);step(Reload.pouch(pose).origin,false,true);g.players[1].ammo[2]=0;step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	check(cs.physical(1).carry==0,"Empty reserve cannot produce a magazine")
	prepare(7);step(Reload.pouch(pose).origin,false,true);step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	step(point(Reload.MAG_POINTS[7]),true,false,.2,false,Basis(Vector3.RIGHT,PI))
	check(cs.state(1).clips[7]==0 and cs.physical(1).carry==1,"An upside-down magazine cannot seat")
	step(point(Reload.MAG_POINTS[7]))
	check(cs.state(1).clips[7]==0 and cs.physical(1).carry==0,"Letting go of an unseated magazine cannot grant ammunition")
	step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true);g.clock+=.4;cs.tick_input(1,.4)
	check(cs.physical(1).carry==0 and cs.state(1).clips[7]==0,"Stale network input cancels an unfinished reload")
	prepare(2);step(Reload.pouch(pose).origin,false,true);magazine()
	step(point(Reload.RACK_POINTS[2]),true);step(point(Reload.RACK_POINTS[2]+Vector3.BACK*.03),true,false,.12);step(point(Reload.RACK_POINTS[2]+Vector3.BACK*.03))
	check(not cs.physical(1).ready,"Short slide tug cannot chamber a round")
	prepare(2);cs.state(1).clips[2]=1;cs.shoot(1)
	check(cs.physical(1).locked,"Last pistol shot locks the slide")
	step(Reload.pouch(pose).origin,false,true);magazine()
	check(cs.physical(1).locked and not cs.physical(1).ready,"Fresh magazine does not release an empty pistol's slide")
	cycle();check(not cs.physical(1).locked and cs.physical(1).ready,"Offhand racking releases the slide and chambers")
	prepare(6);step(Reload.pouch(pose).origin,false,true);step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	pose.erase("offhand_weapon");g.players[1].xr=Poses.validate(pose);cs.tick_input(1,.02)
	check(cs.physical(1).carry==0 and not cs.physical(1).mag,"Offhand tracking loss cancels carried ammo")
	step(point(Reload.MAG_POINTS[6]),true,false,.2)
	check(cs.state(1).clips[6]==0,"Tracking recovery with grip held cannot insert stale ammo")
	prepare(2);step(Reload.pouch(pose).origin,false,true);magazine()
	step(point(Reload.RACK_POINTS[2]),true);step(point(Reload.RACK_POINTS[2]+Vector3.BACK*.065),true,false,.01);step(point(Reload.RACK_POINTS[2]),false,false,.01)
	check(not cs.physical(1).ready,"Instantaneous controller jump cannot complete a rack")
	step(point(Reload.RACK_POINTS[2]));step(point(Reload.RACK_POINTS[2]),true)
	g.players[1].xr={};cs.tick_input(1,.02)
	check(cs.physical(1).grab.is_empty() and not cs.physical(1).ready,"Invalid tracking cancels an unfinished rack")
	prepare(7);step(Reload.pouch(pose).origin,false,true);step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	pose.left_handed=true;step(point(Reload.MAG_POINTS[7]),true,false,.2)
	check(cs.physical(1).carry==0 and cs.state(1).clips[7]==0,"Changing gun hand cannot complete an in-flight insertion")
	prepare(6);pose.head.origin.y=1.05;pose.head.basis=Basis(Vector3.UP,.7)
	pose.weapon=Transform3D(Basis.from_euler(Vector3(.3,.5,.1)),Vector3(.25,.85,-.3));pose.right=pose.weapon
	step(Reload.pouch(pose).origin,false,true);magazine();cycle()
	check(cs.physical(1).ready,"Seated-height pouch and tilted weapon retain working interaction coordinates")
	cycle();var snapshot: Dictionary=cs.snapshot();cs.receive(snapshot)
	check(cs.view[1].size()==9 and cs.view[1][5]&Reload.CHAMBERED,"Physical state survives snapshot validation")
	var bad: Array=snapshot[1].duplicate();bad[6]=101;cs.receive({1:bad});check(cs.view.is_empty(),"Out-of-range action progress is rejected")
	g.players[1].serial+=1;check(cs.physical(1).mag and cs.physical(1).ready,"New life starts with a seated and chambered spawn weapon")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/vr-reload.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_VR_RELOAD_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
