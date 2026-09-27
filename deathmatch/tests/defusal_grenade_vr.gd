extends SceneTree
class TestBindings extends "res://deathmatch/settings/bindings.gd":
	var inputs: Dictionary={}
	func vr_pressed(_rig: Node,action: String) -> bool:return inputs.get(action,false)
var g
var de
var rig
var b
var seq:=100
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frame():
	g.clock+=.02;g.players[1].last_input=g.clock
	rig._process(.02);seq+=1;g._accept_input(1,rig.command(seq));de.sample_player(1)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("DE tracked grenades",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	if not is_instance_valid(g.hud):g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0);de.carrier=0;g.menu_open=false;g.local_yaw=0
	g.fighters[1].position=de.starts[0][0];g.players[1].yaw=0.0;g.players[1].input_blocked=false;g.players[1].last_input=g.clock
	b=TestBindings.new();g.bindings=b;b.physical_interactions=true
	var u=de.utility
	for left in [false,true]:
		rig.left_handed=left;rig.head.position=Vector3(0,1.65,0)
		var hand=rig.right if left else rig.left
		hand.position=Vector3(.3 if left else -.3,1.8,.15)
		u.cancel(1);u.state(1).counts=[1,2,1];u.state(1).cooldown=0;b.inputs={};frame();frame()
		b.inputs={"support":true,"offhand_fire":true};frame()
		check(rig.physical_actions.gesture.held and u.state(1).primed and u.state(1).offhand,"TF-style shoulder chord arms offhand grenade, left="+str(left))
		check(is_instance_valid(rig.physical_actions.grenade) and rig.physical_actions.grenade.visible,"Held model and throw guide shown, left="+str(left))
		check(not rig.command(seq+1).fire and not rig.command(seq+1).offhand_fire,"Held utility blocks both gun triggers")
		for i in 7:hand.position.z-=.06;frame()
		b.inputs={"offhand_fire":true};frame()
		check(u.flying.size()==1 and u.state(1).counts[0]==0,"Swing and grip release emits exactly one purchased HE")
		if not u.flying.is_empty():check(u.flying.values()[0].velocity.z<-3 and u.flying.values()[0].velocity.length()<=26.001,"TF throw boost preserves bounded offhand motion")
		check(not rig.physical_actions.grenade.visible,"Released local model hides")
		u.flying.clear();u.state(1).cooldown=0;b.inputs={};frame();u.equip(1,2)
		b.inputs={"support":true,"offhand_fire":true};frame();check(u.state(1).selected==2 and u.state(1).offhand,"Wheel-selected smoke uses same offhand gesture")
		g.menu_open=true;frame();check(u.selected(1)==-1 and u.state(1).counts[2]==1 and not rig.physical_actions.gesture.held,"Menu cancels offhand grenade without consuming it")
		g.menu_open=false;frame();check(not u.state(1).primed,"Closing menu with chord held cannot rearm")
		b.inputs={};frame();u.state(1).counts=[0,0,0];b.inputs={"support":true,"offhand_fire":true};frame()
		check(not rig.physical_actions.gesture.held and u.selected(1)==-1,"Empty utility rejects physical arm immediately")
	b.inputs={};frame();u.state(1).counts=[1,0,0];u.state(1).cooldown=0
	var rpc=g.match_mode.fortress.physical;var pose: Dictionary=rig.sample_pose();var sequence: int=rig.physical_actions.sequence+100
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial-1,sequence,"arm",pose,Vector3.ZERO),"Stale life rejects DE physical arm")
	check(rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence,"arm",pose,Vector3.ZERO),"Fresh physical arm accepted")
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence,"throw",pose,Vector3.ZERO),"Duplicate physical sequence cannot throw")
	check(not rpc.request_for(1,g.map_epoch,g.players[1].serial,sequence+1,"throw",pose,Vector3(NAN,0,0)) and u.selected(1)==-1,"Nonfinite stroke cancels held equipment")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/classic-de/grenade-vr.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("DE_GRENADE_VR_RESULT ",JSON.stringify(result))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
