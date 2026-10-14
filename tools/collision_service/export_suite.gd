extends SceneTree
## Export the real authoritative collider graph plus real-engine query oracles.
## No renderer, server socket, AI, or gameplay effects are started.
class MovementProbe extends CharacterBody3D:
	signal completed(result:Dictionary)
	var phase:=0
	var command:=Vector3.ZERO
	var cold_ms:=0.
	var skipped_ticks:=0
	func _physics_process(delta:float) -> void:
		# The engine may deliver the bootstrap tick at its previous frequency.
		# Never compare a 60 Hz engine move with a 30 Hz native move.
		if absf(delta-1./30)>0.000001:
			skipped_ticks+=1
			if skipped_ticks>10:push_error("Movement oracle did not reach 30 Hz");get_tree().quit(1)
			return
		var began:=Time.get_ticks_usec()
		if phase==0:
			velocity=Vector3.ZERO;move_and_slide();apply_floor_snap();cold_ms=(Time.get_ticks_usec()-began)/1000.;phase=1;return
		var start:=position;velocity=command;move_and_slide();apply_floor_snap()
		var result:={"start":start,"position":position,"velocity":velocity,"grounded":is_on_floor(),"ms":(Time.get_ticks_usec()-began)/1000.,"cold_ms":cold_ms,"delta":delta,"skipped_ticks":skipped_ticks}
		set_physics_process(false);completed.emit(result)
const Map=preload("res://tools/voxel_battle/map.gd")
var output:="/tmp/cq-collision-world.bin"
var trace_path:="/tmp/cq-collision-traces.bin"
var metadata_path:="/tmp/cq-collision-oracle.json"
var world:Node3D
var map
var primitives:Array=[]
var traces:Array=[]
var bodies:Dictionary={}
var movement_deltas:Array=[]
var skipped_movement_ticks:=0
var stair_ramps:Dictionary={}
var timings:Dictionary={"ray":[],"cylinder":[],"sphere":[],"capsule":[],"movement":[],"movement_cold":[]}
func _initialize():
	Engine.physics_ticks_per_second=30
	Engine.physics_jitter_fix=0.
	run.call_deferred()
func vector(f:FileAccess,v:Vector3) -> void:
	f.store_double(v.x);f.store_double(v.y);f.store_double(v.z)
func basis(f:FileAccess,b:Basis) -> void:
	vector(f,b.x);vector(f,b.y);vector(f,b.z)
func shape_row(shape:Shape3D,transform:Transform3D,id:int,mask:int) -> Dictionary:
	var scale:Vector3=transform.basis.get_scale();var rotation:=transform.basis.orthonormalized()
	var row:={"kind":0,"id":id,"mask":mask,"center":transform.origin,"half":Vector3.ZERO,"radius":0.,"height":0.,"basis":rotation}
	if shape is BoxShape3D:row.half=shape.size*scale*.5
	elif shape is CylinderShape3D:
		assert(absf(scale.x-scale.z)<.0001);row.kind=1;row.radius=shape.radius*scale.x;row.height=shape.height*scale.y
	elif shape is SphereShape3D:row.kind=2;row.radius=shape.radius*scale.x
	elif shape is CapsuleShape3D:row.kind=3;row.radius=shape.radius*scale.x;row.height=shape.height*scale.y
	else:push_error("Unsupported exported shape: "+shape.get_class());quit(1)
	return row
func write_shape(f:FileAccess,row:Dictionary) -> void:
	f.store_32(row.kind);f.store_32(row.id);f.store_32(row.mask);vector(f,row.center);vector(f,row.half);f.store_double(row.radius);f.store_double(row.height);basis(f,row.basis);vector(f,Vector3.ZERO)
func collect(node:Node) -> void:
	if node is StaticBody3D:
		var ids:Array=[]
		for child in node.get_children():
			if child is CollisionShape3D and not child.disabled:
				if child.shape is HeightMapShape3D:ids.append(1)
				else:
					var id:=primitives.size()+2;ids.append(id);primitives.append(shape_row(child.shape,child.global_transform,id,node.collision_layer))
		bodies[node.get_instance_id()]=ids
	for child in node.get_children():collect(child)
func ray_hit(space,start:Vector3,delta:Vector3,mask:int=1) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(start,start+delta,mask);q.hit_from_inside=true;q.hit_back_faces=true
	return space.intersect_ray(q)
func add_query(space,kind:int,start:Vector3,delta:Vector3,label:String) -> void:
	var shape:Shape3D
	if kind==1:shape=CylinderShape3D.new();shape.radius=.3;shape.height=1.65
	elif kind==2:shape=SphereShape3D.new();shape.radius=.08
	elif kind==3:shape=CapsuleShape3D.new();shape.radius=.3;shape.height=1.7
	else:shape=BoxShape3D.new();shape.size=Vector3.ONE
	var row:=shape_row(shape,Transform3D(Basis.IDENTITY,start),0,1);row.kind=kind
	var hit:=false;var fraction:=1.;var unsafe_fraction:=1.;var id:=-1;var normal:=Vector3.ZERO;var position:=start+delta
	var began:=Time.get_ticks_usec()
	if kind==0:
		var result:=ray_hit(space,start,delta)
		if not result.is_empty():
			hit=true;fraction=(result.position-start).dot(delta)/delta.length_squared();position=result.position;normal=result.normal
			var ids:Array=bodies.get(result.collider.get_instance_id(),[])
			if result.shape<ids.size():id=ids[result.shape]
	else:
		var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform.origin=start;q.collision_mask=1;q.margin=.001
		if not space.intersect_shape(q,1).is_empty():hit=true;fraction=0.;unsafe_fraction=0.
		else:
			q.motion=delta;var fractions:PackedFloat32Array=space.cast_motion(q);fraction=fractions[0];unsafe_fraction=fractions[1];hit=fraction<.999999
		position=start+delta*fraction
	var name:String=["ray","cylinder","sphere","capsule"][kind]
	timings[name].append((Time.get_ticks_usec()-began)/1000.)
	traces.append({"shape":row,"delta":delta,"hit":hit,"fraction":fraction,"unsafe_fraction":unsafe_fraction,"id":id,"normal":normal,"position":position,"velocity":Vector3.ZERO,"scenario":label})
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	for pair in [["--world",output],["--traces",trace_path],["--metadata",metadata_path]]:
		var at:=args.find(pair[0])
		if at>=0:
			if pair[0]=="--world":output=args[at+1]
			elif pair[0]=="--traces":trace_path=args[at+1]
			else:metadata_path=args[at+1]
	Engine.physics_ticks_per_second=30
	world=Node3D.new();root.add_child(world);map=Map.new();world.add_child(map);map.stair_ramps_enabled=args.has("--stair-ramps");map.build(false,true)
	if args.has("--stair-ramps"):
		stair_ramps=preload("res://tools/collision_service/stair_ramps.gd").apply(map)
		if stair_ramps.is_empty():quit(1);return
	collect(map)
	# Add the actual eight authored vehicle hull profiles as immutable
	# test obstacles. Vehicle dynamics/crew rules are not simulated in this suite.
	var Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
	for placement in Tanks.placements():
		var kind:String=placement.get("kind","rocket");var config:Dictionary=Tanks.PROFILES[kind]
		var vehicle:=StaticBody3D.new();vehicle.position=placement.position+Vector3.UP*(config.size.y*.5+.02);vehicle.rotation.y=placement.get("yaw",0.);world.add_child(vehicle)
		var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=config.size;collider.shape=box;vehicle.add_child(collider)
		collect(vehicle)
	await physics_frame;await physics_frame
	var space=world.get_world_3d().direct_space_state
	var heightmap:HeightMapShape3D=map.get_node("TerrainCollision").get_child(0).shape
	var terrain_body=map.get_node("TerrainCollision");terrain_body.collision_layer=1<<18
	await physics_frame
	var heights:=heightmap.map_data;var side:=heightmap.map_width;var spacing:=Map.Landscape.EXTENT/(side-1)
	# Infer the actual engine's quad diagonal from a strongly nonplanar cell.
	var best:=0.;var bx:=0;var bz:=0
	for z in range(1,side-2,7):
		for x in range(1,side-2,7):
			var diff:=absf(heights[z*side+x]+heights[(z+1)*side+x+1]-heights[z*side+x+1]-heights[(z+1)*side+x])
			if diff>best:best=diff;bx=x;bz=z
	var origin:=Vector3(-Map.LIMIT,0,-Map.LIMIT)
	var probe:=ray_hit(space,origin+Vector3((bx+.25)*spacing,2000,(bz+.25)*spacing),Vector3(0,-4000,0),1<<18)
	assert(not probe.is_empty())
	var a:=heights[bz*side+bx]*spacing;var b:=heights[bz*side+bx+1]*spacing;var c:=heights[(bz+1)*side+bx]*spacing;var d:=heights[(bz+1)*side+bx+1]*spacing
	var ad:=absf(probe.position.y-(.75*a+.25*d))<absf(probe.position.y-(.5*a+.25*b+.25*c))
	terrain_body.collision_layer=1;await physics_frame
	var f:=FileAccess.open(output,FileAccess.WRITE);f.store_buffer("CQCOLL1".to_ascii_buffer());f.store_8(0);f.store_32(side);f.store_32(side);f.store_double(spacing);vector(f,origin);f.store_32(1 if ad else 0);f.store_32(primitives.size())
	for height in heights:f.store_float(height*spacing)
	for row in primitives:write_shape(f,row)
	f.close()
	var rng:=RandomNumberGenerator.new();rng.seed=93713
	for i in 512:
		var p:=Vector3(rng.randf_range(-Map.LIMIT+5,Map.LIMIT-5),0,rng.randf_range(-Map.LIMIT+5,Map.LIMIT-5));var ground:=Map.Landscape.surface(p.x,p.z).x
		add_query(space,0,p+Vector3.UP*(ground+50),Vector3(0,-100,0),"terrain_down")
		add_query(space,0,p+Vector3.UP*(ground+1.5),Vector3(rng.randf_range(-150,150),rng.randf_range(-8,8),rng.randf_range(-150,150)),"terrain_los")
	for i in 256:
		var primitive:Dictionary=primitives[(i*937)%primitives.size()];var p:Vector3=primitive.center
		add_query(space,0,p+Vector3(20,0,0),Vector3(-40,0,0),"object_ray")
		add_query(space,1,p+Vector3(8,.5,0),Vector3(-16,0,0),"object_cylinder")
		add_query(space,2,p+Vector3(40,1,0),Vector3(-80,0,0),"ordnance")
	for i in 256:
		var p:=Vector3(rng.randf_range(-Map.LIMIT+5,Map.LIMIT-5),0,rng.randf_range(-Map.LIMIT+5,Map.LIMIT-5));var ground:=Map.Landscape.surface(p.x,p.z).x
		add_query(space,1,p+Vector3.UP*(ground+2),Vector3(rng.randf_range(-.5,.5),-3,rng.randf_range(-.5,.5)),"terrain_cylinder")
		add_query(space,3,p+Vector3.UP*(ground+2),Vector3(0,-3,0),"terrain_capsule")
	# Real CharacterBody slide/snap oracle, sampled across the real map.
	for i in 64:
		var p:Vector3=Map.Landscape.CENTERS[i%Map.Landscape.CENTERS.size()]+Vector3((i/11-3)*4,5,(i%7-3)*4)
		var ground:=ray_hit(space,p+Vector3.UP*100,Vector3(0,-200,0))
		if ground.is_empty():continue
		var actor:=MovementProbe.new();actor.collision_layer=2;actor.collision_mask=1;actor.floor_snap_length=.0625;actor.floor_max_angle=acos(.7);actor.wall_min_slide_angle=0
		var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;collider.shape=shape;collider.position.y=.830;actor.add_child(collider);actor.command=Vector3(sin(i*.7)*5,-.2,cos(i*.7)*5);actor.position=ground.position+Vector3.UP*.01;world.add_child(actor)
		var result:Dictionary=await actor.completed
		timings.movement.append(result.ms);timings.movement_cold.append(result.cold_ms)
		movement_deltas.append(result.delta);skipped_movement_ticks+=result.skipped_ticks
		var row:=shape_row(shape,Transform3D(Basis.IDENTITY,result.start),0,1);row.kind=5
		traces.append({"shape":row,"delta":actor.command,"hit":result.grounded,"fraction":1.,"unsafe_fraction":1.,"id":-1,"normal":Vector3.ZERO,"position":result.position,"velocity":result.velocity,"scenario":"cs_slide_snap"})
		actor.queue_free();await physics_frame
	f=FileAccess.open(trace_path,FileAccess.WRITE);f.store_buffer("CQTRACE2".to_ascii_buffer());f.store_32(traces.size())
	var scenarios:Array=[]
	for trace in traces:
		if not scenarios.has(trace.scenario):scenarios.append(trace.scenario)
		write_shape(f,trace.shape);vector(f,trace.delta);f.store_32(1 if trace.hit else 0);f.store_double(trace.fraction);f.store_double(trace.unsafe_fraction);f.store_32(trace.id);vector(f,trace.normal);vector(f,trace.position);vector(f,trace.velocity);f.store_32(scenarios.find(trace.scenario))
	f.close()
	var metadata:={"movement_tick_deltas":movement_deltas,"skipped_bootstrap_ticks":skipped_movement_ticks,"stair_ramps":stair_ramps,"height_samples":heights.size(),"primitives":primitives.size(),"queries":traces.size(),"terrain_diagonal_ad":ad,"diagonal_probe_error_m":minf(absf(probe.position.y-(.75*a+.25*d)),absf(probe.position.y-(.5*a+.25*b+.25*c))),"scenarios":scenarios,"oracle":"Godot real map; 30 Hz; no AI, network or rendering","timings":{}}
	var summary=preload("res://tools/voxel_battle/performance.gd")
	for key in timings:
		metadata.timings[key]=summary.summary(timings[key]);metadata.timings[key]["per_query_ms"]=timings[key];metadata.timings[key]["total_ms"]=timings[key].reduce(func(total,value):return total+value,0.)
	f=FileAccess.open(metadata_path,FileAccess.WRITE);f.store_string(JSON.stringify(metadata,"\t"));f.close();print("COLLISION_ORACLE ",JSON.stringify(metadata));world.queue_free();await process_frame;quit()
