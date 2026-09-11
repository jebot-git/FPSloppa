extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.headless=false;game.voice.mode=1
 var devices:=AudioServer.get_input_device_list()
 print("CAPTURE_DEVICES ",devices.size())
 for attempt in 2:
  for device in devices:
   game.voice.select_input_device(device)
   await create_timer(.15).timeout
   var mic=game.voice.mic
   var ok: bool=is_instance_valid(mic) and mic.opusencoder!=null and mic.input_mix_rate==AudioServer.get_input_mix_rate()
   print("PASS " if ok else "FAIL ","Native capture switch ",attempt," rate=",AudioServer.get_input_mix_rate())
   if not ok:failures.append("capture failed")
 game.voice.set_mode(0)
 print("PASS " if game.voice.mic==null else "FAIL ","Capture is stopped after switching")
 game.headless=true;game.free();await process_frame;await process_frame
 print("VOICE_CAPTURE_SWITCH_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
