extends Node
## Opt-in wall-clock pacing and render costs. No raw poses or microphone data.
const WINDOW_SECONDS:=10.0
var elapsed:=0.0
var warmup:=5.0
var frames:Array[float]=[]
var cpu:Array[float]=[]
var gpu:Array[float]=[]
var spikes:Array=[]
var previous_us:=0
var window_start_us:=0
var target_hz:=0.0
func _ready()->void:
 previous_us=Time.get_ticks_usec()
 if DisplayServer.get_name()!="headless":RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
func refresh_hz()->float:
 var xr:=XRServer.find_interface("OpenXR")
 if get_viewport().use_xr and xr and xr.is_initialized() and xr.has_method("get_display_refresh_rate"):
  var hz:float=xr.call("get_display_refresh_rate")
  if hz>0:return hz
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
 if warmup>0:warmup-=delta;window_start_us=now;return
 if frames.is_empty():target_hz=refresh_hz()
 var budget:float=1000./target_hz
 frames.append(wall);elapsed+=wall/1000.
 var rid:=get_viewport().get_viewport_rid()
 if DisplayServer.get_name()!="headless":
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
 if wall>budget*2 and spikes.size()<8:
  var spike:=context();spike.merge({"ms":Time.get_ticks_msec(),"wall_ms":wall,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.});spikes.append(spike)
 if elapsed<WINDOW_SECONDS:return
 var missed:=0;var severe:=0
 for frame in frames:missed+=int(frame>budget*1.05);severe+=int(frame>budget*2)
 frames.sort();cpu.sort();gpu.sort()
 var report:=context()
 report.merge({"utc":Time.get_datetime_string_from_system(true),"begin_us":window_start_us,"end_us":now,"window_seconds":elapsed,"frames":frames.size(),"fps":frames.size()/elapsed,"frame_ms_p50":percentile(frames,.5),"frame_ms_p95":percentile(frames,.95),"frame_ms_p99":percentile(frames,.99),"frame_ms_max":frames[-1],"target_hz":target_hz,"target_ms":budget,"over_budget_5pct":missed,"over_2budgets":severe,"render_cpu_ms_p95":percentile(cpu,.95),"render_gpu_ms_p95":percentile(gpu,.95),"spikes":spikes.duplicate(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"xr":get_viewport().use_xr})
 print("FRAME_STATS ",JSON.stringify(report))
 frames.clear();cpu.clear();gpu.clear();spikes.clear();elapsed=0;window_start_us=now
