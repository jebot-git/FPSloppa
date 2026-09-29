extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Art=preload("res://deathmatch/art.gd")
const Profiles=preload("res://deathmatch/effects/surface_marks.gd")
class Visuals extends "res://deathmatch/experimental/visuals.gd":
	var last_start:=Vector3.ZERO
	func impacts(rules: String,start: Vector3,ends: PackedVector3Array,weapon: int,definition: Dictionary={},light: bool=true):
		last_start=start;super.impacts(rules,start,ends,weapon,definition,light)
var g
var fx
var checks:=0
var failures: Array=[]
var pulses: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Shared feedback",0,100,60,true)
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);Fixture.setup(g)
	if not is_instance_valid(g.hud):g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	if not is_instance_valid(g.xr_rig):g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig)
	g.xr_rig.setup(g,true);var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	rig.controller_pulse.connect(func(hand,amplitude,duration,frequency):pulses.append({"hand":hand,"amplitude":amplitude,"duration":duration,"frequency":frequency}))
	await physics_frame;await physics_frame
	g.headless=false;g.menu_open=false;g.fighters[1].position=Fixture.point();g.players[1].dead=false
	g.presentation.controller_haptic_strength=.5;pulses.clear();rig.feedback(.8,.06,false,70)
	check(pulses.size()==1 and is_equal_approx(pulses[0].amplitude,.4) and is_equal_approx(pulses[0].duration,.06) and pulses[0].frequency==70,"Controller strength scales amplitude while retaining pulse duration and frequency")
	for left in [false,true]:
		rig.left_handed=left;pulses.clear();rig.weapon_wheel.pulse(.3)
		check(pulses.size()==1 and pulses[0].hand=="right" and is_equal_approx(pulses[0].amplitude,.15),"Wheel haptics use saved strength on physical right controller with either handedness")
	g.presentation.controller_haptic_strength=0;pulses.clear();rig.feedback(.8);rig.feedback(.8,.08,true);rig.weapon_wheel.pulse(.3)
	check(pulses.is_empty(),"Zero controller strength disables both hands and wheel feedback")
	g.presentation.controller_haptic_strength=1.0;pulses.clear();rig.left_handed=false
	fx=Visuals.new();g.add_child(fx);g.variant_visuals=fx;fx.set_process(false)
	var ends:=PackedVector3Array([Fixture.point(0,-10)+Vector3.UP])
	for rules in ["doom","quake","ut99","cs16"]:
		g.armory.select(rules);g.match_mode.kind="dm"
		for left in [false,true]:
			rig.left_handed=left
			for w in g.armory.table.size():
				g.players[1].weapon=w;g.desired_weapon=w;g.clock+=.1
				rig.head.position=Vector3(0,1.65,0);rig.left.transform=Transform3D(Basis(Vector3.RIGHT,.1),Vector3(-.25,1.2,-.3));rig.right.transform=Transform3D(Basis(Vector3.RIGHT,.1),Vector3(.25,1.2,-.3));rig.left_aim.transform=rig.left.transform;rig.right_aim.transform=rig.right.transform
				rig._process(.016)
				var grip=rig.left if left else rig.right
				var relative: Transform3D=rig.gun.transform
				grip.position+=Vector3(.13,.03,.02)
				var muzzle: Vector3=rig.gun.to_global(rig.gun.get_meta("muzzle"))
				g._impacts(muzzle+Vector3(.1,.1,.2),ends,w,PackedVector3Array(),-1,1)
				check(fx.last_start.is_equal_approx(muzzle) and rig.gun.get_parent()==grip and rig.gun.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF and rig.gun.transform.is_equal_approx(relative),"Stable tracked model and muzzle "+str([rules,w,left]))
				if rules=="doom" and w==2:
					var other=rig.right if left else rig.left;other.position.x+=.1
					g._impacts(muzzle,ends,w,PackedVector3Array(),-1,1,true)
					check(fx.last_start.is_equal_approx(rig.offhand_gun.to_global(rig.offhand_gun.get_meta("muzzle"))) and rig.offhand_gun.get_parent()==other,"Dual pistol stays anchored to support hand")
				g._impacts(Vector3.ONE,ends,w,PackedVector3Array(),-1,-1)
				check(fx.last_start==Vector3.ONE,"Remote muzzle remains independent "+str([rules,w,left]))
				for alternate in ([false,true] if rules=="ut99" and g.armory.data(w).has("alt") and not g.armory.data(w).get("scope",false) else [false]):
					pulses.clear();rig.support_aim.engaged=false
					if rules=="doom":g._play_shot_fx(1,w)
					else:g._play_variant_shot_fx(1,w,alternate)
					check(pulses.size()==1 and pulses[0].hand==("left" if left else "right") and pulses[0].amplitude>0 and pulses[0].duration<=float(g.armory.data(w,alternate).cycle)*.8+.001,"Controller firing pulse: "+str([rules,w,left,alternate]))

		# Exercise real projectile spawn and render without moving simulation origin.
		var w: int={"doom":6,"quake":5,"ut99":4,"cs16":6,"tribes":2}[rules]
		g.players[1].weapon=w;rig._process(.016)
		if rules!="cs16":
			var muzzle: Vector3=rig.gun.to_global(rig.gun.get_meta("muzzle"));var authority:=muzzle+Vector3(.12,0,.05)
			g._projectile_spawn(800,1,w,authority,Vector3.FORWARD,0,0)
			check(g.projectiles[800].position==authority and g.projectiles[800].node.position.is_equal_approx(muzzle),rules+" projectile visibly spawns at muzzle without changing damage origin")
			g._update_projectile_visuals(0)
			check(g.projectiles[800].node.position.is_equal_approx(muzzle),rules+" first render preserves muzzle origin")
			for i in 8:g._update_projectile_visuals(.02)
			check(g.projectiles[800].node.position.is_equal_approx(authority),rules+" muzzle correction settles onto authoritative path")
			g._projectile_end(800,authority,w)
		rig.enabled=false
		g.model_weapon=w;g.viewmodel=Art.weapon(w,2,rules);g.add_child(g.viewmodel);g.viewmodel.position=Fixture.point()+Vector3(.2,1.2,-.4)
		g._impacts(Vector3.ZERO,ends,w,PackedVector3Array(),-1,1)
		check(fx.last_start.is_equal_approx(g.viewmodel.to_global(g.viewmodel.get_meta("muzzle"))),rules+" desktop tracer uses visible barrel")
		g.viewmodel.free();g.viewmodel=null;rig.enabled=true

	for left in [false,true]:
		rig.left_handed=left;g.armory.select("doom");g.players[1].weapon=2;rig._process(.016);rig.support_aim.engaged=false;pulses.clear();g._play_shot_fx(1,2,true)
		check(pulses.size()==1 and pulses[0].hand==("right" if left else "left"),"Offhand pistol haptic reaches its actual controller")
		pulses.clear();g._melee_fx(1,true);check(pulses.size()==1 and pulses[0].hand==("right" if left else "left"),"Offhand physical melee routes haptics correctly")
	rig.support_aim.engaged=true;pulses.clear();g._play_shot_fx(1,3)
	check(pulses.size()==2 and pulses[1].amplitude<pulses[0].amplitude,"Braced weapon has lighter support-hand recoil")
	rig.support_aim.engaged=false
	for state in ["remote","menu","unfocused","dead","demo"]:
		pulses.clear();g.menu_open=state=="menu";rig.focused=state!="unfocused";g.players[1].dead=state=="dead";g.demos.playing=state=="demo"
		g._play_shot_fx(-1 if state=="remote" else 1,3)
		check(pulses.is_empty(),"No local weapon rumble for "+state)
	g.menu_open=false;rig.focused=true;g.players[1].dead=false;g.demos.playing=false

	g.match_mode.kind="tf";g.armory.select("quake")
	for role in g.match_mode.fortress.CLASSES:
		g.players[1].tf_class=role
		for w in g.match_mode.fortress.class_definition(role).owned:
			g.players[1].weapon=w;pulses.clear();g._play_variant_shot_fx(1,w,false)
			check(pulses.size()==1,"TF class weapon controller feedback: "+str([role,w]))

	var walkers=g.match_mode.fortress.walkers;walkers.robots["haptic_test"]={"pilot":1}
	for left in [false,true]:
		rig.left_handed=left
		for side in 2:
			pulses.clear();walkers._cannon_feedback(1,side)
			check(pulses.size()==1 and pulses[0].hand==("left" if side==0 else "right"),"Titan cannon pair pulses the physical firing hand")
	walkers.robots.erase("haptic_test")
	g.match_mode.kind="dm"
	g.armory.select("doom");g.players[1].weapon=2;rig._process(.016)
	fx.particles.clear();fx.emission_budget=64;g._impacts(Fixture.point()+Vector3.UP,ends,2,PackedVector3Array([Vector3.ZERO]),-1,1)
	check(fx.particles.is_empty(),"Misses have a tracer but no fake endpoint impact")
	for style in range(7):
		g.clock+=1;fx.particles.clear();fx.emission_budget=64
		var at:=Fixture.point(style-3,-4)+Vector3.UP
		g._contact_fx(at,Vector3.BACK,style)
		check(fx.particles.size()>=9 and fx.particles.any(func(p):return p.smoke),"Contact emits sparks/chips and a puff: "+str(style))
		var count: int=fx.particles.size();g._contact_fx(at,Vector3.BACK,style)
		check(fx.particles.size()==count,"Repeated contact coalesces: "+str(style))
	fx.particles.clear();g._contact_fx(Vector3.ZERO,Vector3.ZERO,0);g._contact_fx(Vector3.INF,Vector3.UP,0)
	check(fx.particles.is_empty(),"Invalid contacts cannot emit effects")
	g.clock+=1;fx.emission_budget=64
	g._damage_map_hit({"hit":true,"id":0,"position":Fixture.point(0,-3)+Vector3.UP,"map_node":null},1,10)
	check(not fx.particles.is_empty(),"Dynamic prop damage emits contact feedback without world decals")
	for mode in ["dm","tdm","ctf","koth","ft","tf","tb","as","de","ig","if","cc"]:
		g.match_mode.kind=mode;g.match_mode.defusal.phase="live";g.intermission=0;g.clock+=1
		for id in [1,-1]:g.players[id].merge({"team":0 if id==1 else 1,"hp":2000,"armor":0,"dead":false,"spectator":false,"invulnerable":0},true)
		g.hit_flash=0;g._damage(-1,1,10,"PISTOL",false,Fixture.point(0,-3)+Vector3.UP,Vector3.FORWARD)
		check(g.hit_flash>0 and is_equal_approx(g.effects.confirmation_at,g.clock) and g.effects.last_hit.has(-1),"Authoritative player hit has visual/audio confirmation in "+mode)
	g.match_mode.kind="dm";g.hit_flash=0;g.players[-1].invulnerable=g.clock+2;g._damage(-1,1,10,"PISTOL")
	check(g.hit_flash==0,"Blocked damage does not falsely confirm a hit")
	g.players[-1].invulnerable=0;g._damage(-1,1,0,"PISTOL");check(g.hit_flash==0,"Zero damage does not confirm a hit")
	for kind in ["hit_confirm","impact_dust","impact_energy","impact_heavy","flesh","pain"]:check(g.spatial.choose(kind)!=null,"Contact SFX available: "+kind)
	var fallback:=Art.marine(Color("8ca5ac"));g.fighters[-1].add_child(fallback);fallback.hurt(Vector3.FORWARD,20);fallback.animate(.016,Vector3.ZERO,"stand",1.65,true,{},false)
	check(absf(fallback.get_node("Upper").rotation.x)>.02,"Fallback body visibly flinches")
	for i in 40:fallback.animate(.016,Vector3.ZERO,"stand",1.65,true,{},false)
	check(fallback.pain==0 and fallback.get_node("Upper").rotation.is_zero_approx(),"Flinch returns smoothly to ordinary stance")
	fallback.free()
	var avatar=g.avatars.library.create_avatar(g.avatars.library.selected)
	g.fighters[-1].add_child(avatar);avatar.set_process(false);avatar.dead=false;avatar.hurt(Vector3.RIGHT,25)
	avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
	check(avatar.pain>0 and absf(avatar.rotation.z)>.02,"VRM body has a directional pain reaction")
	avatar.first_person=true;avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
	check(avatar.rotation.x==0 and avatar.rotation.z==0,"Local tracked viewpoint is not tilted by pain animation")
	avatar.free()
	var demo_path:="res://test-results/shared-feedback/contacts.fpsdemo"
	DirAccess.make_dir_recursive_absolute("res://test-results/shared-feedback")
	DirAccess.remove_absolute(demo_path);g.demos.start_record(demo_path);g._contact_fx(Fixture.point(),Vector3.UP,0);g._send_snapshot();g.demos.stop_record()
	g.demos.input=FileAccess.open(demo_path,FileAccess.READ);g.demos.input.seek(g.demos.MAGIC.length());var frame: Dictionary=g.demos.read_frame();g.demos.input.close();g.demos.input=null
	check(not frame.is_empty() and frame.events.any(func(e):return e[0]=="_contact_fx"),"Dynamic impact survives production demo codec")
	if not frame.is_empty():
		frame.events=[["_contact_fx",[Vector3.ZERO,Vector3.ZERO,0]]];check(not g.demos.valid_frame(frame),"Demo parser rejects invalid contact normals")
		frame.events=[["_contact_fx",[Vector3.ZERO,Vector3.UP,7]]];check(not g.demos.valid_frame(frame),"Demo parser rejects invalid contact styles")
	fx.particles.clear();fx.emission_budget=64
	for i in 400:g.clock+=.1;g.effects.world_hit(Fixture.point(i%30,-4),Vector3.BACK,0)
	check(fx.particles.size()<=fx.MAX_PARTICLES and g.effects.surface_hits.size()<=128,"Sustained impacts keep bounded particle and contact budgets")
	if "--render" in OS.get_cmdline_user_args():await render_feedback()
	g.headless=true;g.disconnect_game();g.free()
	print("SHARED_FEEDBACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func render_feedback():
	g.effects.clear()
	for item in fx.shapes:item.node.queue_free()
	fx.shapes.clear();fx.particles.clear()
	await process_frame
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	g.xr_rig.hide();g.xr_rig.enabled=false
	for actor in g.fighters.values():actor.hide()
	for child in g.get_node("Map").get_children():if child is Node3D:child.hide()
	var camera:=Camera3D.new();g.add_child(camera);camera.position=Fixture.point(0,7)+Vector3.UP*2.5;camera.look_at(Fixture.point(0,-3)+Vector3.UP);camera.make_current();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8
	camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("252c35");camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE;camera.environment.ambient_light_energy=.6
	Art.box(g,Fixture.point(0,-3)+Vector3(0,-.15,0),Vector3(9,.2,3),Art.material(Color("535c65")))
	var light:=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-25,-25,0);light.light_energy=2
	fx.particles.clear();fx.emission_budget=64
	for i in 4:
		var at:=Fixture.point(-3+i*2,-3)+Vector3.UP
		var label:=Label3D.new();g.add_child(label);label.position=at+Vector3(0,1.2,0);label.text=["BLOOD / FLINCH","BULLET","ENERGY","EXPLOSIVE"][i];label.font_size=36;label.pixel_size=.004
		if i==0:
			if g.fighters[-1].avatar:g.fighters[-1].avatar.hide()
			if g.fighters[-1].label:g.fighters[-1].label.hide()
			var body:=Art.marine(Color("72979d"));g.add_child(body);body.position=at-Vector3.UP;body.hurt(Vector3.RIGHT,40);body.animate(.02,Vector3.ZERO,"stand",1.65,true,{},false)
			g.clock+=1;g.effects.hit(-999,at+Vector3(0,.2,.25),Vector3.RIGHT,40,false,false,125)
		else:
			Art.box(g,at-Vector3.BACK*.06,Vector3(1.3,1.7,.1),Art.material(Color("48515a")))
			g.clock+=1;fx.emission_budget=64;g.effects.world_hit(at,Vector3.BACK,[0,0,4,3][i])
	fx._process(.08);fx.set_process(false)
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results/shared-feedback");root.get_texture().get_image().save_png("res://test-results/shared-feedback/impacts.png")
