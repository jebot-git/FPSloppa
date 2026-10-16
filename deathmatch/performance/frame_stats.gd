extends Node
## Opt-in wall-clock pacing and render costs. No raw poses or microphone data.
const WINDOW_SECONDS:=10.0
var elapsed:=0.0
var warmup:=5.0
var frames:Array[float]=[]
var cpu:Array[float]=[]
var gpu:Array[float]=[]
var avatar_batch_cpu:Array[float]=[]
var avatar_batch_tracked_peak:=0
var avatar_batch_counters:Dictionary={}
var spikes:Array=[]
var previous_us:=0
var window_start_us:=0
var target_hz:=0.0
var refresh_source:="unknown"
var previous_physics_frame:=0
var previous_grass_refresh:=0
var previous_audio_updates:=0
var workload_groups:Dictionary={}
func _ready()->void:
 previous_us=Time.get_ticks_usec()
 previous_physics_frame=Engine.get_physics_frames()
 if DisplayServer.get_name()!="headless":RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
func refresh_hz()->float:
 var xr:=XRServer.find_interface("OpenXR")
 if get_viewport().use_xr and xr and xr.is_initialized() and xr.has_method("get_display_refresh_rate"):
  var hz:float=xr.call("get_display_refresh_rate")
  if hz>0:refresh_source="openxr";return hz
 if get_viewport().use_xr:
  refresh_source="assumed_xr_90"
  return 90.
 refresh_source="desktop"
 var hz:float=DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name()!="headless" else 0.
 return hz if hz>0 else 90. if get_viewport().use_xr else 60.
static func percentile(values:Array[float],fraction:float)->float:
 if values.is_empty():return 0.
 return values[clampi(ceili((values.size()-1)*fraction),0,values.size()-1)]
func context()->Dictionary:
 var game=get_parent();var row:Dictionary={}
 if game and game.has_method("local_state"):
  var state:Dictionary=game.local_state()
  row={"menu":game.menu_open,"map_loading":game.map_loading,"weapon":state.get("weapon",-1),"dead":state.get("dead",true),"physics_hz":Engine.physics_ticks_per_second}
  if game.has_method("draw_class_players"):
   var id:int=game.multiplayer.get_unique_id()
   row["class"]=game.classes.role(id);row["vehicle"]=game.battery_tanks.key_for(id)
   row["nvg"]=game.night_vision.enabled_for(id);row["scope"]=game.is_vr() and game.xr_rig.sniper_scope!=null and game.xr_rig.sniper_scope.active
   if "weather" in game and not game.weather.state.is_empty():
    var values:Vector4=game.weather.state.values
    row["weather"]={"mode":game.weather.state.mode,"rain":values.y,"fog":values.x,"rain_reduced":game.weather.reduced}
 return row
func _process(delta:float)->void:
 var now:=Time.get_ticks_usec();var wall:float=float(now-previous_us)/1000.;previous_us=now
 var physics_ticks:int=Engine.get_physics_frames()-previous_physics_frame;previous_physics_frame=Engine.get_physics_frames()
 if warmup>0:warmup-=delta;window_start_us=now;return
 if frames.is_empty():target_hz=refresh_hz()
 var batch=get_viewport().get_node_or_null("NativeAvatarBatch")
 if batch and batch.kernel:
  avatar_batch_counters=batch.kernel.metrics()
  avatar_batch_cpu.append(float(avatar_batch_counters.get("elapsed_us",0.))/1000.)
  avatar_batch_tracked_peak=maxi(avatar_batch_tracked_peak,int(avatar_batch_counters.get("tracked",0)))
 var budget:float=1000./target_hz
 frames.append(wall);elapsed+=wall/1000.
 var game=get_parent();var grass_updates:=0;var grass_ms:=0.;var audio_updates:=0
 if game and game.has_method("draw_class_players"):
  if is_instance_valid(game.battle_map) and is_instance_valid(game.battle_map.grass):
   var grass=game.battle_map.grass
   grass_updates=maxi(0,grass.refreshes-previous_grass_refresh);previous_grass_refresh=grass.refreshes;grass_ms=grass.update_ms
  if is_instance_valid(game.spatial):
   audio_updates=maxi(0,game.spatial.source_updates-previous_audio_updates);previous_audio_updates=game.spatial.source_updates
 var group_key:="physics_%d_grass_%d_audio_%d"%[mini(physics_ticks,8),int(grass_updates>0),int(audio_updates>0)]
 if not workload_groups.has(group_key):workload_groups[group_key]={"frames":0,"wall_ms":0.,"process_ms":0.,"physics_ms":0.,"grass_ms":0.,"grass_ms_max":0.}
 var group:Dictionary=workload_groups[group_key];group.frames+=1;group.wall_ms+=wall;group.process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.;group.physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.;group.grass_ms+=grass_ms;group.grass_ms_max=maxf(group.grass_ms_max,grass_ms)
 var rid:=get_viewport().get_viewport_rid()
 if DisplayServer.get_name()!="headless":
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
 if wall>budget*2 and spikes.size()<8:
  var spike:=context();spike.merge({"ms":Time.get_ticks_msec(),"wall_ms":wall,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.});spikes.append(spike)
 if elapsed<WINDOW_SECONDS:return
 var missed:=0;var severe:=0
 for frame in frames:missed+=int(frame>budget*1.05);severe+=int(frame>budget*2)
 frames.sort();cpu.sort();gpu.sort();avatar_batch_cpu.sort()
 var report:=context()
 var workloads:=workload_groups.duplicate(true)
 for row in workloads.values():
  for field in ["wall_ms","process_ms","physics_ms","grass_ms"]:row[field]/=row.frames
 report["workload_groups"]=workloads
 if not avatar_batch_cpu.is_empty():
  report["avatar_batch"]={"cpu_ms_p50":percentile(avatar_batch_cpu,.5),"cpu_ms_p95":percentile(avatar_batch_cpu,.95),"cpu_ms_max":avatar_batch_cpu[-1],"tracked_peak":avatar_batch_tracked_peak,"last":avatar_batch_counters.duplicate()}
 report["refresh_source"]=refresh_source
 report.merge({"utc":Time.get_datetime_string_from_system(true),"begin_us":window_start_us,"end_us":now,"window_seconds":elapsed,"frames":frames.size(),"fps":frames.size()/elapsed,"frame_ms_p50":percentile(frames,.5),"frame_ms_p95":percentile(frames,.95),"frame_ms_p99":percentile(frames,.99),"frame_ms_max":frames[-1],"target_hz":target_hz,"target_ms":budget,"over_budget_5pct":missed,"over_2budgets":severe,"render_cpu_ms_p95":percentile(cpu,.95),"render_gpu_ms_p95":percentile(gpu,.95),"spikes":spikes.duplicate(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"xr":get_viewport().use_xr})
 print("FRAME_STATS ",JSON.stringify(report))
 frames.clear();cpu.clear();gpu.clear();avatar_batch_cpu.clear();avatar_batch_tracked_peak=0;spikes.clear();workload_groups.clear();elapsed=0;window_start_us=now
