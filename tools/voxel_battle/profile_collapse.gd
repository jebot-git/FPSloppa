extends SceneTree
## Isolated full-map CPU-call / viewport GPU timing experiment. No gameplay changes.
const Map=preload("res://tools/voxel_battle/map.gd")
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=1
 var resident=null
class ProfiledDestruction extends Destruction:
 var animation_calls:Array=[]
 var replacement_calls:Array=[]
 var process_us:=0
 static func thread_cpu_ns()->int:
  # procfs reports a zero file length; read a line rather than get_as_text().
  var file:=FileAccess.open("/proc/thread-self/schedstat",FileAccess.READ)
  return int(file.get_line().get_slice(" ",0))
 func animate_collapse(building:Dictionary)->void:
  var cpu_start:=thread_cpu_ns()
  var start:=Time.get_ticks_usec()
  super.animate_collapse(building)
  animation_calls.append({"wall_us":Time.get_ticks_usec()-start,"thread_cpu_us":(thread_cpu_ns()-cpu_start)/1000.})
 func replace_mesh(source:ArrayMesh,kind:int,lod:int=0)->ArrayMesh:
  var start:=Time.get_ticks_usec()
  var result:=super.replace_mesh(source,kind,lod)
  replacement_calls.append({"lod":lod,"us":Time.get_ticks_usec()-start})
  return result
 func _process(delta:float)->void:
  var start:=Time.get_ticks_usec()
  super._process(delta)
  process_us=Time.get_ticks_usec()-start
var game
var map
var service
var camera:Camera3D
var frames:Array=[]
var previous_post:=0
var size:=Vector2i(1280,720)
var output:="res://test-results/collapse-profile-720.json"
func _initialize()->void:run.call_deferred()
func frame(phase:String,index:int)->void:
 var start:=Time.get_ticks_usec()
 map.update_view(camera)
 var view_us:=Time.get_ticks_usec()-start
 await process_frame
 await RenderingServer.frame_post_draw
 var now:=Time.get_ticks_usec()
 frames.append({"phase":phase,"index":index,"wall_ms":(now-previous_post)/1000. if previous_post else 0.,"view_us":view_us,"service_process_us":service.process_us,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
 previous_post=now
func run()->void:
 assert(DisplayServer.get_name()!="headless","GPU profiling requires Vulkan")
 assert(OS.get_name()=="Linux" and ProfiledDestruction.thread_cpu_ns()>0,"This probe uses Linux schedstat for main-thread execution timing")
 if OS.get_cmdline_user_args().has("--360"):
  size=Vector2i(640,360);output="res://test-results/collapse-profile-360.json"
 root.size=size
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 game=Game.new();root.add_child(game)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.38,.55,.63);game.add_child(env)
 map=Map.new();game.add_child(map);map.build(true,true);map.lighting.phase_override=1.
 service=ProfiledDestruction.new();game.add_child(service);service.setup(game,map,true,true)
 camera=Camera3D.new();camera.far=1200;game.add_child(camera);camera.make_current()
 var id:=-1
 for c in service.cells:
  if c.kind==1 and c.size.z<.3 and c.size.y>3. and c.center.y<3.:id=service.integrity.wall_building[c.wall];break
 assert(id>=0)
 var building:Dictionary=service.integrity.buildings[id]
 var center:Vector3=Map.Landscape.CENTERS[building.kind]+building.center
 camera.position=center+Vector3(building.size.x*1.2,building.floors*3.6*.5+8,building.size.y*1.4+20);camera.look_at(center+Vector3.UP*building.floors*3.6*.4)
 var ids:=PackedInt32Array()
 for column in building.stories[1]:
  for cell in column.cells:
   if not cell in ids:ids.append(cell)
 for i in 120:await frame("warmup",i)
 var events:Array=[]
 # Two repeats separate cold allocations from warmed pipeline/resource caches.
 for repeat in 2:
  for mode in ["full","no_animation","animation_only"]:
   service.clear_state()
   for i in 90:await frame("baseline_"+mode+str(repeat),i)
   service.animation_calls.clear();service.replacement_calls.clear()
   var cpu_start:int=service.thread_cpu_ns()
   var start:=Time.get_ticks_usec()
   if mode=="animation_only":service.animate_collapse(building)
   else:service.apply_breaks(ids,center,mode=="full")
   var trigger_us:=Time.get_ticks_usec()-start
   var trigger_cpu_us:float=(service.thread_cpu_ns()-cpu_start)/1000.
   cpu_start=service.thread_cpu_ns();start=Time.get_ticks_usec();service.flush_meshes();var mesh_us:=Time.get_ticks_usec()-start
   var mesh_cpu_us:float=(service.thread_cpu_ns()-cpu_start)/1000.
   events.append({"mode":mode,"repeat":repeat,"frame":frames.size(),"trigger_us":trigger_us,"trigger_thread_cpu_us":trigger_cpu_us,"mesh_us":mesh_us,"mesh_thread_cpu_us":mesh_cpu_us,"animation_calls":service.animation_calls.duplicate(),"replacement_calls":service.replacement_calls.duplicate(true),"collapse_detail":service.last_collapse_stats.duplicate() if mode!="animation_only" else {}})
   print("COLLAPSE_PROFILE_EVENT ",JSON.stringify(events[-1]))
   # Capture the full 1.4s animation even at uncapped, low-resolution frame rates.
   var until_usec:=Time.get_ticks_usec()+1700000
   var index:=0
   while index<180 or Time.get_ticks_usec()<until_usec:
    await frame("event_"+mode+str(repeat),index)
    index+=1
 var report:Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[size.x,size.y],"vsync":false,"events":events,"frames":frames,"scope":"Full map, no players. Direct failed factory-storey support set; no preceding breaches. CPU-call wall durations can include driver/synchronization waits; thread_cpu_us comes from Linux /proc/thread-self/schedstat execution nanoseconds and excludes descheduling/waits (kernel accounting granularity applies). Viewport GPU timestamps can lag and exclude CPU scripts/uploads. Other owned Godot processes suspended during capture."}
 DirAccess.make_dir_recursive_absolute("res://test-results")
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report))
 print("COLLAPSE_PROFILE_SAVED ",output)
 game.queue_free();await process_frame;quit()
