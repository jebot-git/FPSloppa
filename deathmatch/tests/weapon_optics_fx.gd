extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Scope=preload("res://deathmatch/vr/sniper_scope.gd")
const FX=preload("res://deathmatch/experimental/visuals.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var failures: Array=[]
var checks:=0
var report: Dictionary={}
var stage: Node3D
var scope
var cam: Camera3D
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
	print("PASS " if ok else "FAIL ",label)
func frames(count: int=4) -> void:
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func save_view(view: Viewport,name: String) -> void:view.get_texture().get_image().save_png("res://test-results/weapon-variants/"+name+".png")
func run() -> void:
	root.size=Vector2i(1000,800);stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("18232c");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.8;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-30,0);stage.add_child(light)
	cam=Camera3D.new();stage.add_child(cam);cam.position=Vector3(0,0,.20);cam.fov=75;cam.near=.015;cam.make_current()
	var rifle:=Art.weapon(9,2,"ut99");stage.add_child(rifle);rifle.position=-Vector3(rifle.get_meta("scope_rear"))
	var shot_y: float=rifle.position.y+Art.muzzle(9,"ut99").y
	var target:=Art.box(stage,Vector3(0,shot_y,-20),Vector3(.35,.35,.05),Art.material(Color("ed3827")))
	for i in [-2,-1,1,2]:Art.box(stage,Vector3(i*.55,shot_y,-20),Vector3(.2,.5,.1),Art.material(Color("8fc17e")))
	Art.box(stage,Vector3(0,shot_y,-20.2),Vector3(5,4,.1),Art.material(Color("a0afba")))
	var guide=preload("res://deathmatch/vr/aim_guide.gd").new();stage.add_child(guide)
	for profile in ["ut99","tf_sniper"]:
		guide.update(Transform3D.IDENTITY,9,true,profile)
		check(not guide.visible,profile+": sniper helper beam is removed")
	guide.update(Transform3D.IDENTITY,2,true,"doom")
	check(guide.visible,"Other weapons retain their aim guide")
	guide.free()
	scope=Scope.new();stage.add_child(scope)
	var shot:=Transform3D(Basis.IDENTITY,rifle.to_global(Art.muzzle(9,"ut99")))
	scope.update_view(rifle,[cam.global_transform],shot,true)
	check(scope.active,"Scope activates simply by looking through rear lens")
	check(scope.viewport.world_3d==stage.get_world_3d(),"Scope shares game world")
	check(cam.fov==75,"Main camera FOV is untouched")
	check(not scope.viewport.use_xr,"Optic uses a separate non-XR render target")
	check((scope.camera.cull_mask&Scope.SCOPE_LAYER)==0,"Optic excludes its lens and weapon to prevent recursion")
	await frames(8);save_view(root,"scope-through-lens");save_view(scope.viewport,"scope-axis")
	# Compare a neutral patch in the rendered lens to the source viewport.
	var patch:Vector3=scope.lens.to_global(Vector3(scope.lens.mesh.size.x*.15,scope.lens.mesh.size.y*.15,0))
	var rendered:Image=root.get_texture().get_image()
	var screen_patch:Vector2i=Vector2i(cam.unproject_position(patch)*Vector2(rendered.get_size())/root.get_visible_rect().size)
	var shown:Color=rendered.get_pixelv(screen_patch)
	var source:Color=scope.viewport.get_texture().get_image().get_pixel(333,179)
	check(shown.get_luminance()<=source.get_luminance()+.03 and shown.get_luminance()>source.get_luminance()*.5,"Scope avoids gamma-brightening while keeping the scene readable")
	report.lens_luminance={"source":source.get_luminance(),"displayed":shown.get_luminance()}
	var pixel: Color=scope.viewport.get_texture().get_image().get_pixel(256,256)
	check(pixel.r>pixel.g*1.3,"Rendered optic center agrees with bullet axis")
	var world_target: Vector3=target.global_position
	var axis_error: float=scope.camera.unproject_position(world_target).distance_to(Vector2(256,256))
	var test_view:=SubViewport.new();test_view.size=Vector2i(512,512);test_view.world_3d=stage.get_world_3d();stage.add_child(test_view)
	var test_camera:=Camera3D.new();test_view.add_child(test_camera);test_camera.fov=12;test_camera.cull_mask=scope.camera.cull_mask;test_camera.global_transform=cam.global_transform;test_camera.rotate_y(deg_to_rad(3));test_camera.make_current()
	test_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await frames();save_view(test_view,"scope-head-camera")
	var head_error:=test_camera.unproject_position(world_target).distance_to(Vector2(256,256))
	check(axis_error<1 and head_error>80,"Weapon-axis camera stays on shot; head-following zoom drifts with gaze")
	report.camera_comparison={"weapon_axis_error_pixels":axis_error,"head_following_error_pixels_at_3_degrees":head_error,"resolution":[512,512],"selected":"one weapon-axis camera"}
	# Compare one optical pass with duplicated stereo optical passes after warmup.
	RenderingServer.viewport_set_measure_render_time(scope.viewport.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(test_view.get_viewport_rid(),true)
	test_camera.global_transform=scope.camera.global_transform
	for stereo in [false,true]:
		test_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if stereo else SubViewport.UPDATE_DISABLED
		await frames(8);var gpu:=0.0;var cpu:=0.0
		for i in 12:
			await frames(1)
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(scope.viewport.get_viewport_rid())
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(scope.viewport.get_viewport_rid())
			if stereo:
				gpu+=RenderingServer.viewport_get_measured_render_time_gpu(test_view.get_viewport_rid());cpu+=RenderingServer.viewport_get_measured_render_time_cpu(test_view.get_viewport_rid())
		report.camera_comparison["dual_pass" if stereo else "single_pass"]={"mean_gpu_ms":gpu/12,"mean_cpu_ms":cpu/12,"pixels":512*512*(2 if stereo else 1)}
	test_view.free()
	var optic:=Transform3D(Basis.IDENTITY,rifle.to_global(rifle.get_meta("scope_rear")))
	for side in [-1,1]:
		var head:=Transform3D(Basis.IDENTITY,optic.origin+Vector3(side*.032,0,.16))
		var eyes: Array=[]
		for offset in [-.032,.032]:eyes.append(head*Transform3D(Basis.IDENTITY,Vector3(offset,0,0)))
		scope.update_view(rifle,eyes,shot,true);check(scope.active,"Either eye can operate the scope: "+str(side))
	for point in [Vector3(.10,0,.16),Vector3(0,0,-.1),Vector3(0,0,.8)]:
		scope.update_view(rifle,[Transform3D(Basis.IDENTITY,optic.origin+point)],shot,true);check(not scope.active,"Eye outside usable lens volume is rejected "+str(point))
	scope.update_view(rifle,[cam.global_transform],shot,false);check(not scope.active and scope.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden/menu/blocked gun suspends optical rendering")
	var wall:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,2,.04);collider.shape=box;wall.add_child(collider);stage.add_child(wall);wall.position.z=-.45
	await physics_frame;await physics_frame
	scope.update_view(rifle,[cam.global_transform],shot,true);check(not scope.active,"Wall between eye and optic camera prevents seeing through world")
	wall.free();scope.disable();rifle.hide()
	# Local-only cosmetics have hard limits and expire under stress.
	var fx:=FX.new();stage.add_child(fx)
	for i in 20:
		fx.emission_budget=64
		for j in 64:fx.particle(Vector3.ZERO,Vector3.ZERO,Color.WHITE,.1,.05)
	check(fx.particles.size()==FX.MAX_PARTICLES,"Particle pool stays capped under sustained fire")
	for i in 90:fx.globe(Vector3.ZERO,Color.WHITE,.1,.05)
	check(fx.shapes.size()==FX.MAX_SHAPES,"Beam/burst geometry pool stays capped")
	fx._process(.1);check(fx.particles.is_empty() and fx.shapes.is_empty(),"Cosmetic pools expire all completed effects")
	fx.free()
	await render_fx_gallery()
	check(checks>=17,"All optics and FX scenarios completed")
	report.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures})
	FileAccess.open("res://test-results/weapon-variants/optics-fx.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPTICS_FX_RESULT ",JSON.stringify(report));stage.free();quit(0 if failures.is_empty() else 1)
func render_fx_gallery() -> void:
	for child in stage.get_children():
		if child is MeshInstance3D:child.hide()
	cam.position=Vector3(0,6,12);cam.look_at(Vector3.ZERO);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=15
	var fx:=FX.new();stage.add_child(fx)
	var rules:=Rules.new()
	var labels:=["QUAKE · FIRE / SMOKE","QUAKE · LIGHTNING","UT · SHOCK COMBO","UT · BIO / PULSE","UT · FLAK / RIPPER","UT · REDEEMER"]
	for i in 6:
		var pos:=Vector3((i%3-1)*4.7,0,(i/3-.5)*5)
		var label:=Label3D.new();label.text=labels[i];label.font_size=24;label.pixel_size=.005;label.position=pos+Vector3(0,-.35,1.2);stage.add_child(label)
		fx.emission_budget=64
		match i:
			0:fx.burst("quake",pos,6,"rocket")
			1:fx.impacts("quake",pos-Vector3(1.6,0,0),PackedVector3Array([pos+Vector3(1.6,0,0)]),8)
			2:fx.combo(pos)
			3:
				fx.burst("ut99",pos,1,"bio");fx.impacts("ut99",pos-Vector3(1.6,0,0),PackedVector3Array([pos+Vector3(1.6,0,0)]),7)
			4:
				rules.select("ut99")
				for slot in [4,10]:
					var node:=fx.projectile("ut99",rules.data(slot));stage.add_child(node);node.position=pos+Vector3((slot-7)*.25,.1,0);node.scale=Vector3.ONE*3
				fx.burst("ut99",pos,4,"flak_shell")
			5:fx.burst("ut99",pos,8,"warhead")
	# Freeze a readable mid-burst frame rather than timing screenshot against wall clock.
	fx.set_process(false);fx._process(.10)
	await frames(3);save_view(root,"weapon-effects")
