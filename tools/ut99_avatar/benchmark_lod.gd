extends SceneTree
## Matched 32-avatar render/CPU test, no AI, terrain, combat or networking.
const Library=preload("res://deathmatch/avatars/library.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Probe=preload("res://tools/voxel_battle/performance.gd")
var avatars:Array=[]
var output:="res://test-results/ut99-lod/render"
var samples:=360
var results:Dictionary={}
func _initialize() -> void:run.call_deferred()
func step() -> Vector2:
 var start:=Time.get_ticks_usec();var ik:=0.0
 for rig in avatars:
  rig._process(1.0/60);ik+=rig.arm_update_ms
 return Vector2((Time.get_ticks_usec()-start)/1000.0,ik)
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Rendering required");quit(1);return
 var args:=OS.get_cmdline_user_args()
 if args.has("--output"):output=args[args.find("--output")+1]
 if args.has("--samples"):samples=int(args[args.find("--samples")+1])
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1440,900);root.msaa_3d=Viewport.MSAA_DISABLED
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("24322c");root.add_child(environment)
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,1.8,0);camera.look_at(Vector3(0,1.2,10));camera.fov=85;camera.current=true;camera.far=200
 var library:=Library.new();root.add_child(library)
 var hashes:Array=[]
 for model in ["soldier","commando","sgirl","fcommando","boss"]:hashes.append(library.register_file("res://deathmatch/avatars/models/base/"+model+".utavatar",false))
 for i in 32:
  var rig=library.create_avatar(hashes[i%5]);root.add_child(rig);rig.set_process(false);rig.unarmed=true;rig.speed=4;rig.target_xr_pose=Poses.neutral()
  avatars.append(rig)
 var cases:=["baseline","ik_only","mesh_only","combined","baseline_repeat","combined_repeat"]
 for layout in ["near","mixed","far"]:
  for i in avatars.size():
   var row:=i/8;var distance:=6.0+row*1.5 if layout=="near" else 60.0+row*5
   if layout=="mixed":distance=[7.0,30.0,65.0,75.0][row]
   avatars[i].position=Vector3((i%8-3.5)*distance*.09,0,distance)
  for mode in cases:
   for i in avatars.size():
    avatars[i].distance_ik_enabled=mode in ["ik_only","combined","combined_repeat"]
    avatars[i].mesh_lod_enabled=mode in ["mesh_only","combined","combined_repeat"]
    # Prime clip selection so the first baseline keeps the same staggered phase
    # as later cases instead of resetting every resident on its first update.
    avatars[i].clip_name=avatars[i].choose_clip().name
    avatars[i].time=i*.073;avatars[i].ik_near=true;avatars[i].ik_weight=0
   for warmup in 120:
    await process_frame;step();await RenderingServer.frame_post_draw
   var wall:Array=[];var update:Array=[];var ik:Array=[];var gpu:Array=[];var primitives:Array=[];var draws:Array=[]
   var last:=Time.get_ticks_usec()
   for sample in samples:
    await process_frame;var cpu:=step();await RenderingServer.frame_post_draw
    var now:=Time.get_ticks_usec();wall.append((now-last)/1000.0);last=now
    update.append(cpu.x);ik.append(cpu.y);gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
    primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
   var tiers:=[0,0,0];var active:=0
   for rig in avatars:tiers[rig.mesh_tier]+=1;active+=int(rig.tracked_arms_active)
   var key:String=layout+"/"+mode
   results[key]={"wall_ms":Probe.summary(wall),"avatar_cpu_ms":Probe.summary(update),"ik_cpu_ms":Probe.summary(ik),"gpu_ms":Probe.summary(gpu),"primitives":Probe.summary(primitives),"draws":Probe.summary(draws),"mesh_tiers":tiers,"ik_active":active}
   print(key," ",JSON.stringify(results[key]))
   if mode in ["baseline","combined"]:root.get_texture().get_image().save_png(output+"/"+layout+"-"+mode+".png")
 var report:={"hardware":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1440,900],"avatars":32,"samples_per_case":samples,"by_case":results,"scope":"Static camera, five bundled UT99 model families, matched Run clips and neutral tracked poses; 120-frame warmups; uncapped mono Vulkan, no MSAA, map, AI, combat, networking or physics. CPU includes policy and instance uniforms; wall and GPU include avatar rendering. Baseline uses the same indexed full-detail mesh and shader, both LOD policies disabled. Repeat cases expose timing variation."}
 var file:=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit()
