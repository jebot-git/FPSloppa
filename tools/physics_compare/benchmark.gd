extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var world:Node3D
var fighters:Array=[]
var debris:Array=[]
var rows:Array=[]
var ticks:=0
var ray:PhysicsRayQueryParameters3D
var shape_query:PhysicsShapeQueryParameters3D
var tick_work:Array=[]
var process_times:Array=[]
var ray_times:Array=[]
var motion_times:Array=[]
var physics_times:Array=[]
var found_hits:=0
var started:=false
var last_begin:=0
var frame_times:Array=[]
func _initialize():run.call_deferred()
func run():
	Engine.physics_ticks_per_second=60;world=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(160,1,160))
	# Brush-like static cover; a triangle strip exercises mesh queries/seams.
	for i in 192:
		var body=Fixture.box(world,Vector3((i%16)*8-60,1.5,(i/16)*8-44),Vector3(2,3,2));body.collision_layer=1
	var terrain:=ConcavePolygonShape3D.new();var faces:=PackedVector3Array()
	for x in range(-20,20):
		for z in range(-20,20):
			var a:=Vector3(x*2.,-.02,z*2.);var b:=a+Vector3(2,0,0);var c:=a+Vector3(0,0,2);var d:=a+Vector3(2,0,2)
			faces.append_array([a,c,b,b,c,d])
	terrain.set_faces(faces);var terrain_body:=StaticBody3D.new();var terrain_shape:=CollisionShape3D.new();terrain_shape.shape=terrain;terrain_body.add_child(terrain_shape);world.add_child(terrain_body)
	for i in 16:
		var fighter=Fighter.new();fighter.setup(i,"Benchmark",Color.WHITE);world.add_child(fighter);fighter.position=Vector3((i%4)*12-18,.02,(i/4)*12-18);fighters.append(fighter)
	for i in 64:
		var body:=RigidBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.15,.3,.08);collision.shape=shape;body.add_child(collision)
		body.collision_layer=0;body.collision_mask=1;body.position=Vector3((i%8)*1.2-4,2+i*.03,(i/8)*1.2-4);world.add_child(body);debris.append(body)
	ray=PhysicsRayQueryParameters3D.new();ray.collision_mask=3
	shape_query=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.65;shape_query.shape=capsule;shape_query.collision_mask=1
	await physics_frame;await physics_frame;started=true
func _physics_process(_delta:float) -> bool:
	if not started:return false
	var begin:=Time.get_ticks_usec()
	if ticks>=120 and last_begin>0:frame_times.append((begin-last_begin)/1000.0)
	last_begin=begin
	var space:=world.get_world_3d().direct_space_state
	for i in fighters.size():
		var actor=fighters[i]
		if ticks%120==0:actor.position=Vector3((i%4)*12-18,.02,(i/4)*12-18);actor.velocity=Vector3.ZERO
		actor.simulate(Vector2(sin((ticks+i)*.03),-1).normalized(),i*.4,false,1./60,ticks%90==0)
	var motion_end:=Time.get_ticks_usec()
	for i in 128:
		var actor=fighters[i%16];ray.from=actor.position+Vector3.UP*1.2;ray.to=ray.from+Vector3(sin(i*.77+ticks*.01),-.2,cos(i*.77+ticks*.01))*40;ray.exclude=[actor.get_rid()]
		if not space.intersect_ray(ray).is_empty():found_hits+=1
	for i in 16:
		shape_query.transform=Transform3D(Basis.IDENTITY,fighters[i].position+Vector3.UP*.83);shape_query.motion=Vector3(0,-.8,-.2);space.cast_motion(shape_query)
	var query_end:=Time.get_ticks_usec()
	if ticks%60==0:
		for i in debris.size():debris[i].position=Vector3((i%8)*1.2-4,2+i*.03,(i/8)*1.2-4);debris[i].linear_velocity=Vector3(2,1,1);debris[i].sleeping=false
	if ticks>=120:
		motion_times.append((motion_end-begin)/1000.0);ray_times.append((query_end-motion_end)/1000.0);tick_work.append((Time.get_ticks_usec()-begin)/1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	ticks+=1
	if ticks>=720:
		var report={"engine":ProjectSettings.get_setting("physics/3d/physics_engine"),"backend":space.get_class(),"ticks":ticks,"rays_hit":found_hits,"movement_ms":distribution(motion_times),"queries_ms":distribution(ray_times),"script_physics_ms":distribution(tick_work),"physics_monitor_ms":distribution(physics_times),"headless_frame_interval_ms":distribution(frame_times),"engine_version":Engine.get_version_info().string,"fixture":{"players":16,"rays_per_tick":128,"shape_casts_per_tick":16,"debris":64,"static_boxes":193,"terrain_triangles":3200}}
		var args:=OS.get_cmdline_user_args();var output:String=args[0] if not args.is_empty() else "/tmp/physics-benchmark.json"
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("PHYSICS_BENCHMARK ",JSON.stringify(report));world.free();quit()
	return false
func distribution(values:Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
