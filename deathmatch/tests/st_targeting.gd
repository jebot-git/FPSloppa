extends SceneTree
## Exercise actual weapon traces, field requests and presentation, not synthetic hits.
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
var g
var r
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fire_target() -> bool:
	g.players[1].weapon=11;g.players[1].fire=true;g.players[1].cooldown=0;g.players[1].last_input=g.clock;g.fighters[1].tribes_state.energy=50
	return r.combat.fire(1)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_raindance";g.start_host("ST targeting",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false);r=g.match_mode.tribes;r.set_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Artillery");g._add_player(-2,"Enemy")
	for id in g.players:
		g.players[id].team=1 if id==-2 else 0;g.players[id].dead=false;g.players[id].spectator=false;g.players[id].invulnerable=0
		g.fighters[id].position=Fixture.ORIGIN+Vector3(id*10,0,30);g.fighters[id].velocity=Vector3.ZERO
	g.fighters[1].position=Fixture.ORIGIN
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	var wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,12,-100),Vector3(50,24,1))
	r.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(240,1,240),Vector3(480,200,480))
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	r.apply_equipment(1,"heavy",[3,4,7],"energy");r.apply_equipment(-1,"heavy",[3,4,7],"energy")
	var s: Dictionary=g.players[1];s.yaw=0;s.pitch=0
	# Both current native traces and the reference path must retain overlays.
	var beacon_point: Vector3=Fixture.ORIGIN+Vector3(0,1.45,-30)
	r.targeting.beacons[999]={"team":0,"position":beacon_point,"normal":Vector3.UP,"hp":10.0}
	var hit: Dictionary=g._trace(Fixture.ORIGIN+Vector3.UP*1.45,beacon_point-Vector3(0,0,2),1)
	check(hit.get("beacon",-1)==999,"Active ST weapon trace preserves beacon collision")
	r.targeting.beacons.erase(999)
	g.match_mode.kind="tdm";s.weapon=11;s.fire=true
	r.targeting.designate(1,{"hit":true,"position":beacon_point})
	check(r.targeting.lasers.is_empty() and r.stations()==null,"Arena Tribes loadout does not activate ST designation or stations")
	g.match_mode.kind="st"
	check(fire_target() and r.targeting.lasers.has(1),"Firing targeter traces a real wall and publishes its hit")
	var target: Vector3=r.targeting.lasers.get(1,{}).get("position",Vector3.INF)
	check(target.distance_to(Fixture.ORIGIN+Vector3(0,1.45,-99.5))<.02,"Desktop designation agrees with crosshair ray")
	check(r.targeting.targets(0).size()==1 and r.targeting.targets(1).is_empty(),"Shared laser target belongs only to the shooter's team")
	check(is_equal_approx(g.fighters[1].tribes_state.energy,47),"Targeter spends its ordinary energy cost")
	var before: int=s.shots;check(not r.combat.fire(1) and s.shots==before,"Held targeter respects trace cadence")
	if not is_instance_valid(g.camera):g.camera=Camera3D.new();g.add_child(g.camera)
	var view=preload("res://deathmatch/tribes/field_view.gd").new();g.add_child(view);view.setup(r)
	s.weapon=7;view.update()
	check(view.markers.has("l1") and view.markers.has("aiml1"),"Mortar displays teammate target and collision-checked aiming mark")
	check(view.markers.values().all(func(label):return label.fixed_size),"Artillery target text keeps readable size at long range")
	check(view.markers.aiml1.text=="⊕" and view.markers.aiml1.offset==Vector2.ZERO and view.markers.aiml1.get_node("Caption").offset.x>0,"Aiming ring is centred on solution independently of caption width")
	var direction: Vector3=(view.markers.get("aiml1",g).position-g._shot_solution(1).origin).normalized()
	var solution: Dictionary=r.targeting.solution(1,target,7)
	check(not solution.is_empty() and direction.distance_to(solution.get("direction",Vector3.ZERO))<.0001,"Displayed reticle uses the actual mortar solution")
	s.team=1;g.clock+=.2;view.update();check(view.markers.is_empty(),"Opposing team sees no targeting overlay");s.team=0
	s.dead=true;g.clock+=.2;view.update();check(view.markers.is_empty(),"Dead players see no firing guidance");s.dead=false
	s.weapon=3;g.clock+=.2;view.update();check(view.markers.is_empty(),"Ordinary guns show no artillery overlay")
	# Real controller weapon frames are authoritative for either dominant hand.
	for left in [false,true]:
		s.weapon=11
		s.vr_device=true;s.xr={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left_handed":left,"weapon":Transform3D(Basis(Vector3.UP,.06),Vector3(-.35 if left else .35,1.2,-.4))}
		var origin: Vector3=g._shot_solution(1).origin
		var expected: Dictionary=g._trace(origin,origin-s.xr.weapon.basis.z*1000,1)
		check(fire_target() and r.targeting.lasers[1].position.distance_to(expected.position)<.002,"Targeter follows tracked weapon rather than head (%s)"%left)
		s.xr.weapon.origin=Vector3(0,1.2,-101)
		s.cooldown=0;check(not r.combat.fire(1),"Tracking through cover cannot designate through wall (%s)"%left)
	s.vr_device=false;s.xr={};s.pitch=0;s.yaw=0
	for reason in ["release","weapon","death","spectator","life","team","menu","expiry"]:
		fire_target()
		match reason:
			"release":s.fire=false
			"weapon":s.weapon=3
			"death":s.dead=true
			"spectator":s.spectator=true
			"life":s.serial+=1
			"team":s.team=1
			"menu":s.input_blocked=true
			"expiry":g.clock+=.5
		r.targeting.tick();check(r.targeting.lasers.is_empty(),"Designation clears on "+reason)
		s.team=0;s.dead=false;s.spectator=false;s.input_blocked=false
	fire_target();s.pitch=PI*.49;fire_target()
	check(r.targeting.lasers.is_empty(),"Moving laser into empty sky removes previous surface target")
	r.targeting.reset();s.pitch=-.8;s.tribes_beacons=3;g.clock+=1
	check(r.perform_field(1,"beacon",g.map_epoch,s.serial,1),"Field-menu request places beacon along desktop aim")
	check(s.tribes_beacons==2 and r.targeting.beacons.size()==1,"Accepted request consumes exactly one beacon")
	check(not r.perform_field(1,"beacon",g.map_epoch,s.serial,1) and s.tribes_beacons==2,"Replayed field request cannot place a second beacon")
	for left in [false,true]:
		g.clock+=1;s.vr_device=true;s.xr={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left_handed":left,"weapon":Transform3D(Basis(Vector3.RIGHT,-.7),Vector3(-1 if left else 1,1.1,-.4))}
		check(r.perform_field(1,"beacon",g.map_epoch,s.serial,3 if left else 2),"Controller aim places beacon (%s)"%left)
	s.xr={};s.vr_device=false;s.pitch=0
	var packed: Dictionary=Codec.unpack(Codec.pack(r.targeting.snapshot()))
	var replica=preload("res://deathmatch/tribes/targeting.gd").new();replica.setup(r);replica.receive(packed)
	check(replica.beacons==r.targeting.beacons and replica.targets(0).size()==3 and replica.targets(1).is_empty(),"Beacon snapshot round trip preserves positions, health and team filtering")
	var key: int=r.targeting.beacons.keys()[0]
	r.targeting.damage(key,-2,.05*r.Arsenal.UNIT);check(r.targeting.targets(0).size()==2,"Disabled beacon stops giving guidance")
	check(not r.targeting.repair(key,-2,10) and r.targeting.repair(key,1,10),"Only teammate repairs restore beacon")
	check(r.targeting.targets(0).size()==3,"Repaired beacon resumes guidance")
	r.targeting.damage(key,-2,100);g.clock+=.2;view.update()
	check(not view.nodes.has("b%d"%key),"Destroyed beacon model is removed")
	# A real designation is consumed by artillery bot's ordinary combat controller.
	s.pitch=0;s.yaw=0;fire_target();r.targeting.beacons.clear()
	var ai=g.bots;var brain: Dictionary=ai.new_brain(-1);brain.role="siege";brain.enemy=0;brain.goal_kind="st_bombard";brain.goal_key="st:bombard";brain.designate_at=INF
	g.fighters[-1].position=Fixture.ORIGIN+Vector3(12,0,35);g.players[-1].weapon=7;g.players[-1].yaw=0;g.players[-1].pitch=0
	check(ai.tribes.offense.bombard(-1,brain,1.0) and brain.has("bombard_solution"),"Heavy support acquires teammate laser designation")
	check(brain.get("bombard_solution",{}).get("target",Vector3.INF).distance_to(r.targeting.lasers[1].position)<.001,"Artillery uses shared hit position without inventing target")
	# Support AI must reach the same laser path through the normal combat loop.
	var d=r.deployables;d.rows[900]={"kind":"pulse","team":1,"owner":-2,"position":Fixture.ORIGIN+Vector3(0,0,-80),"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp("pulse"),"energy":100.0,"ready":0.0,"aim":Vector3.FORWARD}
	var paint: Dictionary=ai.new_brain(1);paint.role="escort";paint.enemy=0
	s.cooldown=0;ai.combat(1,paint,1.0)
	check(s.weapon==11 and s.fire and paint.has("designation"),"Ordinary bot combat selects targeter for visible equipment with nearby artillery")
	check(r.combat.fire(1) and r.targeting.lasers[1].position.distance_to(d.rows[900].position)<3,"AI targeting input publishes actual equipment trace hit")
	check(d.rows[900].hp==d.Data.hp("pulse"),"Targeting laser does not damage designated equipment")
	g.match_mode.flags[1].carrier=1;check(not ai.tribes.offense.designate(1,paint,1.0),"Flag carrier does not stop to paint artillery targets");g.match_mode.flags[1].carrier=0
	d.rows.erase(900);s.yaw=0;s.pitch=0;fire_target()
	if "--capture-targeting" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,800);root.position=Vector2i(6000,6000)
		for row in [[Vector3(0,-.5,-50),Vector3(120,1,140),Color("27313c")],[Vector3(0,12,-100),Vector3(50,24,1),Color("526878")]]:
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=row[1];mesh.mesh=box;mesh.position=Fixture.ORIGIN+row[0];var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=row[2];mesh.material_override=mat;g.add_child(mesh)
		g.camera.global_transform=Transform3D(Basis.IDENTITY,Fixture.ORIGIN+Vector3(0,1.45,0));g.camera.make_current();s.weapon=7
		g.clock+=.1;view.next_update=0;view.update()
		check(view.markers.has("l1") and view.markers.has("aiml1"),"Vulkan capture contains target and mortar cues")
		for frame in 4:await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/st-main-sync/targeting-guidance.png")
		g.camera.look_at(view.markers.aiml1.global_position)
		for frame in 4:await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/st-main-sync/targeting-aim.png")
	wall.free();view.free();g.disconnect_game();g.free()
	print("ST_TARGETING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
