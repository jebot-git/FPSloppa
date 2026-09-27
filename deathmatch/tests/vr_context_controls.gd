extends "res://deathmatch/tests/defusal_grenade_vr.gd"
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class ContextBindings extends "res://deathmatch/settings/bindings.gd":
	var inputs: Dictionary={}
	var turn:=Vector2.ZERO
	func vr_pressed(_rig: Node,action: String) -> bool:return inputs.get(action,false)
	func axis(_rig: Node,action: String) -> Vector2:return turn if action=="turn" else Vector2.ZERO
func step(inputs: Dictionary={},turn: float=0.0):
	b.inputs=inputs;b.turn=Vector2(0,turn);g.clock+=.3
	rig._process(.02)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("VR contextual controls",0,100,60,true,"de");g.bots.free();g.bots=null
	g.bot_population.target=0;g.bot_population.count_target=0;g.set_process(false);g.set_physics_process(false)
	Fixture.setup(g);await physics_frame;await physics_frame
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	rig.head.position=Vector3(0,1.65,0);rig.origin_offset=Vector3.ZERO;g.fighters[1].position=Fixture.point()
	de=g.match_mode.defusal;de.clear_bomb();de.phase="live";de.phase_end=g.clock+7200;g.menu_open=false
	g.players[1].merge({"owned":range(12),"ammo":[240,64,300,40],"weapon":6,"dead":false,"spectator":false,"team":0},true);g.desired_weapon=6
	b=ContextBindings.new();g.bindings=b;step()
	check(b.vr.ability==b.vr.reload and b.vr.jetpack==b.vr.reload,"TF ability and jetpack default to the reload button")
	var u=de.utility;u.state(1).counts=[1,2,1]
	step({},1);check(u.state(1).shoulder==0 and g.desired_weapon==6 and u.selected(1)==-1 and not de.gun_holstered(1),"Turn-stick up selects shoulder HE while preserving the gun")
	step({},1);check(u.state(1).shoulder==0,"Held stick makes one selection")
	step();step({},1);check(u.state(1).shoulder==1,"Fresh up selects flash")
	step();step({},-1);check(u.state(1).shoulder==0,"Down selects the previous grenade")
	u.state(1).counts=[1,0,1];step();step({},1);check(u.state(1).shoulder==2,"Grenade cycle skips empty inventory")
	step();step({},1);check(u.state(1).shoulder==0,"Grenade cycle wraps")
	u.state(1).primed=true;step();step({},1);check(u.state(1).shoulder==0 and u.state(1).primed,"Stick cannot cancel or replace a primed grenade")
	u.cancel(1);u.state(1).shoulder=-1;u.state(1).counts=[0,0,0];step();step({},1);check(u.state(1).shoulder==-1 and g.desired_weapon==6,"Empty utility does not cycle CS guns")
	u.state(1).counts=[1,2,1];step();g.menu_open=true;step({},1);g.menu_open=false;step({},1)
	check(u.state(1).shoulder==-1,"Closing menu with stick held does not select a grenade")
	step();rig.focused=false;step({},-1);rig.focused=true;step({},-1)
	check(u.state(1).shoulder==-1,"Focus return with held stick does not select equipment")
	step();rig.weapon_wheel.toggle(Vector2.ZERO);step({},1)
	check(u.state(1).shoulder==-1,"Weapon wheel owns the selection stick")
	rig.weapon_wheel.close();step({},1);check(u.state(1).shoulder==-1,"Closing the wheel does not leak a held stick selection")
	step();g.players[1].dead=true;step({},1);check(u.state(1).shoulder==-1,"Dead players cannot cycle utility");g.players[1].dead=false
	step();g.players[1].spectator=true;step({},1);check(u.state(1).shoulder==-1,"Spectators retain flight controls without equipment cycling");g.players[1].spectator=false
	step();step({},-1);check(u.state(1).shoulder==2,"Down from a holstered grenade selects the last owned type")
	u.cancel(1)
	g.match_mode.kind="tf";g.armory.apply_mode();g.players[1].tf_next="engineer";g._spawn(1);g.fighters[1].position=Fixture.point()
	g.players[1].tf_next="medic";var tf=g.match_mode.fortress;var gun: int=g.desired_weapon
	step();step({},1)
	check(g.players[1].tf_tool=="dispenser" and g.players[1].tf_next=="medic" and g.desired_weapon==gun,"Engineer stick selects dispenser without changing queued class or gun")
	check("DISPENSER" in tf.ability_state(1).label,"HUD names the selected deployable")
	step();step({},-1);check(g.players[1].tf_tool=="sentry","Engineer down selects sentry")
	g.players[1].tf_next="heavy";g._spawn(1);g.fighters[1].position=Fixture.point();tf.cooldowns[1]=0
	step();step({"ability":true})
	check(tf.effects.get(1,{}).get("kind","")=="heavy","Reload-button ability activates authoritative TF brace")
	tf.effects.clear();tf.cooldowns[1]=0;step({"ability":true})
	check(not tf.effects.has(1),"Held ability button does not repeat")
	step();g.menu_open=true;step({"ability":true});g.menu_open=false;step({"ability":true})
	check(not tf.effects.has(1),"Menu press cannot activate an ability after closing")
	step();b.physical_interactions=false;step({"ability":true})
	check(tf.effects.has(1),"Ability button also works when physical gestures are disabled")
	b.physical_interactions=true
	g.match_mode.kind="dm";g.match_mode.jetpacks=true;g.armory.select("cs16");g._spawn(1);g.fighters[1].position=Fixture.point()
	g.players[1].weapon=2;g.desired_weapon=2;g.jetpacks.collect(1);step({"reload":true,"jetpack":true,"ability":true})
	var command: Dictionary=rig.command(100)
	check(command.reload and not command.jetpack,"Shared CS A/X remains magazine release even with an owned jetpack")
	b.vr.jetpack="turn:by_button";command=rig.command(101)
	check(command.jetpack,"A separately rebound jetpack button works alongside CS reload")
	for left in [false,true]:
		rig.left_handed=left;g.players[1].weapon=0;g.desired_weapon=0
		var hand=rig.left if left else rig.right;var aim=rig.left_aim if left else rig.right_aim
		hand.transform=Transform3D(Basis(Vector3.RIGHT,.7),Vector3(-.2 if left else .2,1.2,-.4));aim.transform=Transform3D(Basis(Vector3.RIGHT,-.4),hand.position)
		var knife: Transform3D=rig.weapon_pose()
		check(knife.is_equal_approx(hand.transform),"Knife rotates with the grip instead of the pistol aim frame, left="+str(left))
		var model: Transform3D=preload("res://deathmatch/art.gd").held_transform(knife,0,.65,"cs16")
		check((model*preload("res://deathmatch/counterstrike/models.gd").grip(0)).distance_to(hand.position)<.001,"Rotating the knife preserves its palm anchor")
	rig.left_handed=false
	b.vr.jetpack=b.VR.jetpack;g.armory.select("doom");g._spawn(1);g.fighters[1].position=Fixture.point();g.jetpacks.collect(1)
	step();g._physics_process(.016);step({"jetpack":true});g._physics_process(.016)
	check(g.fighters[1].jetpack_state.activation==1 and g.fighters[1].jetpack_state.mode==2,"Host physics accepts one dedicated jetpack press without a jump")
	check(not g.players[1].jump,"Dedicated jetpack press does not synthesize a jump")
	var activation: int=g.fighters[1].jetpack_state.activation
	for i in 5:g._physics_process(.016)
	check(g.fighters[1].jetpack_state.activation==activation,"Host consumes repeated jetpack input once")
	step();g.players[1].jetpack=false;g.fighters[1].reset_jetpack();step({"jetpack":true});g._physics_process(.016)
	check(g.fighters[1].jetpack_state.activation==0,"A button cannot grant an unowned jetpack")
	step();g.players[1].owned=[2,3];g.desired_weapon=2;step({},1)
	check(g.desired_weapon==3,"Other loadouts retain turn-stick weapon cycling")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/rec-feedback/controls.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("VR_CONTEXT_RESULT ",JSON.stringify(result))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
