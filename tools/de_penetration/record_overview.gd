extends SceneTree
## One local six-round-cap match, spectator camera, and complete movie capture.
var OUT="res://test-results/de-overview-recordings/"
var map_id:="de_varq_dust2"
var overview=preload("res://tools/de_penetration/overview_camera.gd").new()
var preview:=false
class Director extends Node:
 var update: Callable
 func _process(delta):update.call(delta)
var game
var server:=false
var followed:=0
var switch_at:=0.
var label: Label
var smooth_camera:=false
var camera_ready:=false
var camera_subject:=0
var camera_yaw:=0.
func _initialize():
 smooth_camera=true
 preview=OS.get_cmdline_user_args().has("--preview")
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--record-map":map_id=args[i+1]
 OUT+=map_id+"/"
 run.call_deferred()
func camera_frame(delta: float):
 if not is_instance_valid(game) or not game.active or not game.camera:return
 for id in game.fighters:game.fighters[id].show()
 overview.update(game,delta)
 if game.hud:
  game.hud.center_message.hide()
  game.hud.vitals.get_parent().get_parent().hide()
 if is_instance_valid(game.viewmodel):game.viewmodel.hide()
 label.text="%s · 5v5 BOTS · TEAM OVERVIEW\nRound %d / 6  |  %d — %d  |  %s"%[map_id,game.match_mode.defusal.round_id,game.match_mode.scores[0],game.match_mode.scores[1],game.match_mode.defusal.phase.to_upper()]
func run():
 server=OS.get_cmdline_user_args().has("--server")
 DirAccess.make_dir_recursive_absolute(OUT)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 if server:
  game.bot_population.count_target=10;game.bot_population.maintain();game.set_physics_process(false)
  while not FileAccess.file_exists(OUT+"recording-ready.json") or (not preview and not FileAccess.file_exists(OUT+"capture-started.json")):
   game._send_snapshot();await create_timer(.1).timeout
  game.set_physics_process(true)
 else:
  root.title="FPSloppa · "+map_id+(" · Camera preview (not recording)" if preview else " · 5v5 overview recording")
  var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer)
  label=Label.new();label.position=Vector2(24,65);label.add_theme_font_size_override("font_size",24);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);layer.add_child(label)
  var director:=Director.new();director.update=camera_frame;director.process_priority=1000;root.add_child(director)
 var finished_at:=-1.
 while is_instance_valid(game):
  if game.active and game.current_map==map_id:
   var teams: Array=[0,0];var spectators:=0;var shots:=0;var kills:=0;var cs_bots:=0
   for id in game.players:
    var s: Dictionary=game.players[id]
    if s.spectator:spectators+=1
    elif s.team in [0,1]:teams[s.team]+=1
    shots+=int(s.get("shots",0));kills+=int(s.get("kills",0))
    if id<0 and game.fighters[id].cs16_enabled:cs_bots+=1
   var de=game.match_mode.defusal
   if server and de.phase=="finished":game.intermission=3600.
   var pen=game.get_node("Map/MapRuntime").ballistics
   var report={"pid":OS.get_process_id(),"map":game.current_map,"bsp_sha256":game.map_sha,"teams":teams,"spectators":spectators,"round":de.round_id,"phase":de.phase,"scores":game.match_mode.scores,"round_cap":2*(de.win_limit-1),"bsp_penetration_ready":pen.ready,"cs_movement_bots":cs_bots,"shots":shots,"kills":kills,"wallbang_probes":game.bots.wallbang.attempts if server else 0,"wallbang_firing_ticks":game.bots.wallbang.firing_ticks if server else 0,"clock":game.clock,"camera":"smooth three-quarter cutaway", "camera_clearance_corrections":overview.clearance_corrections, "camera_clearance_failures":overview.clearance_failures, "camera_frames":overview.frames, "camera_maximum_step":overview.maximum_step, "cutaway_materials":overview.materials.size(), "smooth_camera":true,"travel_smoothing_samples":game.bots.travel_smoothing.samples if server else 0,"raw_travel_turn":game.bots.travel_smoothing.raw_turn if server else 0,"smoothed_travel_turn":game.bots.travel_smoothing.smooth_turn if server else 0}
   FileAccess.open(OUT+("server" if server else "client")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
   if not server and spectators==1 and teams==[5,5] and game.local_state().get("spectator",false):
    if not FileAccess.file_exists(OUT+"recording-ready.json"):
     FileAccess.open(OUT+"recording-ready.json",FileAccess.WRITE).store_string(JSON.stringify(report))
   if not server and de.phase=="finished" and not preview:
    if finished_at<0:finished_at=Time.get_ticks_msec()/1000.
    if Time.get_ticks_msec()/1000.-finished_at>=8:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(OUT+"final.png")
     FileAccess.open(OUT+"complete.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
     await create_timer(3).timeout
     game.disconnect_game("Recording complete");quit();return
  await create_timer(1).timeout
