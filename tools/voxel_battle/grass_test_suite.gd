extends Node
## Explicit local diagnostic. Raw frame rows stay in memory until a take ends.
const STAGES=[
 {"name":"A: normal grass + audio","selection":true,"draw":true,"audio":true,"play":true},
 {"name":"B: normal grass, no grass audio","selection":true,"draw":true,"audio":false,"play":false},
 {"name":"C: frozen selection + audio","selection":false,"draw":true,"audio":true,"play":true},
 {"name":"D: frozen selection, no grass audio","selection":false,"draw":true,"audio":false,"play":false},
 {"name":"E: grass hidden, no grass audio","selection":false,"draw":false,"audio":false,"play":false},
 {"name":"F: normal grass + silent audio queries","selection":true,"draw":true,"audio":true,"play":false},
 {"name":"G: trees/bush selection frozen, no audio","selection":true,"draw":true,"audio":false,"play":false,"environment_selection":false},
 {"name":"H: all vegetation selection frozen, no audio","selection":false,"draw":true,"audio":false,"play":false,"environment_selection":false}]
var stages:Array=STAGES
var reset_player_on_start:=true
var game
var stage:=0
var take:=0
var capture:=false
var action_deadline_us:=0
var settling:=0.
var elapsed:=0.
var seconds:=60.
var rows:Array=[]
var output:="user://grass-ab"
var banner:Label3D
var previous_us:=0
var previous_physics:=0
var previous_scans:=0
var previous_builds:=0
var previous_emissions:=0
var check_path:=""
var checking:=false
var check_failures:Array=[]
var check_phases:=0
func setup(arena)->void:
 game=arena;process_priority=10000
 RenderingServer.viewport_set_measure_render_time(game.get_viewport().get_viewport_rid(),true)
 var args:=OS.get_cmdline_user_args()
 var index:=args.find("--grass-output")
 if index>=0 and index+1<args.size():output=args[index+1]
 index=args.find("--grass-test-check")
 if index>=0 and index+1<args.size():check_path=args[index+1];seconds=.25
 output=output.path_join("session-"+Time.get_datetime_string_from_system(true).replace(":","-")+"-"+str(OS.get_process_id()))
 DirAccess.make_dir_recursive_absolute(output)
 game.grass_audio.profiling_enabled=true
 # Hold weather and daylight constant across all takes; no AI in this fixture.
 game.weather.reset();game.weather.set_process(false)
 game.battle_map.lighting.phase_override=1.
 game.jungle_ambience.set_process(false)
 game.jungle_ambience.day.volume_db=-8;game.jungle_ambience.night.volume_db=-80;game.jungle_ambience.river.volume_db=-80;game.jungle_ambience.submerged.volume_db=-80
 for bed in game.jungle_ambience.beds.values():bed.volume_db=-80
 var home=game.hud.menu_pages.pages.home
 game.hud.button(home,"GRASS TEST: NEXT CONDITION",func():menu_stage(1))
 game.hud.button(home,"GRASS TEST: START TAKE",start_capture)
 game.hud.button(home,"GRASS TEST: PREVIOUS CONDITION",func():menu_stage(-1))
 banner=Label3D.new();banner.name="GrassDiagnostic";banner.font_size=24;banner.pixel_size=.0016
 banner.no_depth_test=true;banner.position=Vector3(0,.20,-1.3)
 (game.xr_rig.head if game.is_vr() else game.camera).add_child(banner)
 select_stage(0)
 print("GRASS_AB_READY ",ProjectSettings.globalize_path(output))
func select_stage(index:int)->void:
 if capture:finish("condition_changed")
 stage=index
 var mode:Dictionary=stages[stage];var grass=game.battle_map.grass
 # Warm a valid visible buffer before freezing it, including after hidden mode.
 grass.selection_enabled=true;grass.set_enabled(true);grass.dirty=true;grass.update(game.world_view_camera())
 var environment=game.battle_map.environment
 game.battle_map.environment_selection_enabled=true;environment.dirty=true;environment.update(game.world_view_camera())
 game.battle_map.environment_selection_enabled=mode.get("environment_selection",true)
 grass.selection_enabled=mode.selection
 if not mode.draw:grass.set_enabled(false)
 game.grass_audio.set_enabled(mode.audio);game.grass_audio.set_playback_enabled(mode.play)
 settling=3.;reset_counters()
func reset_counters()->void:
 previous_us=Time.get_ticks_usec();previous_physics=Engine.get_physics_frames()
 previous_scans=game.grass_audio.scans;previous_builds=game.grass_audio.cell_builds;previous_emissions=game.grass_audio.emissions
func menu_stage(direction:int)->void:
 if Time.get_ticks_usec()<action_deadline_us:return
 action_deadline_us=Time.get_ticks_usec()+300000
 select_stage(posmod(stage+direction,stages.size()))
func start_capture()->void:
 if capture:return
 toggle_capture()
func close_capture_menu()->void:
 if not capture:return
 game.menu_open=false;game.hud.show_menu(false)
func toggle_capture()->void:
 # Hiding the XR viewport can synchronously release/re-emit its active button.
 # Latch before closing, and keep the menu's START action idempotent.
 if not checking and Time.get_ticks_usec()<action_deadline_us:return
 action_deadline_us=Time.get_ticks_usec()+300000
 if capture:finish("manual_stop");return
 take+=1;rows.clear();elapsed=0.;capture=true;settling=5.;reset_counters()
 if not checking and reset_player_on_start:game.rpc_id(1,"_reset_shocktroop_test",game.map_epoch)
 if stages[stage].draw:game.battle_map.grass.selection_enabled=true
 game.battle_map.environment_selection_enabled=true
 close_capture_menu.call_deferred()
 print("GRASS_AB_BEGIN ",JSON.stringify({"stage":stage,"take":take,"mode":stages[stage]}))
func _process(delta:float)->void:
 if not is_instance_valid(game) or not game.active:return
 var available:bool=not game.map_loading and not game.menu_open and not game.local_state().get("dead",true) and (not game.is_vr() or game.xr_rig.focused)
 var instruction:="STILL: slow head turns" if elapsed<20 else "WALK: repeat same path" if elapsed<40 else "RUN: repeat same path"
 banner.text=stages[stage].name+"\n"+("SETTLING" if settling>0 and capture else "%ds / %ds — %s"%[elapsed,seconds,instruction] if capture else "Open menu: START TAKE")
 if not available:
  if capture:finish("interrupted_menu_focus_or_life")
  settling=3.;reset_counters();return
 if settling>0:
  settling=maxf(0,settling-delta);reset_counters()
  if settling==0:settle_complete()
  return
 if not check_path.is_empty() and not checking:
  checking=true;toggle_capture();settling=.1
 if not capture:reset_counters();return
 var now:=Time.get_ticks_usec();var physics:int=Engine.get_physics_frames()
 var grass=game.battle_map.grass;var audio=game.grass_audio
 var actor=game.fighters.get(game.multiplayer.get_unique_id())
 var rid:RID=game.get_viewport().get_viewport_rid()
 rows.append([now,now-previous_us,physics-previous_physics,grass.update_ms,audio.update_us,audio.scans-previous_scans,audio.cell_builds-previous_builds,audio.emissions-previous_emissions,RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid),actor.velocity.length() if actor else 0.,grass.submitted_tufts,grass.refreshes,game.battle_map.environment.update_ms,game.battle_map.environment.visible_features,game.battle_map.terrain.running.size()])
 elapsed+=float(now-previous_us)/1000000.
 previous_us=now;previous_physics=physics;previous_scans=audio.scans;previous_builds=audio.cell_builds;previous_emissions=audio.emissions
 if elapsed>=seconds:
  finish("complete")
  if checking:advance_check()
func settle_complete()->void:
 game.battle_map.grass.selection_enabled=stages[stage].selection
 game.battle_map.environment_selection_enabled=stages[stage].get("environment_selection",true)
func extra_metadata()->Dictionary:return {}
func finish(reason:String)->void:
 capture=false
 var path:=output.path_join("stage-%d-take-%03d"%[stage,take])
 var file:=FileAccess.open(path+".csv",FileAccess.WRITE)
 if not file:push_error("Cannot write grass capture: "+path);return
 file.store_line("sample_us,interval_us,physics_ticks,grass_ms,grass_audio_us,audio_scans,audio_cell_builds,audio_emissions,render_cpu_ms,render_gpu_ms,speed,grass_instances,grass_refreshes,environment_ms,environment_instances,terrain_jobs")
 for row in rows:file.store_csv_line(PackedStringArray(Array(row).map(func(value):return str(value))))
 file.close()
 var metadata:={"stage":stage,"take":take,"condition":stages[stage],"reason":reason,"seconds":elapsed,"frames":rows.size(),"xr":game.is_vr(),"physics_hz":Engine.physics_ticks_per_second,"warmup_seconds":.1 if checking else 5,"render_scale":game.presentation.render_scale,"csv":path+".csv"}
 metadata["runtime"]=str(XRServer.find_interface("OpenXR").get_system_info()) if game.is_vr() else "desktop validation"
 var xr=XRServer.find_interface("OpenXR")
 metadata["refresh_hz"]=xr.get_display_refresh_rate() if game.is_vr() else 0.
 metadata["target_hz"]=metadata.refresh_hz if metadata.refresh_hz>0 else 90.
 metadata["refresh_source"]="openxr" if metadata.refresh_hz>0 else "assumed_90"
 metadata["adapter"]=RenderingServer.get_video_adapter_name()
 metadata["terrain_jobs"]=game.battle_map.terrain.running.size()
 metadata["vegetation_source_sha256"]=FileAccess.get_sha256("res://tools/voxel_battle/grass.gd")
 metadata["environment_source_sha256"]=FileAccess.get_sha256("res://tools/voxel_battle/environment.gd")
 metadata["suite_source_sha256"]=FileAccess.get_sha256("res://tools/voxel_battle/grass_test_suite.gd")
 metadata.merge(extra_metadata())
 metadata["grass_audio_source_sha256"]=FileAccess.get_sha256("res://tools/voxel_battle/grass_audio.gd")
 file=FileAccess.open(path+".json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"\t"));file.close()
 print("GRASS_AB_END ",JSON.stringify(metadata))
func advance_check()->void:
 if rows.is_empty():check_failures.append("stage %d has no frames"%stage)
 if not stages[stage].audio and rows.any(func(r):return r[5]!=0 or r[7]!=0):check_failures.append("disabled audio still works")
 if not stages[stage].play and rows.any(func(r):return r[7]!=0):check_failures.append("disabled playback emitted")
 if not stages[stage].selection and rows.any(func(r):return r[3]!=0):check_failures.append("frozen selection rebuilt")
 if not stages[stage].get("environment_selection",true) and rows.any(func(r):return r[13]!=0):check_failures.append("frozen trees rebuilt")
 if not stages[stage].draw and rows.any(func(r):return r[11]!=0):check_failures.append("hidden grass still submitted")
 check_phases+=1
 if stage+1<stages.size():select_stage(stage+1);toggle_capture();settling=.1;return
 var file:=FileAccess.open(check_path,FileAccess.WRITE);file.store_string(JSON.stringify({"stages":check_phases,"failures":check_failures}));file.close()
 game.finish_check(0 if check_failures.is_empty() else 1)
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_F9:select_stage((stage+1)%stages.size())
  elif event.physical_keycode==KEY_F10:toggle_capture()
func _exit_tree()->void:
 if capture:finish("exit")
