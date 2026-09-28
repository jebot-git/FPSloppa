extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Equipment=preload("res://deathmatch/tribes/equipment.gd")
class Rig extends Node3D:
	var game
	var support_aim={"engaged":false}
class Actions extends RefCounted:
	var rig
	var gesture={"held":false}
	var sent: Array=[]
	func send(kind: String,_pose: Dictionary,velocity:=Vector3.ZERO):sent.append({"kind":kind,"velocity":velocity})
var g
var checks:=0
var failures: Array=[]
var sequence:=100
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func request(kind: String,pose: Dictionary,velocity:=Vector3.ZERO) -> bool:
	sequence+=1
	return g.match_mode.fortress.physical.request_for(1,g.map_epoch,g.players[1].serial,sequence,kind,pose,velocity)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("ST VR reliability",0,100,30,true,"st")
	g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(60,1,60))
	var rules=g.match_mode.tribes;var s: Dictionary=g.players[1];var actor=g.fighters[1]
	rules.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(30,2,30),Vector3(60,40,60))
	actor.position=Fixture.ORIGIN;actor.velocity=Vector3.ZERO;s.team=0;s.physical=true;s.input_blocked=false;s.yaw=0
	await physics_frame;await physics_frame
	for left in [false,true]:
		rules.combat.cancel(1);rules.deployables.reset();await physics_frame;rules.apply_equipment(1,"light",[3,2,0],"camera")
		var pose:=Poses.neutral();pose.left_handed=left;pose.weapon=pose.left if left else pose.right
		pose.body={"hips":Transform3D(Basis(Vector3.UP,.3),Vector3(.08,.95,.05))};pose.head.origin=Vector3(.1,1.6,-.12)
		var hand: String="right" if left else "left";pose[hand]=Equipment.mount(pose,"pack")
		check(request("hold_pack",pose),"Tracked chest pack grab, handedness "+str(left))
		pose[hand]=Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(.3,1.2,-.5))
		check(not request("activate",pose) and s.tribes_pack=="camera" and not rules.combat.held[1].used,"Invalid placement preserves unused held pack "+str(left))
		pose[hand].basis=Basis(Vector3.RIGHT,-PI/4)
		check(request("activate",pose) and s.tribes_pack=="none" and rules.deployables.rows.size()==1,"Correcting aim retries without another grab "+str(left))
		check(not request("activate",pose) and rules.deployables.rows.size()==1,"Held trigger/replayed activation cannot duplicate deployment "+str(left))
		request("cancel",pose);rules.apply_equipment(1,"light",[3,2,0],"ammo");pose[hand]=Equipment.mount(pose,"pack")
		check(request("hold_pack",pose),"Grab transfer pack "+str(left))
		var wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,1.1,-.6),Vector3(2,2,.16));await physics_frame
		pose[hand].origin=Vector3(0,1.2,-.9);var before: int=rules.recovery.rows.size()
		check(not request("transfer",pose,Vector3(0,0,-3)) and s.tribes_pack=="ammo" and rules.recovery.rows.size()==before,"Cannot transfer equipment through a wall "+str(left))
		wall.free();await physics_frame
		pose[hand]=Equipment.mount(pose,"pack");check(request("hold_pack",pose) and request("transfer",pose,Vector3.RIGHT),"Clear transfer still works after blocked release "+str(left))
		check(not request("transfer",pose),"Transfer consumes one authoritative held item "+str(left))
	# Exercise actual client grip state/motion rather than assigning item flags.
	var rig:=Rig.new();rig.game=g;g.add_child(rig);var actions:=Actions.new();actions.rig=rig
	var equipment=preload("res://deathmatch/vr/tribes_equipment.gd").new();equipment.setup(actions)
	for left in [false,true]:
		g.match_mode.flags[1].carrier=1;var pose:=Poses.neutral();pose.left_handed=left
		var hand: String="right" if left else "left";pose[hand]=Equipment.mount(pose,"flag")
		equipment.reset();actions.sent.clear();equipment.update(.02,true,pose,false,false);equipment.update(.02,true,pose,true,false)
		check(equipment.item=="flag" and actions.sent.back().kind=="hold_flag","Client grip claims chest flag "+str(left))
		actor.velocity=Vector3(40,0,0)
		for i in 10:equipment.update(.02,true,pose,true,false)
		equipment.update(.02,true,pose,false,false)
		check(actions.sent.back().kind=="cancel","Releasing a stationary hand while skiing does not throw flag "+str(left))
		equipment.update(.02,true,pose,true,false)
		for i in 5:pose[hand].origin.z-=.06;equipment.update(.02,true,pose,true,false)
		equipment.update(.02,true,pose,false,false)
		check(actions.sent.back().kind=="throw" and actions.sent.back().velocity.length()>1.2,"Deliberate hand swing releases flag pass "+str(left))
		pose[hand]=Equipment.mount(pose,"flag");equipment.update(.02,true,pose,true,false)
		for i in 480:equipment.update(.02,true,pose,true,false)
		check(equipment.item.is_empty() and actions.sent.back().kind=="cancel","Local held item expires before authority lease "+str(left))
		equipment.reset();check(equipment.motion.velocity==Vector3.ZERO,"Reset discards stale swing velocity "+str(left))
	var reply=preload("res://deathmatch/vr/physical_actions.gd").new();reply.equipment.item="pack";reply.equipment.used=true
	reply.reply(reply.sequence,"activate",false)
	check(reply.equipment.item=="pack" and not reply.equipment.used,"Rejected placement reply releases trigger latch while retaining pack")
	rig.free();var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/st-raindance/vr-reliability.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ST_VR_RELIABILITY ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
