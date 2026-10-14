extends SceneTree
## Integrated backend acceptance: real authored map and gameplay CharacterBody3D.
const Map=preload("res://tools/voxel_battle/map.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class UnassistedFighter extends Fighter:
	func step_up(_travel:Vector3,_height:float)->bool:return false
var failures:Array=[]
var checks:=0
var report:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func actor(parent:Node,p:Vector3,unassisted:bool=false):
	var body=UnassistedFighter.new() if unassisted else Fighter.new()
	body.setup(1,"Jolt acceptance",Color.WHITE);parent.add_child(body)
	body.set_process(false);body.configure_cs16(true,3.0);body.position=p
	return body
func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func run()->void:
	Engine.physics_ticks_per_second=30
	report.engine=ProjectSettings.get_setting("physics/3d/physics_engine")
	check(report.engine=="Jolt Physics","Jolt explicitly selected before physics server startup")
	var map:=Map.new();root.add_child(map);map.build(false,true)
	check(map.stair_ramps.added_ramps==19 and map.stair_ramps.removed_treads==304,"Runtime replaces 304 stair treads with 19 ramps")
	check(map.stair_ramps.render_boxes_unchanged,"Authored stair render geometry preserved")
	var actors:Array=[];var flights:Array=map.stair_ramps.flights
	for flight in flights:
		var start:=vector(flight.start);var end:=vector(flight.end)
		var slope:float=(end.y-start.y)/(end.z-start.z)
		actors.append(actor(map,start+Vector3(0,.75*slope-.005,.45),true))
	for tick in 95:
		await physics_frame
		for body in actors:body.simulate(Vector2.DOWN,0,false,1.0/30)
		if tick==10:check(not Fighter.CS16.near_edge(actors[0],Vector2.DOWN),"Uphill floor probe does not mistake a ramp for a ledge")
	for i in actors.size():
		var end:=vector(flights[i].end);var body=actors[i]
		check(body.position.z>=end.z-.25 and absf(body.position.y-end.y)<.08,"Flight %d uphill without stair assist"%i)
	for tick in 95:
		await physics_frame
		for body in actors:body.simulate(Vector2.UP,0,false,1.0/30)
	for i in actors.size():
		var start:=vector(flights[i].start);var body=actors[i]
		check(body.position.z<start.z+.8 and body.position.y<start.y+.5,"Flight %d downhill without stair assist"%i)
	map.free();await physics_frame
	var world:=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
	var lower=actor(world,Vector3(0,.02,0));var upper=actor(world,Vector3(0,1.68,0))
	for tick in 60:
		await physics_frame
		lower.simulate(Vector2.ZERO,0,false,1.0/30);upper.simulate(Vector2.ZERO,0,false,1.0/30)
	check(upper.is_supported() and absf(upper.position.y-lower.position.y-1.65)<.025,"Players support a standing player without overlap")
	check(not Fighter.CS16.near_edge(lower,Vector2.RIGHT),"Flat supported ground does not enable edge friction")
	lower.position.x=49.9
	check(Fighter.CS16.near_edge(lower,Vector2.RIGHT),"Actual unsupported ledge still enables edge friction")
	upper.update_height(.65,true);upper.update_height(1.65,true)
	check(is_equal_approx(upper.collision_height,1.65),"Prone and standing hull updates remain usable on support")
	lower.free();upper.free()
	var timings:Dictionary={}
	for count in [32,64]:
		actors=[]
		for i in count:
			var angle:float=TAU*i/count
			actors.append(actor(world,Vector3(cos(angle)*8,.02,sin(angle)*8)))
		var samples:Array=[]
		for tick in 240:
			await physics_frame
			var began:=Time.get_ticks_usec()
			for body in actors:
				var direction:=Vector2(-body.position.x,-body.position.z).normalized()
				body.simulate(direction,0,false,1.0/30)
			if tick>=60:samples.append((Time.get_ticks_usec()-began)/1000.0)
		var minimum:=INF
		for i in actors.size():
			for j in range(i+1,actors.size()):
				if absf(actors[i].position.y-actors[j].position.y)<.2:
					minimum=minf(minimum,Vector2(actors[i].position.x-actors[j].position.x,actors[i].position.z-actors[j].position.z).length())
		check(minimum>.57,"%d converging players preserve cylinder separation"%count)
		samples.sort();timings[str(count)]={"movement_batch_p50_ms":samples[samples.size()/2],"movement_batch_p95_ms":samples[int(samples.size()*.95)],"minimum_horizontal_separation_m":minimum,"samples":samples.size()}
		for body in actors:body.free()
		await physics_frame
	world.free();await process_frame
	report.merge({"checks":checks,"failures":failures,"movement_only":timings,"tick_hz":30})
	print("CQ_JOLT_RUNTIME_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
