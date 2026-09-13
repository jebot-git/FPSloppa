extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
const OUT="res://test-results/ba2/gameplay/"
var g
var w
var camera: Camera3D
var failures: Array=[]
func _initialize():run.call_deferred()
func shot(label: String,at: Vector3,target: Vector3) -> void:
	camera.position=at;camera.look_at(target);camera.make_current()
	for i in 12:w.draw(1./60.);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1"
	g.start_host("BA-2 render",0,100,60,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():if id<0:g._peer_left(id)
	# Exercise the fixed TB host timer and leave other modes editable.
	g.hud.host_mode.configure([{"id":"tb","title":"TITANBALL"},{"id":"dm","title":"DEATHMATCH"}],"MODE")
	g.hud.host_mode.choose("tb");g.hud.minutes.value=33;g.hud.refresh_maps()
	if g.hud.minutes.value!=10 or g.hud.minutes.editable:failures.append("TB host timer lock")
	g.hud.host_mode.choose("dm");g.hud.refresh_maps()
	if not g.hud.minutes.editable:failures.append("other mode timer control")
	Fixture.build(g);g.match_mode.titanball.advance_time(60.);w=g.match_mode.fortress.walkers
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	if g.viewmodel:g.viewmodel.hide()
	g.fighters[1].position=Vector3(0,.05,6);g.fighters[1].show_alive(true,true)
	camera=Camera3D.new();camera.fov=80;g.add_child(camera)
	if g.camera:camera.cull_mask=g.camera.cull_mask
	await physics_frame;await physics_frame
	var r: Dictionary=w.robots.test
	g.match_mode.titanball.preparation_left=60.;g.match_mode.titanball.update_gate()
	var gate_mesh: MeshInstance3D=g.match_mode.titanball.gate_ref.get_ref().get_node("Mesh")
	var gate_bounds: AABB=gate_mesh.get_aabb()
	if absf(gate_bounds.size.z-1.2)>.001 or gate_bounds.position.z<=18 or gate_bounds.end.z>=20:failures.append("gate faces are not recessed inside the wall pocket")
	await shot("hangar",Vector3(12,7,12),Vector3(0,7,18))
	await shot("hangar_outside",Vector3(0,24,45),Vector3(0,8,5))
	g.match_mode.titanball.advance_time(60.)
	await shot("parked",Vector3(12,7,19),Vector3(0,5,0))
	await shot("ladder",Vector3(0,1.5,2.5),Vector3(0,2.8,0))
	g.fighters[1].position=w.transform(r)*w.LADDER
	g.players[1].invulnerable=0.;g.players[1].input_blocked=false
	if not w.try_board(1,"test"):failures.append("boarding")
	var eye: Vector3=w.transform(r)*(w.SEAT+Vector3.UP*1.5)
	var exterior_camera: Camera3D=camera
	g._process(1./60.);camera=g.camera
	await shot("cockpit",eye,eye+w.transform(r).basis.z*30)
	if not g.viewmodel.visible or g.model_weapon!=0 or g.model_art_rules!="doom":failures.append("pilot fist presentation")
	await shot("cockpit_rear",eye,eye-w.transform(r).basis.z*30)
	if g.camera.cull_mask!=w.cockpit.PRIVATE_LAYER:failures.append("rear view leaks world")
	await shot("cockpit",eye,eye+w.transform(r).basis.z*30)
	if w.cockpit.hud.get_viewport()!=w.cockpit.feed or not w.cockpit.hud.visible or w.cockpit.hud.telemetry.armor!=200:failures.append("live HUD is absent from monitor viewport")
	if w.cockpit.hud.telemetry.exit_lock!=3.:failures.append("monitor boarding lock countdown missing")
	w.cockpit.feed.get_texture().get_image().save_png(OUT+"cockpit_feed.png")
	if absf(w.cockpit.hud.telemetry.remaining-r.path.get_baked_length())>.001:failures.append("monitor remaining distance at start")
	r.distance=r.path.get_baked_length()-.32
	await shot("cockpit_distance_to_goal",eye,eye+w.transform(r).basis.z*30)
	w.cockpit.feed.get_texture().get_image().save_png(OUT+"cockpit_feed_distance_to_goal.png")
	if absf(w.cockpit.hud.telemetry.remaining-.32)>.001:failures.append("monitor remaining distance does not update from route progress")
	r.distance=r.path.get_baked_length()+.1
	await shot("cockpit_goal_reached",eye,eye+w.transform(r).basis.z*30)
	if w.cockpit.hud.telemetry.remaining!=0.:failures.append("monitor distance becomes negative beyond endpoint")
	r.distance=0.
	var saved_hp: int=g.players[1].hp;g.players[1].hp=67;r.heat=[100.,25.];r.overheated=[true,false]
	await shot("cockpit_heat",eye,eye+w.transform(r).basis.z*30)
	if w.cockpit.hud.telemetry.hp!=67 or w.cockpit.hud.telemetry.heat!=r.heat or not w.cockpit.hud.telemetry.locked[0]:failures.append("monitor telemetry did not update")
	w.cockpit.feed.get_texture().get_image().save_png(OUT+"cockpit_feed_heat.png")
	g.players[1].hp=saved_hp;r.heat=[0.,0.];r.overheated=[false,false]
	camera=exterior_camera;g.viewmodel.hide()
	if not w.views.test.pilot_shell.visible:failures.append("exterior shell removed")
	if g.camera.cull_mask!=w.cockpit.PRIVATE_LAYER or not w.cockpit.interior.visible:failures.append("monitor-only cockpit isolation")
	if w.cockpit.sensor.cull_mask&w.cockpit.PRIVATE_LAYER:failures.append("monitor captures private interior")
	for i in 180:g.clock+=1./60.;w.tick(1./60.)
	r.pitches=[deg_to_rad(20),deg_to_rad(-10)];r.body_yaw=w.Tuning.LATERAL_LIMIT
	await shot("walking",Vector3(12,7,19),r.position+Vector3.UP*5)
	var view=w.views.test
	if not view.pilot_shell.visible:failures.append("exterior walking camera lost robot body")
	if w.cockpit.interior.visible:failures.append("interior visible from outside")
	if w.cockpit.feed.render_target_update_mode!=SubViewport.UPDATE_DISABLED:failures.append("inactive monitor still rendering")
	if view.ladder.visible:failures.append("ladder visible while manned")
	if not view.skeleton or view.skeleton.get_bone_count()!=18:failures.append("skeleton")
	for pair in 2:
		var bone: int=view.skeleton.find_bone("Cannon.L" if pair==0 else "Cannon.R")
		var relative: Quaternion=view.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion().inverse()*view.skeleton.get_bone_pose_rotation(bone)
		if absf(relative.y)>.0001 or absf(relative.z)>.0001:failures.append("cannon axis")
		var barrel: Vector3=(view.skeleton.global_basis*view.skeleton.get_bone_global_pose(bone).basis.y).normalized()
		var expected: Vector3=w.transform(r).basis*w._body_pose(r).basis*Basis(Vector3.RIGHT,r.pitches[pair])*Vector3.BACK
		if barrel.dot(expected)<.99995:failures.append("visible cannon elevation/torso yaw disagrees with firing direction")
	if not w.leave(1):failures.append("dismount")
	for i in 120:g.clock+=1./60.;w.tick(1./60.)
	await shot("stopped",Vector3(12,7,19),r.position+Vector3.UP*5)
	if not view.ladder.visible:failures.append("ladder absent after stop")
	await shot("ladder_after_exit",w.transform(r)*Vector3(1.6,1.6,2.8),w.transform(r)*Vector3(0,2.4,0))
	g.fighters[1].position=w.transform(r)*w.LADDER
	if not w.try_board(1,"test"):failures.append("ladder reboarding before death test")
	for i in 120:g.clock+=1./60.;w.tick(1./60.)
	g._damage(1,1,5000,"TEST",true)
	await shot("ladder_death_braking",w.transform(r)*Vector3(1.6,1.6,2.8),w.transform(r)*Vector3(0,2.4,0))
	if r.pilot!=0 or r.speed<=0. or view.ladder.visible:failures.append("death braking ladder state")
	for i in 120:g.clock+=1./60.;w.tick(1./60.)
	await shot("ladder_after_death",w.transform(r)*Vector3(1.6,1.6,2.8),w.transform(r)*Vector3(0,2.4,0))
	if r.pilot!=0 or r.speed!=0. or not view.ladder.visible or not view.prompt.visible:failures.append("empty stopped robot did not deploy ladder after death")
	g.players[1].dead=false;g.players[1].input_blocked=false;g.fighters[1].position=w.transform(r)*w.LADDER
	if not w.try_board(1,"test"):failures.append("boarding before crush render")
	g._add_player(-1,"Crush target");g.players[-1].team=1;g.players[-1].dead=false;g.players[-1].spectator=false;g.players[-1].invulnerable=0.;g.players[-1].hp=100
	g.fighters[-1].position=w.transform(r)*Vector3(.7,0,0)
	g.match_mode.fortress.buildings[98765]={"owner":-1,"team":1,"position":w.transform(r)*Vector3(-1.5,0,1),"kind":"sentry","hp":150,"ready":g.clock,"next":g.clock+3,"expires":g.clock+120}
	g._process(1./60.);g.viewmodel.hide()
	await shot("blue_sentry_before_stomp",w.transform(r)*Vector3(4,2.2,4),w.transform(r)*Vector3(.7,.65,0))
	await physics_frame;await physics_frame;w.tick(.1);g._process(1./60.);g.viewmodel.hide()
	await shot("crush_gibs",w.transform(r)*Vector3(4,2.2,4),w.transform(r)*Vector3(.7,.65,0))
	if not g.players[-1].dead or not g.fighters[-1].gibbed or g.effects.gibs.is_empty():failures.append("crush did not produce visible gib state and pieces")
	if g.match_mode.fortress.buildings.has(98765) or g.match_mode.fortress.visuals.has("b98765"):failures.append("Blue sentry or its visual survived the stomp")
	await shot("corridor",Vector3(0,32,32),Vector3(0,12,135))
	for i in Fixture.Timing.CHECKPOINTS.size():
		var pose: Transform3D=w.Route.sample(r.path,Fixture.Timing.CHECKPOINTS[i])
		await shot("checkpoint"+str(i+1),pose*Vector3(7,6,-20),pose.origin+Vector3.UP*8)
		if g.get_node("Map").find_children("TBObjectiveLabel","Label3D",true,false).size()!=3:failures.append("checkpoint/base markers missing")
	for distance in [43.,88.,135.,198.,235.,285.]:
		var pose: Transform3D=w.Route.sample(r.path,distance)
		await shot("defence"+str(int(distance)),pose*Vector3(5,6,-18),pose.origin+Vector3.UP*7)
	var wreck_pose: Transform3D=w.Route.sample(r.path,30.)
	await shot("street_wreck",wreck_pose*Vector3(6,1.8,-5),wreck_pose*Vector3(10.3,.85,0))
	var rubble_pose: Transform3D=w.Route.sample(r.path,60.)
	await shot("street_rubble",rubble_pose*Vector3(-5.5,1.8,-4),rubble_pose*Vector3(-9.5,.7,0))
	var room_pose: Transform3D=w.Route.sample(r.path,36.)
	await shot("ambush_room",room_pose*Vector3(-22,1.65,0),room_pose.origin+Vector3.UP*1.65)
	camera.position=w.transform(r)*Vector3(10,8,24);camera.look_at(w.transform(r)*Vector3(2,3,20));camera.make_current()
	g._ability_fx("ba2_cannon",w.cannon_origin(r,0),w.transform(r)*Vector3(2.336,.85,26),0)
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"cannon_splash.png")
	if not is_instance_valid(g.ability_effects) or g.ability_effects.bursts.is_empty():failures.append("small cannon burst effect")
	FileAccess.open(OUT+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"bones":view.skeleton.get_bone_count()},"  "))
	print("BA2_RENDER_RESULT ",JSON.stringify(failures));g.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
