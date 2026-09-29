extends SceneTree
const Motion=preload("res://deathmatch/vehicles/tribes/render_motion.gd")
const Data=preload("res://deathmatch/vehicles/tribes/scout_data.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func curve(t: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,t*.3)*Basis(Vector3.RIGHT,sin(t)*.1)*Basis(Vector3.FORWARD,sin(t*2)*.2),Vector3(t*25,10+sin(t),-t*5))
func interpolation_cases():
	for hz in [72,90,120,144]:
		var m=Motion.new();var maximum:=0.0;var last: Vector3=Vector3.ZERO;var max_step:=0.0
		# Populate a fresh two-tick bracket per render sample, as a 60 Hz host does.
		for f in 2*hz:
			var now: float=float(f)/hz;var tick: int=floori(now*60)
			m.push(1,float(tick)/60,curve(float(tick)/60));m.push(1,float(tick+1)/60,curve(float(tick+1)/60))
			var pose: Transform3D=m.sample(1,now,Transform3D.IDENTITY)
			maximum=maxf(maximum,pose.origin.distance_to(curve(now).origin))
			if f>0:max_step=maxf(max_step,pose.origin.distance_to(last))
			last=pose.origin
		check(maximum<.001 and max_step<26.0/hz,"60 Hz host motion remains smooth at %d Hz rendering"%hz)
		check(m.tracks[1].size()<=Motion.HISTORY,"Render history stays bounded at %d Hz"%hz)
	var m=Motion.new();var next:=0;var now:=0.0;var previous:=0.0;var max_jump:=0.0;var monotonic:=true
	for f in 720:
		now=float(f)/120
		while next<=120 and next*.05+([.01,.03,.015,.02][next%4])<=now:
			var stamp: float=next*.05;m.push(1,stamp,Transform3D(Basis.IDENTITY,Vector3(stamp*25,0,0)));m.received(stamp,now);next+=1
		var pose: Transform3D=m.sample(1,m.advance(now),Transform3D.IDENTITY)
		if f>30:max_jump=maxf(max_jump,pose.origin.x-previous)
		monotonic=monotonic and pose.origin.x>=previous-.0001
		previous=pose.origin.x
	check(monotonic,"Jittered snapshots never move backwards")
	check(max_jump<.5,"Jittered 20 Hz network updates do not step by an entire packet")
	var stopped: Transform3D=m.sample(1,100,Transform3D.IDENTITY)
	check(stopped.origin.x<=next*.05*25,"Packet loss holds last hull position without tunnelling")
	m.push(1,7,Transform3D(Basis.IDENTITY,Vector3(1000,0,0)))
	check(m.tracks[1].size()==1 and m.sample(1,6,Transform3D.IDENTITY).origin.x==1000,"Teleport resets visual history instead of sweeping through map")
func run():
	interpolation_cases()
	root.title="Transport VR controls and smoothing";root.size=Vector2i(1000,700);root.position=Vector2i(6000,6000)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance";g.start_host("Transport VR",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);var rules=g.match_mode.tribes;rules.set_process(false)
	var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.focused=true;rig.blackout.hide();rig.head.position=Vector3(0,1.65,0)
	var left:=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	var right:=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	var c=rules.vehicles;var pads=rules.stations();var s: Dictionary=g.players[1];var actor=g.fighters[1];s.team=0;s.input_blocked=false;s.dead=false;s.spectator=false
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200))
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	await process_frame;await physics_frame
	for kind in ["lpc","hpc"]:
		c.reset();rules.energy[0]=20000;g.clock+=4;actor.position=pads.rows[index].position;actor.velocity=Vector3.ZERO;rules.apply_equipment(1,"light",[3,2,0],"energy");s.input_blocked=false
		await physics_frame
		check(c.purchase(1,g.map_epoch,s.serial,kind),kind+" purchased for real control-path test")
		if c.rows.is_empty():continue
		var key: int=c.rows.keys()[0];var row: Dictionary=c.rows[key];g.clock+=4
		row.position=Fixture.ORIGIN+Vector3.UP*5;row.velocity=Vector3.ZERO;c.bodies[key].position=row.position
		actor.position=c.seat_position(row,0)+Vector3(0,0,1)
		await physics_frame
		check(c.board(1,key,0),kind+" pilot boards")
		for mirrored in [false,true]:
			rig.left_controls=mirrored;rig.left_handed=mirrored
			var move=right if mirrored else left;var turn=left if mirrored else right
			move.set_input("primary",Vector2(.4,.7));turn.set_input("primary",Vector2(0,1))
			g.sequence+=1;var cmd: Dictionary=g._local_command()
			check(cmd.fly==1 and cmd.pitch==0 and not cmd.jetpack and cmd.move.is_equal_approx(Vector2(.4,-.7)),kind+" lift uses turn Y, preserving thrust/strafe (%s)"%mirrored)
			g._accept_input(1,cmd);var control: Dictionary=Data.controls(s)
			check(control.lift_axis and control.lift==1 and not control.jet,kind+" lift survives authoritative input validation (%s)"%mirrored)
			turn.set_input("primary",Vector2(0,-1));cmd=g._local_command();check(cmd.fly==-1,kind+" down commands landing (%s)"%mirrored)
			turn.set_input("primary",Vector2(0,.1));cmd=g._local_command();check(cmd.fly==0,kind+" deadzone holds altitude (%s)"%mirrored)
			turn.set_input("primary",Vector2(0,1));g.menu_open=true;cmd=g._local_command();check(cmd.fly==0 and cmd.input_blocked,kind+" menus suppress lift (%s)"%mirrored);g.menu_open=false
		# Real swept physics driven by the same validated analog channel.
		s.move=Vector2.ZERO;s.fly=1;s.vr_device=true;s.input_blocked=false;s.jet_held=false;s.pitch=0;s.yaw=row.yaw
		var start: float=row.position.y
		for tick in 120:g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(row.position.y>start+5,kind+" stick alone raises craft without held jet button")
		s.fly=0
		for tick in 120:g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		var hover: float=row.position.y
		for tick in 60:g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(absf(row.position.y-hover)<.01,kind+" centered stick holds altitude")
		s.fly=-1
		for tick in 240:g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(row.position.y<Fixture.ORIGIN.y+1 and row.position.y>=Fixture.ORIGIN.y and c.rows.has(key),kind+" down stick lands on collision floor without destroying hull")
		# Observe actual hull + camera frame, including bank/pitch and stale stair offsets.
		row.position=Fixture.ORIGIN+Vector3(3,8,0);row.pitch=.1;row.bank=.2;c.pin(key);c.render_motion.clear();c.render_frames.clear();c.render_frame_number=-1
		c.render_motion.push(key,g.clock-1,Transform3D(Basis.IDENTITY,row.position-Vector3.RIGHT*4));c.render_motion.push(key,g.clock,c.seat_frame(row))
		actor.view_offset=.4;actor.previous_view_offset=.3;actor.prediction_view_offset=Vector3(1,0,0)
		var physical: Vector3=actor.position;c.update(.016)
		var deck: Transform3D=c.view.nodes[key].global_transform
		check(actor.render_position().is_equal_approx(deck*c.definition(row).seats[0]),kind+" local camera seat exactly matches rendered hull")
		check(actor.avatar.global_position.is_equal_approx(actor.render_position()),kind+" fallback avatar shares deck frame without moving collider")
		check(actor.render_view_offset()==0 and actor.position==physical,kind+" render smoothing ignores stair residue and leaves physics untouched")
		check(not c.view.nodes[key].is_physics_interpolated_and_enabled(),kind+" hull avoids a second engine interpolation pass")
		# Same frozen frame even if another consumer queries after authority changes.
		row.position+=Vector3.RIGHT;c.pin(key);c.update(.016)
		check(actor.render_position().is_equal_approx(c.view.nodes[key].global_transform*c.definition(row).seats[0]),kind+" render consumers share one frame regardless of processing order")
		c.leave(1,true);check(not actor.render_mount.is_valid() and actor.mounted_visuals.is_empty() and actor.avatar.position==Vector3.ZERO,kind+" ejection clears render and visual attachments")
		actor.view_offset=0;actor.previous_view_offset=0
	# All VR vehicles use stick lift; desktop retains its previous flight controls.
	var base:={"kind":"scout","position":Vector3.ZERO,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":0.0,"bank":0.0}
	Data.advance(base,Data.controls({"vr_device":true,"fly":-1.0,"jetpack":true}),0,.1)
	check(base.velocity.y<0,"Scout down stick overrides held jet button")
	base.kind="lpc";base.velocity=Vector3.ZERO;Data.advance(base,Data.controls({"jetpack":true}),0,.1)
	check(base.velocity.y>0,"Desktop transports keep jet-button lift")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	c.reset();g.disconnect_game();g.free();print("ST_TRANSPORT_VR ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
