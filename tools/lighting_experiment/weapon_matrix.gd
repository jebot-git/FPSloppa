extends SceneTree
## Real weapon definitions and FX, real production map receiver/pool, deterministic stills.
const OUT="res://test-results/weapon-emission/"
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const FX=preload("res://deathmatch/experimental/visuals.gd")
const Pool=preload("res://deathmatch/lighting/weapon_pool.gd")
const Emission=preload("res://deathmatch/lighting/weapon_emission.gd")
const Art=preload("res://deathmatch/art.gd")
var stage: Node3D
var camera: Camera3D
var pool
var fx
var material: ShaderMaterial
var checks: Array=[]
var failures: Array=[]
var records: Array=[]
class SilentAudio extends RefCounted:
	func play(_sound,_position,_gain):pass
class AbilityGame extends Node3D:
	const Art=preload("res://deathmatch/art.gd")
	var headless:=false
	var match_mode:={"COLORS":[Color.RED,Color.BLUE]}
	var spatial=SilentAudio.new()
	var pool
	func _weapon_illumination(a,b,recipe,key=0):pool.emit_source(a,b,recipe,key)

func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok:failures.append(label);push_error(label)
func shot(name: String) -> Image:
	for i in 3:await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();image.save_png(OUT+name+".png");return image
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			if maxf(absf(cb.r-ca.r),maxf(absf(cb.g-ca.g),absf(cb.b-ca.b)))>.018:count+=1
	return count
func surface(pos: Vector3,size: Vector3) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=material;stage.add_child(node);node.position=pos;return node
func reset_fx() -> void:
	pool.clear()
	if is_instance_valid(fx):fx.free()
	fx=FX.new();stage.add_child(fx);fx.set_process(false);fx.illumination.connect(pool.emit_source)
func catalogue() -> Array:
	var rows: Array=[];var rules:=Rules.new()
	for profile in Rules.IDS:
		rules.select(profile)
		for slot in rules.table.size():
			for alt in ([false,true] if profile=="ut99" else [false]):
				rows.append({"profile":profile,"slot":slot,"alt":alt,"definition":rules.data(slot,alt).duplicate(true),"label":profile+" / "+rules.data(slot).name+(" ALT" if alt else "")})
	# Resolve every owned TF weapon through the actual class rules, not a copied list.
	var arena=load("res://deathmatch/arena.tscn").instantiate()
	arena.headless=true
	root.add_child(arena);arena.set_process(false);arena.set_physics_process(false)
	arena.match_mode.kind="tf";arena.armory.select("quake")
	for role in arena.match_mode.fortress.CLASSES:
		arena.players[1]={"tf_class":role}
		for slot in arena.match_mode.fortress.CLASSES[role].owned:
			var definition: Dictionary=arena.match_mode.fortress.weapon_data(1,slot).duplicate(true)
			rows.append({"profile":"quake","slot":slot,"alt":false,"definition":definition,"label":"TF "+role+" / "+definition.name})
	arena.match_mode.kind="dm";arena.armory.select("ut99")
	var charged: Dictionary=arena.variant_combat.definition(1,1,{"alternate":true,"scale":8})
	rows.append({"profile":"ut99","slot":1,"alt":true,"definition":charged,"label":"UT charged BIO / 8 cells"})
	rows.append({"profile":"ut99","slot":6,"alt":false,"definition":arena.armory.data(6).duplicate(),"label":"UT charged ROCKET / 6 rockets","volley":6})
	arena.match_mode.kind="dm";arena.armory.select("doom")
	var live_pool=arena.get_node_or_null("Map/MapRuntime/WeaponLighting")
	check(live_pool!=null and not live_pool.receivers.is_empty(),"Live arena installs map lighting")
	if live_pool:
		var at: Vector3=arena.spawn_points[0]+Vector3.UP
		arena._projectile_spawn(9001,1,7,at,Vector3.FORWARD,0,0)
		arena.projectiles[9001].position+=Vector3.FORWARD*.4
		arena._update_projectile_visuals(.035)
		check(not live_pool.sources.is_empty(),"Live Doom plasma render path emits illumination")
		var key: int=arena.projectiles[9001].node.get_instance_id()
		arena._projectile_end(9001,at,7)
		check(not live_pool.sources.any(func(item):return item.key==key),"Live impact removes its moving source")
		arena.match_mode.kind="tf";arena.armory.select("quake");live_pool.clear()
		arena._impacts(at,PackedVector3Array([at+Vector3.FORWARD*4]),7)
		check(not live_pool.sources.is_empty(),"Live TF heavy hitscan produces muzzle illumination")
		var was_xr: bool=arena.xr_rig.enabled
		for vr in [false,true]:
			arena.xr_rig.enabled=vr;live_pool.clear()
			var eye: Vector3=arena.get_viewport().get_camera_3d().global_position
			for i in 5:live_pool.emit_source(eye+Vector3.FORWARD*2,eye+Vector3.FORWARD*3,Emission.recipe("plasma"),i+1)
			live_pool._process(0)
			check(arena.is_vr()==vr and live_pool.selected_count==2,("VR" if vr else "Desktop")+": live arena shares the two-effect cap")
			check(live_pool.receivers.all(func(receiver):return receiver.get_shader_parameter("weapon_count")==2),("VR" if vr else "Desktop")+": map shaders receive exactly two sources")
		arena.xr_rig.enabled=was_xr
		arena._clear_map_players()
		check(live_pool.sources.is_empty(),"Live transition clears transient illumination")
	arena.players.clear();arena.free();camera.make_current()
	return rows
func scenario(row: Dictionary,index: int) -> void:
	reset_fx();seed(1234)
	var d: Dictionary=row.definition;var kind:=Emission.kind(row.profile,row.slot,d)
	if row.profile=="ut99" and row.slot==7 and row.alt:kind="pulse_beam"
	var noop: bool=d.get("zoom",false) or (row.profile=="ut99" and row.slot==11 and row.alt) or kind in ["melee","hammer"]
	var start:=Vector3(-2,.55,0);var end:=Vector3(2,.55,0)
	var projectile: Node3D
	if not noop:
		if kind=="flame":
			fx.streak(PackedVector3Array([start,end]),Emission.recipe(kind).color,.035,.14)
			fx.illumination.emit(start,end,Emission.recipe(kind),0)
		elif kind in ["hitscan","sniper","rail","shock_beam","beam","pulse_beam"]:
			var ends:=PackedVector3Array()
			for i in int(d.get("pellets",1)):ends.append(end+Vector3(0,0,(i-(d.get("pellets",1)-1)*.5)*.022))
			fx.impacts(row.profile,start,ends,row.slot,d)
		else:
			if not d.has("kind"):d=d.duplicate();d.kind=kind
			projectile=fx.projectile(row.profile,d);stage.add_child(projectile);projectile.position=Vector3(0,maxf(.18,d.get("radius",.1)+.04),0) if Emission.recipe(kind).get("radius",0)<1 else Vector3(0,.55,0)
			projectile.set_meta("trail_position",projectile.position-Vector3.RIGHT*.8)
			fx.travel(projectile,Vector3.RIGHT*maxf(10,d.get("speed",20)),.035,false)
			for j in range(1,row.get("volley",1)):
				var other: Node3D=fx.projectile(row.profile,d);projectile.add_child(other);other.position=Vector3(0,float(j)*.15,0);other.set_meta("trail_position",other.global_position-Vector3.RIGHT*.6)
				fx.travel(other,Vector3.RIGHT*18,.035,false)
	fx._process(.0)
	pool.update_receivers()
	var count: int=pool.selected_count
	for receiver in pool.receivers:receiver.set_shader_parameter("weapon_count",0)
	var slug:="%02d"%index
	var baseline:=await shot(slug+"-off")
	pool.update_receivers()
	var lit:=await shot(slug+"-on")
	var delta:=changed(baseline,lit)
	var expected: bool=not noop and (kind in ["hitscan","sniper","rail","shock_beam","beam","pulse_beam","flame"] or Emission.recipe(kind).get("energy",0)>0)
	check((count>0)==expected,row.label+": appropriate illumination")
	check(delta>8 if expected else delta==0,row.label+": rendered surface response")
	check(stage.find_children("*","Light3D",true,false).is_empty(),row.label+": no light nodes")
	check(fx.particles.size()<=FX.MAX_PARTICLES and fx.shapes.size()<=FX.MAX_SHAPES,row.label+": bounded visuals")
	records.append({"label":row.label,"kind":kind,"alternate":row.alt,"sources":count,"changed_pixels":delta,"image":slug+"-on.png"})
	if projectile:
		reset_fx();fx.burst(row.profile,Vector3(0,.18,0),row.slot,kind,d);fx._process(0)
		pool.update_receivers();var burst_count: int=pool.selected_count
		for receiver in pool.receivers:receiver.set_shader_parameter("weapon_count",0)
		var impact_off:=await shot(slug+"-impact-off");pool.update_receivers();var impact_on:=await shot(slug+"-impact-on")
		check(changed(impact_off,impact_on)>8 if burst_count>0 else changed(impact_off,impact_on)==0,row.label+": impact illumination")
		pool.clear();fx.travel(projectile,Vector3.ZERO,.035,true);check(pool.sources.is_empty(),row.label+": stopped projectile does not light indefinitely")
		projectile.free()
	pool._process(1.0);check(pool.sources.is_empty() and pool.selected_count==0,row.label+": lighting expires")
func occlusion() -> void:
	reset_fx();var source:=Emission.recipe("bfg")
	pool.world.head=pool.world.box(AABB(Vector3(-.01,0,-5),Vector3(.02,5,10)),pool.world.head)
	pool.emit_source(Vector3(-.6,.6,0),Vector3(-.6,1.2,0),source)
	pool.update_receivers();var lit:=await shot("wall-on")
	pool.clear();var off:=await shot("wall-off")
	var blocked:=Vector2i(camera.unproject_position(Vector3(.5,.02,0)));var clear:=Vector2i(camera.unproject_position(Vector3(-1,.02,0)))
	check(lit.get_pixelv(blocked)==off.get_pixelv(blocked),"2 cm wall blocks real BFG illumination")
	check(lit.get_pixelv(clear).g>off.get_pixelv(clear).g+.02,"BFG still illuminates visible side")
	pool.world.head=-1;pool.world.planes.clear();pool.world.children.clear()
func extras() -> void:
	var mock:=AbilityGame.new();mock.pool=pool;stage.add_child(mock)
	for kind in ["sentry_fire","ba2_cannon","flame","explosion","napalm"]:
		reset_fx()
		var abilities=preload("res://deathmatch/modes/fortress_fx.gd").new();abilities.game=mock;mock.add_child(abilities)
		abilities.emit(kind,Vector3(-1,.5,0),Vector3(1,.5,0),0)
		# Freeze the tween state for a matched off/on comparison.
		for tween in get_processed_tweens():tween.pause()
		pool.update_receivers();check(pool.selected_count>0,kind+": actual ability FX emits illumination")
		for receiver in pool.receivers:receiver.set_shader_parameter("weapon_count",0)
		var baseline:=await shot(kind+"-off");pool.update_receivers();var lit:=await shot(kind+"-on")
		check(changed(baseline,lit)>8,kind+": rendered ability illumination")
		check(abilities.find_children("*","Light3D",true,false).is_empty(),kind+": no light nodes")
		abilities.free()
	reset_fx();fx.combo(Vector3(0,.5,0));fx._process(.05);pool.update_receivers()
	check(pool.selected_count==1,"Shock combo emits bounded purple light")
	await shot("shock-combo");mock.free()
func doors() -> void:
	reset_fx();pool.world.planes.clear();pool.world.children.clear();pool.world.head=-1
	var bounds:=AABB(Vector3(-.01,0,-5),Vector3(.02,3,10));var head: int=pool.world.box(bounds)
	var door:=StaticBody3D.new();stage.add_child(door)
	pool.brushes=[{"node":door,"head":head,"local":Transform3D.IDENTITY,"bounds":bounds}]
	var source:=Emission.recipe("bfg");pool.emit_source(Vector3(-.6,.6,0),Vector3(-.6,1.2,0),source)
	pool.update_receivers();var closed:=await shot("door-closed")
	door.position.y=4;pool.update_receivers();var opened:=await shot("door-open")
	var point:=Vector2i(camera.unproject_position(Vector3(.5,.02,0)))
	check(opened.get_pixelv(point).g>closed.get_pixelv(point).g+.02,"Moving brush opens correct light path")
	door.position.y=0;door.rotation.y=.25;pool.update_receivers();var rotated:=await shot("door-rotated")
	check(rotated.get_pixelv(point)==closed.get_pixelv(point),"Rotated brush still blocks light")
	pool.clear();door.free();pool.brushes.clear();pool.world.planes.clear();pool.world.children.clear();pool.world.head=-1
func stress() -> void:
	reset_fx()
	for i in 300:pool.emit_source(Vector3(i*.005,.5,0),Vector3(i*.005,.5,.1),Emission.recipe("plasma"),i+1)
	check(pool.sources.size()==64,"300 projectile sources bounded to 64 candidates")
	pool.update_receivers();check(pool.selected_count==2,"Desktop selects at most two sources")
	check(material.get_shader_parameter("weapon_count")==2,"Both selected sources reach the shader")
	pool.emit_source(Vector3.ZERO,Vector3.ZERO,Emission.recipe("rocket"),300);pool.remove_source(300)
	check(not pool.sources.any(func(item):return item.key==300),"Destroyed projectile removed immediately")
	pool.clear();check(material.get_shader_parameter("weapon_count")==0,"Map teardown disables receivers")
	var corrupt=Pool.TreeData.new();corrupt.planes.append(Plane(Vector3.RIGHT,0));corrupt.children.append(Vector2i(0,0))
	check(corrupt.prune_into(Pool.TreeData.new(),0,AABB(-Vector3.ONE,Vector3.ONE*2))==-2 and corrupt.visits<4500,"Cyclic BSP pruning bounded and fails dark")
func map_test() -> void:
	reset_fx()
	for node in stage.get_children():
		if node is MeshInstance3D:node.hide()
	var level=preload("res://deathmatch/maps/loader.gd").read("res://maps/qsrc_dm6.bsp");stage.add_child(level)
	preload("res://deathmatch/maps/filtering.gd").new().apply(level,2,true,1)
	pool.configure(level,"res://maps/qsrc_dm6.bsp")
	check(pool.available and not pool.receivers.is_empty(),"Actual DM6 baked materials registered")
	camera.position=Vector3(47.25,2.03,-7.25);var dir:=Vector3(.194305,-.089638,.976837).normalized();camera.look_at(camera.position+dir)
	var baseline:=await shot("dm6-off")
	pool.emit_source(camera.position+dir*.5,camera.position+dir*4,Emission.recipe("plasma"));pool.update_receivers()
	var lit:=await shot("dm6-on");check(changed(baseline,lit)>100,"Actual dark DM6 receives weapon illumination")
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	var metrics: Array=[]
	for count in [0,2,2,0]:
		var samples: Array=[];var updates: Array=[];var draws: Array=[]
		for frame in 390:
			pool.clear()
			for i in count:pool.emit_source(camera.position+dir*.5+Vector3.UP*i*.3,camera.position+dir*4+Vector3.UP*i*.3,Emission.recipe("plasma"))
			var began:=Time.get_ticks_usec();pool.update_receivers();var elapsed:=(Time.get_ticks_usec()-began)/1000.0
			await process_frame
			if frame>=90:
				samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));updates.append(elapsed);draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.sort();updates.sort();draws.sort();metrics.append({"count":count,"gpu_median_ms":samples[150],"update_median_ms":updates[150],"draws":draws[150]})
	FileAccess.open(OUT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	pool.clear();level.free()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Weapon matrix requires a graphical renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(800,600);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	stage=Node3D.new();root.add_child(stage)
	camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(4,4.5,6);camera.look_at(Vector3(0,.4,0));camera.fov=48;camera.make_current()
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("050608");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=0;stage.add_child(env)
	material=ShaderMaterial.new();material.shader=preload("res://deathmatch/maps/baked_light.gdshader")
	var image:=Image.create(2,2,false,Image.FORMAT_RGB8);image.fill(Color(.3,.32,.35));var texture:=ImageTexture.create_from_image(image)
	material.set_shader_parameter("base_texture",texture)
	image=Image.create(4,4,false,Image.FORMAT_RGB8);image.fill(Color(.006,.006,.006));material.set_shader_parameter("bake_texture",ImageTexture.create_from_image(image))
	surface(Vector3(0,-.1,0),Vector3(10,.2,8));surface(Vector3(0,1,-2),Vector3(10,2,.1))
	pool=Pool.new();stage.add_child(pool);pool.set_process(false);pool.available=true;pool.receivers=[material];pool.world.head=-1
	var rows:=catalogue()
	for i in rows.size():await scenario(rows[i],i)
	await extras();await occlusion();await doors();stress();await map_test()
	check(stage.find_children("*","Light3D",true,false).is_empty(),"Weapon render fixture contains no realtime lights")
	var report:={"checks":checks,"failures":failures,"weapons":records,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"effect_limit":{"desktop":Pool.MAX_EFFECTS,"vr":Pool.MAX_EFFECTS}}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WEAPON_EMISSION_RESULT ",records.size()," cases / ",checks.size()," checks / failures ",failures)
	stage.free();quit(0 if failures.is_empty() else 1)
