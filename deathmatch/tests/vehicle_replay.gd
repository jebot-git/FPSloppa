extends SceneTree
## Production recording/playback regression: a translating, banking occupied LPC.
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pose(t: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,t*.2)*Basis(Vector3.RIGHT,.1)*Basis(Vector3.FORWARD,.15),Fixture.ORIGIN+Vector3(t*25,20,0))
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_raindance";g.start_host("Replay smoothing",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);g.demos.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	var rules=g.match_mode.tribes;rules.set_process(false)
	var c=rules.vehicles;var pads=rules.stations()
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	var s: Dictionary=g.players[1];s.team=0;s.dead=false;s.spectator=false;s.input_blocked=false
	g.clock+=4;g.fighters[1].position=pads.rows[index].position;rules.energy[0]=20000
	rules.apply_equipment(1,"light",[3,2,0],"energy");s.input_blocked=false
	await physics_frame
	check(c.purchase(1,g.map_epoch,s.serial,"lpc"),"Production transport purchased for recording")
	if c.rows.is_empty():g.free();quit(1);return
	var key: int=c.rows.keys()[0];var row: Dictionary=c.rows[key]
	row.pilot=1;row.life=s.serial
	var passenger: int=g.players.keys().filter(func(id):return id!=1)[0]
	var runner: int=g.players.keys().filter(func(id):return id!=1 and id!=passenger)[0]
	g.players[passenger].dead=false;g.players[passenger].spectator=false
	row.passengers[0]=passenger;row.passenger_lives[0]=g.players[passenger].serial
	var path:="/tmp/fps-vehicle-replay-%d.fpsdemo"%Time.get_ticks_usec()
	check(g.demos.start_record(path),"Start occupied transport recording")
	for tick in 101:
		var t: float=tick*.05
		g.clock=g.demos.started+t;row.position=pose(t).origin;row.yaw=t*.2;row.pitch=.1;row.bank=.15;row.velocity=Vector3(25,0,0)
		g.fighters[runner].position=pose(t).origin+Vector3.FORWARD*50
		c.pin(key);g._send_snapshot()
	g.demos.stop_record()
	check(g.demos.open_demo(path),"Recorded transport passes demo validation")
	g.demos.set_process(false);g.match_mode.tribes.set_process(false)
	c=g.match_mode.tribes.vehicles
	for hz in [30,90,144]:
		for speed in [.5,1.0,2.0]:
			g.demos.seek(1);g.demos.speed=speed;g.demos.paused=false
			var error:=0.0;var seat_error:=0.0;var step_error:=0.0;var runner_error:=0.0;var previous:=Vector3.ZERO
			for f in hz:
				g.demos.tick(1.0/hz)
				# Multiple render ticks in this test share an engine frame number.
				c.render_frames.clear()
				var shown: Transform3D=c.render_frame(key)
				if f>int(hz*.15):
					error=maxf(error,shown.origin.distance_to(pose(g.demos.render_time()).origin))
					runner_error=maxf(runner_error,g.fighters[runner].position.distance_to(pose(g.demos.render_time()).origin+Vector3.FORWARD*50))
					step_error=maxf(step_error,absf(shown.origin.distance_to(previous)-25*speed/hz))
				for id in [1,passenger]:
					var actor=g.fighters[id]
					seat_error=maxf(seat_error,actor.render_position().distance_to(shown*c.definition(c.rows[key]).seats[c.seat_for(id,c.rows[key])]))
				previous=shown.origin
			check(error<.001 and step_error<.001,"%d Hz at %.1fx: hull speed uniform, max position error %.6f"%[hz,speed,error])
			check(seat_error<.001,"%d Hz at %.1fx: pilot and passenger use hull timeline"%[hz,speed])
			check(runner_error<.001,"%d Hz at %.1fx: unmounted fighter shares the replay timeline"%[hz,speed])
	g.demos.paused=true;g.demos.tick(.01);c.render_frames.clear()
	var held: Transform3D=c.render_frame(key)
	g.clock+=200;g.demos.tick(1);c.render_frames.clear()
	check(c.render_frame(key).is_equal_approx(held),"Paused hull unaffected by elapsed wall/physics time")
	g.demos.seek(.5);c.render_frames.clear()
	check(c.render_frame(key).origin.x<Fixture.ORIGIN.x+15,"Backward seek discards future vehicle poses")
	g.demos.viewpoint="first";g.demos.selected_player=1;g.demos.update_camera(0)
	check(g.demos.camera.position.is_equal_approx(g.fighters[1].render_position()+Vector3.UP*g.fighters[1].eye_height()),"Replay camera rides the interpolated seat")
	g.headless=false;c.update(0)
	for id in [1,passenger]:
		var actor=g.fighters[id];actor._process(.016)
		c.update(.016)
		if not is_instance_valid(actor.avatar):continue
		check(actor.avatar.global_position.distance_to(actor.render_position())<.001,"Mounted visual stays attached for occupant %d"%id)
		if not actor.avatar_hash.is_empty():check(actor.avatar.speed==0 and actor.avatar.grounded,"Occupant %d does not walk at aircraft speed"%id)
	if DisplayServer.get_name()!="headless":
		var library=preload("res://deathmatch/avatars/library.gd").new()
		library.entries["sample_d"]={"path":"res://vrm/sample_d.vrm"}
		var model=preload("res://deathmatch/avatars/visual_loader.gd").create_avatar(library,"sample_d")
		var actor=g.fighters[passenger];actor.clear_mounted_visuals();actor.set_avatar(model,"sample_d")
		actor.show_alive(true,false);actor.visual_velocity=Vector3(25,0,0)
		actor._process(.016);model._process(.016);c.update(.016)
		check(model.speed==0 and model.grounded,"VRM passenger uses a grounded idle pose on the moving deck")
		check(model.global_position.distance_to(actor.render_position())<.001,"VRM animation preserves the interpolated seat attachment")
		library.free()
	check(g.demos.process_priority<g.fighters[1].process_priority,"Playback updates precede passenger animation")
	g.demos.stop_playback()
	check(not g.fighters[1].physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Leaving replay restores normal interpolation")
	g.disconnect_game();g.free()
	DirAccess.remove_absolute(path)
	print("VEHICLE_REPLAY ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
