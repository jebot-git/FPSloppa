extends SceneTree
## One local six-round-cap match, spectator camera, and complete movie capture.
var OUT="res://test-results/de-santorini-recording/"
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
 smooth_camera=OS.get_cmdline_user_args().has("--smooth-camera")
 if smooth_camera:OUT="res://test-results/de-santorini-smooth-recording/"
 run.call_deferred()
func camera_frame(delta: float):
 if not is_instance_valid(game) or not game.active or not game.camera:return
 var alive: Array=[]
 for id in game.players:
  if id<0 and not game.players[id].dead and not game.players[id].spectator:alive.append(id)
 if not alive.has(followed) or game.clock>=switch_at:
  if game.fighters.has(followed):game.fighters[followed].show()
  # Prefer the bomb carrier or a bot currently engaged, then rotate perspectives.
  var chosen:=0
  for id in alive:
   if id==game.match_mode.defusal.carrier:chosen=id;break
  if chosen==0 and not alive.is_empty():chosen=alive[posmod(alive.find(followed)+1,alive.size())]
  followed=chosen;switch_at=game.clock+12
 if followed!=0 and game.fighters.has(followed):
  var actor=game.fighters[followed];var s: Dictionary=game.players[followed]
  var eye: Vector3=actor.render_position()+Vector3.UP*actor.eye_height()
  if smooth_camera:
   if camera_subject!=followed:camera_ready=false;camera_yaw=s.yaw;camera_subject=followed
   camera_yaw=lerp_angle(camera_yaw,s.yaw,1-exp(-5*delta))
   var forward: Vector3=Basis(Vector3.UP,camera_yaw)*Vector3.FORWARD
   var desired: Vector3=eye-forward*3.2+Vector3.UP*1.0+forward.cross(Vector3.UP)*.4
   var space=game.get_world_3d().direct_space_state
   var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,desired,1))
   if not hit.is_empty():desired=hit.position+(eye-hit.position).normalized()*.25
   var third: bool=desired.distance_to(eye)>1.0
   if third:
    actor.show()
    var position: Vector3=game.camera.global_position.lerp(desired,1-exp(-10*delta)) if camera_ready else desired
    hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,position,1))
    if not hit.is_empty():position=hit.position+(eye-hit.position).normalized()*.25
    game.camera.global_position=position;game.camera.look_at(eye+forward*4+Vector3.UP*clampf(s.pitch,-.3,.3));camera_ready=true
   else:
    actor.hide();game.camera.global_position=eye;game.camera.rotation=Vector3(s.pitch,camera_yaw,0);camera_ready=false
  else:
   actor.hide();game.camera.global_position=eye;game.camera.rotation=Vector3(s.pitch,s.yaw,0)
  if is_instance_valid(game.viewmodel):game.viewmodel.hide()
  label.text="SANTORINI · 5v5 BOTS · %s\nRound %d / 6  |  %d — %d  |  %s"%[s.name,game.match_mode.defusal.round_id,game.match_mode.scores[0],game.match_mode.scores[1],game.match_mode.defusal.phase.to_upper()]
func run():
 server=OS.get_cmdline_user_args().has("--server")
 DirAccess.make_dir_recursive_absolute(OUT)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 if server:
  game.bot_population.count_target=10;game.bot_population.maintain();game.set_physics_process(false)
  while not FileAccess.file_exists(OUT+"recording-ready.json") or not FileAccess.file_exists(OUT+"capture-started.json"):
   game._send_snapshot();await create_timer(.1).timeout
  game.set_physics_process(true)
 else:
  root.title="FPSloppa · Santorini · 5v5 · Recording"
  var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer)
  label=Label.new();label.position=Vector2(24,65);label.add_theme_font_size_override("font_size",24);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);layer.add_child(label)
  var director:=Director.new();director.update=camera_frame;director.process_priority=1000;root.add_child(director)
 var finished_at:=-1.
 while is_instance_valid(game):
  if game.active and game.current_map=="de_varq_santorini":
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
   var report={"pid":OS.get_process_id(),"map":game.current_map,"bsp_sha256":game.map_sha,"teams":teams,"spectators":spectators,"round":de.round_id,"phase":de.phase,"scores":game.match_mode.scores,"round_cap":2*(de.win_limit-1),"bsp_penetration_ready":pen.ready,"cs_movement_bots":cs_bots,"shots":shots,"kills":kills,"wallbang_probes":game.bots.wallbang.attempts if server else 0,"wallbang_firing_ticks":game.bots.wallbang.firing_ticks if server else 0,"clock":game.clock,"smooth_camera":smooth_camera,"travel_smoothing_samples":game.bots.travel_smoothing.samples if server else 0,"raw_travel_turn":game.bots.travel_smoothing.raw_turn if server else 0,"smoothed_travel_turn":game.bots.travel_smoothing.smooth_turn if server else 0}
   FileAccess.open(OUT+("server" if server else "client")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
   if not server and spectators==1 and teams==[5,5] and game.local_state().get("spectator",false):
    if not FileAccess.file_exists(OUT+"recording-ready.json"):
     FileAccess.open(OUT+"recording-ready.json",FileAccess.WRITE).store_string(JSON.stringify(report))
   if not server and de.phase=="finished":
    if finished_at<0:finished_at=Time.get_ticks_msec()/1000.
    if Time.get_ticks_msec()/1000.-finished_at>=8:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(OUT+"final.png")
     FileAccess.open(OUT+"complete.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
     await create_timer(3).timeout
     game.disconnect_game("Recording complete");quit();return
  await create_timer(1).timeout
