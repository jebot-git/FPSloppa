extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Gait=preload("res://deathmatch/avatars/locomotion.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
var checks:=0
var game
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var fallback=preload("res://deathmatch/art.gd").marine(Color.WHITE)
	root.add_child(fallback)
	for frame in 30:fallback.animate(1.0/60,Vector3(0,5,-5),"stand",1.65,false,{},false)
	check(fallback.get_node("LeftBoot").position.y>.25 and fallback.get_node("LeftThigh").transform.is_finite(),"Fallback marine also tucks articulated legs during jumps")
	for frame in 30:fallback.animate(1.0/60,Vector3.FORWARD,"prone",.65,true,{},false)
	check(fallback.get_node("Upper").rotation.x< -1 and fallback.get_node("LeftBoot").position.z>.7,"Fallback marine lies down and extends crawling legs")
	fallback.free()
	for speed in [3.0,9.4]:
		for index in 8:
			var gait:=Gait.new();var v: Vector3=Vector3(sin(index*PI/4),0,-cos(index*PI/4))*speed
			for frame in 60:gait.update(1.0/60,v,"stand",true,{},false)
			check(gait.direction_name==Gait.DIRECTIONS[index] and gait.gait_name==("run" if speed>6 else "walk"),"Directional gait %s speed %.1f"%[Gait.DIRECTIONS[index],speed])
			check(gait.offsets.left.is_finite() and gait.offsets.right.is_finite() and gait.offsets.left.distance_to(gait.offsets.right)>.05,"Alternating finite feet "+Gait.DIRECTIONS[index])
	var gait:=Gait.new()
	for frame in 60:gait.update(1.0/60,Vector3(0,0,-9.4),"stand",true,{},false)
	var phase:=gait.phase
	for frame in 20:gait.update(1.0/60,Vector3(0,5,-9.4),"stand",false,{},false)
	check(gait.gait_name=="jump" and is_equal_approx(gait.phase,phase) and gait.offsets.left.y>.25,"Jump tucks legs and pauses running cycle")
	for frame in 20:gait.update(1.0/60,Vector3(0,-5,-9.4),"stand",false,{},false)
	check(gait.gait_name=="fall" and gait.offsets.left.y<.12,"Falling extends legs for landing")
	gait.update(1.0/60,Vector3.ZERO,"stand",true,{},false)
	check(gait.landing>0,"Landing briefly compresses the pose")
	var body: Dictionary={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.08,0)),"right_foot":Transform3D(Basis.IDENTITY,Vector3(.15,.08,0))}
	for i in 100:gait.update(.01,Vector3.FORWARD*5,"stand",true,body,false)
	check(gait.assist_weight==0,"Tracked animation is disabled by default")
	for i in 100:gait.update(.01,Vector3.FORWARD*5,"stand",true,body,true)
	check(gait.assist_weight>.99,"Opt-in assist blends in after both feet are still")
	body.left_foot.origin.z-=.10;gait.update(.01,Vector3.FORWARD*5,"stand",true,body,true)
	check(gait.assist_weight==0,"Intentional step immediately yields to tracking")
	body.left_foot.origin.y=.4
	for i in 100:gait.update(.01,Vector3.FORWARD*5,"stand",true,body,true)
	check(gait.assist_weight==0,"Held raised foot cannot become a synthetic standing pose")
	body.left_foot.origin=Vector3(-.15,.08,0)
	for i in 100:gait.update(.01,Vector3.FORWARD*5,"stand",true,body,true)
	for key in body:body[key].origin+=Vector3(.1,0,.2)
	gait.update(.01,Vector3.FORWARD*5,"stand",true,body,true)
	check(gait.assist_weight>.99,"Common room-scale rebase does not cancel assist")
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("Stance regression",0,100,60,true);game.set_process(false);game.set_physics_process(false)
	game.bots.free();game.bots=null
	for id in game.players:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(-15,-15)
	var s: Dictionary=game.players[1];s.spectator=false;s.dead=false;s.xr={}
	var actor=game.fighters[1]
	for posture in ["stand","crouch","prone"]:
		actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.jump_held=false;s.prone=posture=="prone";s.crouch=posture=="crouch"
		game._update_crouch(1,{})
		for i in 35:await physics_frame;actor.simulate(Vector2(0,-1),0,false,1.0/60,posture=="prone")
		var ratio: float=1.0 if posture=="stand" else .55 if posture=="crouch" else .18
		check(actor.stance==posture and absf(Vector2(actor.velocity.x,actor.velocity.z).length()-9.4*ratio)<.1,"Authoritative "+posture+" speed and height")
		check(is_equal_approx(actor.accuracy_scale(),1.0 if posture=="stand" else .75 if posture=="crouch" else .45),"Grounded "+posture+" spread multiplier")
		if posture=="prone":check(actor.position.y<Fixture.ORIGIN.y+.1 and not actor.jump_queued,"Held jump cannot lift a prone player")
	actor.position=Fixture.point();actor.velocity=Vector3.ZERO
	var ceiling=Fixture.box(game,Fixture.point()+Vector3.UP*1.0,Vector3(3,.5,3));await physics_frame
	s.prone=false;s.crouch=false;game._update_crouch(1,{})
	check(actor.stance=="prone" and actor.collision_height==.65,"Low ceiling blocks leaving prone without granting standing speed")
	ceiling.free();await physics_frame;game._update_crouch(1,{})
	check(actor.stance=="stand","Leaving the ceiling restores requested standing stance")
	var pose:=Poses.neutral();pose.height=.65;s.prone=true
	game._update_crouch(1,pose)
	check(actor.stance=="stand","Upright tracked head cannot claim prone collider or accuracy")
	pose.head.origin.y=.45;pose.left.origin.y=.3;pose.right.origin.y=.3;pose.weapon=pose.right;pose.height=.65
	game._update_crouch(1,pose)
	check(actor.stance=="prone" and not Poses.validate(pose).is_empty(),"Physical lying-down pose supports prone collision")
	actor.position=Fixture.point()+Vector3.UP*3;actor.velocity=Vector3.ZERO
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	check(actor.accuracy_scale()==1.0,"Airborne posture has no accuracy bonus")
	var copy=preload("res://deathmatch/fighter.gd").new();copy.setup(99,"Copy",Color.WHITE);game.add_child(copy)
	actor.tracked_leg_animation=true;copy.receive_locomotion(actor.locomotion_state())
	check(copy.stance=="prone" and copy.tracked_leg_animation and not copy.visual_grounded,"Authoritative stance, air state and assist replicate together")
	copy.free()
	var prediction=preload("res://deathmatch/movement/prediction.gd").new()
	actor.update_height(1.65,true);prediction.remember(1,actor.position,actor.velocity,1.65)
	prediction.reconcile(actor,1,actor.position,actor.velocity,.65)
	check(actor.stance=="prone","Acknowledged server denial corrects predicted stand-up")
	prediction.clear();actor.update_height(1.65,true);prediction.remember(2,actor.position,actor.velocity,1.65);actor.update_height(1.05,true)
	prediction.reconcile(actor,2,actor.position,actor.velocity,.65)
	check(actor.stance=="crouch","Older stance acknowledgement cannot undo newer crouch")
	# Exercise real firing rather than only checking a multiplier helper.
	var widths: Array=[]
	s.xr={};s.vr_device=false;s.weapon=4;s.owned=[4];s.ammo=[0,100,0,0];s.dead=false;s.spectator=false;s.yaw=0.0;s.pitch=0.0
	for posture in ["stand","crouch","prone"]:
		actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.jump_held=false;s.prone=posture=="prone";s.crouch=posture=="crouch";game._update_crouch(1,{})
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
		check(absf(game._weapon_transform(1).origin.y-actor.position.y-minf(1.45,actor.eye_height()))<.001,"Weapon origin follows "+posture+" eye height")
		s.cooldown=0;game.demos.events.clear();game.demos.recording=true;seed(7531);game._fire(1);game.demos.recording=false
		var width:=Vector2.ZERO;var found:=false
		for event in game.demos.events:
			if event[0]!="_impacts":continue
			found=true
			for end in event[1][1]:
				var direction: Vector3=(end-event[1][0]).normalized()
				width.x=maxf(width.x,absf(atan2(direction.x,-direction.z)));width.y=maxf(width.y,absf(asin(direction.y)))
		check(found and width.x>0 and width.y>0,"Actual shotgun pellets produced for "+posture)
		widths.append(width)
	check(absf(widths[1].x/widths[0].x-.75)<.01 and absf(widths[1].y/widths[0].y-.75)<.01,"Crouch tightens both actual spread axes by 25 percent")
	check(absf(widths[2].x/widths[0].x-.45)<.01 and absf(widths[2].y/widths[0].y-.45)<.01,"Prone tightens both actual spread axes by 55 percent")
	actor.tracked_leg_animation=true
	var demo_path: String="/tmp/fpsloppa-stances-%d.fpsdemo"%Time.get_ticks_usec()
	check(game.demos.start_record(demo_path),"Prone demo starts")
	game._send_snapshot();game.demos.stop_record();game.demos.input=FileAccess.open(demo_path,FileAccess.READ);game.demos.input.seek(8)
	var recorded: Dictionary=game.demos.read_frame()
	check(not recorded.is_empty(),"Stance metadata passes production demo validation")
	if not recorded.is_empty():
		actor.update_height(1.65,true);game.demos.apply_frame(recorded,false)
		check(actor.stance=="prone" and actor.tracked_leg_animation,"Demo playback restores prone and tracked-leg preference")
		var legacy: Dictionary=recorded.duplicate(true);legacy.snapshot[10].erase("locomotion")
		check(game.demos.valid_frame(legacy),"Legacy demos without stance metadata remain readable")
		recorded.snapshot[10].locomotion[1].height=NAN
		check(not game.demos.valid_frame(recorded),"Malformed stance metadata is rejected before playback")
	game.demos.input.close();game.demos.input=null;DirAccess.remove_absolute(demo_path)
	if "--client-config" in OS.get_cmdline_user_args():
		var bindings=preload("res://deathmatch/settings/bindings.gd").new();bindings.tracked_leg_animation=true;bindings.physical_prone=false
		check(bindings.save()==OK,"New movement options save")
		var saved=preload("res://deathmatch/settings/bindings.gd").new();saved.load_settings()
		check(saved.tracked_leg_animation and not saved.physical_prone and saved.keys.prone==KEY_Z,"Animation preference, physical prone and key binding survive reload")
	print("STANCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	game.free();quit(0 if failures.is_empty() else 1)
