extends SceneTree
## Actual-map visual and paired rendering comparison. No forced mesh LOD.
var scene
var ready:=false
var output:="res://test-results/rock-cover"
var capture_size:=Vector2i.ZERO
func _initialize()->void:run.call_deferred()
func _process(_delta:float)->bool:
 if ready:scene.map.update_view(scene.camera)
 return false
func summary(values:Array)->Dictionary:
 values.sort();return {"p50_ms":values[int(values.size()*.5)],"p95_ms":values[int(values.size()*.95)],"max_ms":values.back()}
func measure()->Dictionary:
 for i in 25:await process_frame
 var frame:Array=[];var gpu:Array=[];var cpu:Array=[]
 for i in 100:
  var started:=Time.get_ticks_usec();await process_frame;frame.append((Time.get_ticks_usec()-started)/1000.)
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
 return {"frame":summary(frame),"render_cpu":summary(cpu),"render_gpu":summary(gpu),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
func run()->void:
 if DisplayServer.get_name()=="headless":quit(1);return
 var args:=OS.get_cmdline_user_args()
 if args.has("--output"):output=args[args.find("--output")+1]
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;scene.map.lighting.phase_override=1;ready=true
 var records:Array=[]
 for tag in ["outcrop","verge","river","night"]:
  var wanted:String="outcrop" if tag=="night" else tag
  var rows:Array=scene.map.rock_cover.rows.filter(func(row):return row.tag==wanted)
  var row:Dictionary=rows[0]
  var p:=Vector3(row.position[0],row.position[1],row.position[2]);var target:=p+Vector3.UP*float(row.height)*.45
  if tag=="river":target.y=scene.Landscape.water_sample(p.x,p.z).y+.8
  var eye:=target+Vector3(-6,1.7,-7)
  if tag=="river":
   var closest:=INF
   for river in scene.Landscape.Hydrology.RIVERS:
    for i in range(river.points.size()-1):
     var a:Vector3=river.points[i];var b:Vector3=river.points[i+1];var direction:=Vector2(b.x-a.x,b.z-a.z)
     var along:=clampf((Vector2(p.x,p.z)-Vector2(a.x,a.z)).dot(direction)/direction.length_squared(),0,1)
     var center:Vector3=a.lerp(b,along);var distance:=Vector2(p.x-center.x,p.z-center.z).length()
     if distance<closest:closest=distance;eye=center-(b-a).normalized()*10;eye.y=center.y+1.7
  eye.y=maxf(eye.y,scene.Landscape.surface(eye.x,eye.z).x+2.0)
  scene.camera.position=eye;scene.camera.fov=65;scene.camera.look_at(target)
  scene.visor_mode=1 if tag=="night" else 0
  scene.map.lighting.phase_override=0 if tag=="night" else 1
  scene.map.lighting.apply()
  var started:=Time.get_ticks_msec();await process_frame
  while not scene.map.terrain.settled():
   await process_frame
   if Time.get_ticks_msec()-started>90000:push_error("Stream timeout");quit(1);return
  await create_timer(.5).timeout;await RenderingServer.frame_post_draw
  var capture:=root.get_texture().get_image();capture_size=capture.get_size();capture.save_png(output+"/"+tag+".png")
  if tag in ["outcrop","river"]:
   var with_rocks:Dictionary=await measure()
   scene.map.rock_cover.visible=false
   var without_rocks:Dictionary=await measure()
   scene.map.rock_cover.visible=true
   records.append({"tag":tag,"with_rocks":with_rocks,"without_rocks":without_rocks,"position":[eye.x,eye.y,eye.z]})
  print("ROCK_CAPTURE ",tag)
 var report:={"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"capture_resolution":[capture_size.x,capture_size.y],"reported_texture_size":[root.get_texture().get_width(),root.get_texture().get_height()],"requested_window_size":[1280,720],"rows":records,"rocks":scene.map.rock_cover.rows.size(),"batches":scene.map.rock_cover.groups.size(),"scope":"Settled full-map renderer, paired fixed-view 100-frame samples after 25 warmup frames; rock visibility only changes. No avatars, networking or gameplay. Development machine only; no target-machine FPS claim."}
 FileAccess.open(output+"/render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));scene.map.terrain.shutdown();quit()
