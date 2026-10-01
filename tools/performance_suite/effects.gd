extends SceneTree
## Deterministic rendered effect benchmark. An optional reference script permits A/B runs.
var output:="res://test-results/effect-benchmark.json"
func _initialize() -> void:run.call_deferred()
func distribution(values: Array) -> Dictionary:
	values.sort();var n:=values.size()
	return {"n":n,"median_us":(values[(n-1)/2]+values[n/2])*.5,"p95_us":values[ceili(n*.95)-1],"p99_us":values[ceili(n*.99)-1],"max_us":values.back()}
func run() -> void:
	var args:=OS.get_cmdline_user_args();var reference:=""
	if args.size()>0:output=args[0]
	if args.size()>1:reference=args[1]
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,2,6);camera.look_at(Vector3(0,0,-2));camera.make_current()
	var result:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"runs":[]}
	var variants: Array=["current"] if reference.is_empty() else ["reference","current","current","reference"]
	for variant in variants:
		var fx=load(reference if variant=="reference" else "res://deathmatch/experimental/visuals.gd").new()
		world.add_child(fx);fx.set_process(false)
		var timings: Array=[]
		for frame in 270:
			fx._process(1.0/72)
			var begin:=Time.get_ticks_usec()
			# Identical tracer, shotgun cluster, curved beam and expanding shapes.
			var mode:=frame%4
			if mode<2:
				for pellet in (8 if mode==1 else 1):
					var x: float=(pellet-3.5)*.08
					fx.streak(PackedVector3Array([Vector3(x,0,0),Vector3(x,.2,-4)]),Color(1,.6,.15,.8),.012,.12)
			elif mode==2:
				var points:=PackedVector3Array()
				for i in 25:points.append(Vector3(sin(i*.7)*.08,.5,-i*.2))
				fx.streak(points,Color(.3,.6,1,.8),.02,.16)
			else:
				fx.ring(Vector3(-1,0,-2),Color(.5,.8,1,.7),.8,.25)
				fx.globe(Vector3(1,0,-2),Color(1,.4,.1,.7),.7,.25)
			if frame>=30:timings.append(Time.get_ticks_usec()-begin)
			await process_frame
		result.runs.append({"variant":variant,"creation":distribution(timings),"children":fx.get_child_count()})
		if variant=="current" and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.get_basename()+".png")
		fx.free();await process_frame
	world.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("EFFECT_BENCHMARK ",JSON.stringify(result));quit()
