extends SceneTree
## Opt-in local live-device probe. No telemetry leaves this machine.
const LOG_PATH="res://test-results/live-vr.jsonl"
const STATUS_PATH="res://test-results/live-vr-status.json"
const COMMAND_PATH="res://test-results/live-vr-command.json"
var game
var log_file: FileAccess
var elapsed:=0.0
var phase:="menu"
var last_command:=""
var last_inventory:=""
var test_sound:AudioStreamPlayer
var tone_until:=0
var tone_at:=0
func _initialize():call_deferred("start")
func start():
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);current_scene=game
 if OS.get_cmdline_user_args().has("--standard-audio"):
  game.presentation.spatial_audio="stereo";game.spatial.apply_backend()
 elif OS.get_cmdline_user_args().has("--steam-audio"):
  game.presentation.spatial_audio="steam_audio";game.spatial.apply_backend()
 root.audio_listener_enable_2d=true;root.audio_listener_enable_3d=true
 if not game.is_vr():push_error("LIVE_VR: OpenXR did not initialize");quit(2);return
 log_file=FileAccess.open(LOG_PATH,FileAccess.WRITE)
 print("LIVE_VR_READY runtime=",XRServer.find_interface("OpenXR").get_system_info())
 process_frame.connect(sample)
func vector(v: Vector3) -> Array:return [snappedf(v.x,.0001),snappedf(v.y,.0001),snappedf(v.z,.0001)]
func pose(t: Transform3D) -> Dictionary:return {"p":vector(t.origin),"x":vector(t.basis.x),"y":vector(t.basis.y),"z":vector(t.basis.z)}
func sample():
 elapsed+=root.get_process_delta_time()
 if elapsed<.1:return
 elapsed=0
 command()
 if OS.get_cmdline_user_args().has("--voice-monitor") and game.active and game.multiplayer.is_server():
  for id in game.players:
   if id!=1 and game.players[id].spectator and game.players[id].name.begins_with("Local voice"):
    game.fighters[id].global_position=game.camera.global_position+game.camera.global_basis.x*1.5-Vector3.UP*1.55
 if Time.get_ticks_msec()<tone_until and Time.get_ticks_msec()>tone_at:
  test_sound.play();tone_at=Time.get_ticks_msec()+1500
 var rig=game.xr_rig
 var xr=XRServer.find_interface("OpenXR")
 var buses: Array=[]
 for i in range(AudioServer.bus_count):
  buses.append({"name":AudioServer.get_bus_name(i),"mute":AudioServer.is_bus_mute(i),"volume":AudioServer.get_bus_volume_db(i),"peak":AudioServer.get_bus_peak_volume_left_db(i,0),"send":AudioServer.get_bus_send(i)})
 var trackers: Dictionary={}
 for key in XRServer.get_trackers(XRServer.TRACKER_ANY):
  var tracker=XRServer.get_tracker(key)
  var entry:={"class":tracker.get_class(),"description":tracker.get_tracker_desc()}
  if tracker is XRPositionalTracker:
   for name in ["default","grip","aim","tracker_pose"]:
    if tracker.has_pose(name):
     var p=tracker.get_pose(name);entry[name]={"tracked":p.has_tracking_data,"confidence":p.tracking_confidence,"pose":pose(p.get_adjusted_transform())}
  if tracker is XRBodyTracker:
   entry.active=tracker.has_tracking_data;entry.joints={}
   for name in rig.tracking.JOINTS:
    var index:int=rig.tracking.JOINTS[name]
    entry.joints[name]={"flags":tracker.get_joint_flags(index),"pose":pose(tracker.get_joint_transform(index))}
  if tracker is XRHandTracker:
   entry.active=tracker.has_tracking_data;entry.source=tracker.hand_tracking_source
   entry.curls=Array(preload("res://deathmatch/vr/hand_input.gd").sample(null,tracker))
  if tracker is XRFaceTracker:
   entry.blink=[tracker.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT),tracker.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_RIGHT)]
  trackers[str(key)]=entry
 # Some vendor face trackers are retrievable by name but absent from the type inventory.
 var face=XRServer.get_tracker("/user/face_tracker") as XRFaceTracker
 if face:trackers["/user/face_tracker"]={"class":face.get_class(),"blink":[face.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT),face.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_RIGHT)]}
 var actor=game.fighters.get(game.multiplayer.get_unique_id())
 var sampled:Dictionary=rig.sample_pose()
 var body:Dictionary={}
 for key in sampled.get("body",{}):
  if sampled.body[key] is Transform3D:body[key]=pose(sampled.body[key])
  elif sampled.body[key] is PackedFloat32Array:body[key]=Array(sampled.body[key])
 var controls:Dictionary={}
 for side in ["left","right"]:
  var c=rig.get(side)
  controls[side]={"grip_tracked":c.get_has_tracking_data(),"aim_tracked":rig.get(side+"_aim").get_has_tracking_data(),"trigger":c.get_float("trigger"),"grip":c.get_float("grip"),"stick":str(c.get_vector2("primary")),"a":c.is_button_pressed("ax_button"),"b":c.is_button_pressed("by_button"),"trigger_touch":c.is_button_pressed("trigger_touch"),"thumbrest_touch":c.is_button_pressed("thumbrest_touch"),"ax_touch":c.is_button_pressed("ax_touch"),"by_touch":c.is_button_pressed("by_touch"),"primary_touch":c.is_button_pressed("primary_touch"),"secondary_touch":c.is_button_pressed("secondary_touch")}
 var report:={"ms":Time.get_ticks_msec(),"phase":phase,"focused":rig.focused,"active":game.active,"menu":game.menu_open,"fps":Engine.get_frames_per_second(),"head":pose(rig.head.transform),"head_world":vector(rig.head.global_position),"origin":pose(rig.origin.transform),"yaw":game.local_yaw,"actor":vector(actor.position) if actor else [],"head_capsule_offset":vector(rig.head.global_position-actor.position) if actor else [],"blackout":rig.blackout.visible,"body_visible":actor.local_body_visible if actor else false,"pose_valid":not sampled.is_empty(),"body":body,"tracking_status":rig.tracking.status,"tracking_enabled":rig.tracking.enabled,"native_calibration":str(rig.tracking.native_corrections),"calibration":rig.tracking.corrections.keys(),"osc_roles":rig.tracking.osc.current(Time.get_ticks_msec()*.001).keys(),"controls":controls,"trackers":trackers,"turn":{"smooth":rig.smooth_turn,"speed":rig.turn_speed,"snap":rig.snap_angle},"lobby":game.lobby.active(),"voice_packets":game.voice.sequence,"voice_received":game.voice.received_packets,"voice_decoded_peak":game.voice.decoded_peak,"mouth_pose":Array(game.voice.mouth_pose(game.multiplayer.get_unique_id())),"voice_mode":game.voice.mode,"voice_transmitting":game.voice.transmitting,"voice_meter":game.voice.meter,"voice_status":game.voice.message,"audio_input":AudioServer.input_device,"audio_output":AudioServer.output_device,"audio_buses":buses,"listener":root.audio_listener_enable_3d,"render_size":str(xr.get_render_target_size()),"texture_filter":game.presentation.get("texture_filter",2),"render_multiplier":xr.render_target_size_multiplier,"scale3d":root.scaling_3d_scale,"vrs":root.vrs_mode}
 if actor:
  report["water"]={"swimming":actor.in_water,"underwater":actor.underwater,"air":actor.air_left}
  report["motion"]={"physics_hz":Engine.physics_ticks_per_second,"render_position":vector(actor.render_position()),"grounded":actor.is_on_floor(),"velocity":vector(actor.velocity)}
 if game.players.has(-99):report["kick_target_health"]=game.players[-99].hp
 if game.players.has(1):
  report["kick_hits"]=[game.players[1].get("left_kick",{}).get("hit",false),game.players[1].get("right_kick",{}).get("hit",false)]
 var wall=game.get_node_or_null("Map/WaitingRoom/VoteWall")
 if wall:
  report["wall_vote"]={"mode":wall.panel.selector.modes.value,"map":wall.panel.selector.maps.value,"mode_open":wall.panel.selector.modes.popup.visible,"map_open":wall.panel.selector.maps.popup.visible,"status":wall.panel.status.text}
 var mirror=game.get_node_or_null("Map/WaitingRoom/TrackingMirror")
 if mirror and is_instance_valid(mirror.avatar):
  report["mirror_mouth"]=Array(mirror.avatar.mouth.weights)
  report["mirror_blink"]=[mirror.avatar.eyes.blink.x,mirror.avatar.eyes.blink.y]
 log_file.store_line(JSON.stringify(report));log_file.flush()
 var status:=FileAccess.open(STATUS_PATH,FileAccess.WRITE);status.store_string(JSON.stringify(report,"  "));status.close()
 var inventory:=str(trackers.keys())+str(body.keys())+str(rig.focused)
 if inventory!=last_inventory:print("LIVE_VR_TRACKERS ",inventory);last_inventory=inventory
func command():
 if not FileAccess.file_exists(COMMAND_PATH):return
 var text:=FileAccess.get_file_as_string(COMMAND_PATH)
 if text==last_command:return
 last_command=text
 var data=JSON.parse_string(text)
 if not data is Dictionary:return
 phase=str(data.get("phase",phase))
 match data.get("action",""):
  "practice":
   if game.active and game.practice:game.disconnect_game()
   if not game.active:
    game.bind_address="127.0.0.1";game.start_host(game.nickname,29108,20,10,false,str(data.get("mode","dm")))
   if game.bots:game.bots.free();game.bots=null
   for id in game.players.keys():
    if id<0:game.fighters[id].free();game.fighters.erase(id);game.players.erase(id)
   game.players[1].invulnerable=0 if game.match_mode.kind=="cc" else game.clock+3600
  "lobby":
   game.votes.allowed_modes=["dm","ctf","koth"];game.mode_maplists={"dm":["lqdm1","lqdm2"],"ctf":["lqdm1"],"koth":["lqdm2"]}
   game.lobby.enabled=true;game.lobby.seconds=600;game.lobby.begin()
  "drag_test":
   var wall=game.get_node_or_null("Map/WaitingRoom/VoteWall")
   if wall:
    var entries: Array=[]
    var modes: Array=game.votes.allowed_modes.duplicate()
    for i in 12:modes.append("drag_test_mode_%02d"%(i+1))
    for mode in modes:
     for i in 18:
      var row:={"mode":mode,"map":"drag_test_map_%02d"%(i+1),"title":"DRAG TEST MAP %02d"%(i+1),"votes":0}
      if mode.begins_with("drag_test_"):row.mode_title="DRAG TEST MODE "+mode.right(2)
      entries.append(row)
    wall.panel.set_meta("drag_test_options",entries);wall.panel.refresh()
  "kick_target":
   if not game.players.has(-99):game._add_player(-99,"Kick target")
   game.players[-99].hp=100;game.players[-99].invulnerable=0
   game.fighters[-99].position=game.fighters[1].position+Basis(Vector3.UP,game.local_yaw)*Vector3(0,0,-1)
  "capture_feedback":game.match_mode.capture_feedback(0,game.nickname,1)
  "end_lobby":game.lobby.until=game.clock
  "vote_alert":
   game.votes.ballot={"kind":"match","value":"ctf|lqdm1","eligible":[1,2,3],"votes":{2:true},"needed":2,"until":game.clock+60}
  "menu":game.menu_open=true;game.hud.show_menu(true)
  "calibrate":game.xr_rig.tracking.enabled=true;game.xr_rig.tracking.calibrate()
  "recenter":game.xr_rig.recenter()
  "damage":game._hurt_fx(1,game.fighters[1].position+Vector3.UP,Vector3.BACK,10,false,false,1)
  "audio_test":
   if not test_sound:
    test_sound=AudioStreamPlayer.new();test_sound.stream=load("res://deathmatch/audio/pain.wav");test_sound.volume_db=-12;root.add_child(test_sound)
   tone_until=Time.get_ticks_msec()+15000;tone_at=0
  "stop":game.request_quit()
 print("LIVE_VR_PHASE ",phase," action=",data.get("action","mark"))
