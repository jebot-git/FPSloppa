extends SceneTree
## Run outside the source project after mounting an exported client PCK.
class Arena extends Node3D:
 var headless:=false
 var quitting:=false
 var clock:=0.
 var camera: Camera3D
func _initialize():run.call_deferred()
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()<2 or not ProjectSettings.load_resource_pack(args[0]):quit(2);return
 var spatial=load(args[1]).new()
 var arena:=Arena.new();root.add_child(arena);arena.add_child(spatial);spatial.game=arena
 # Native 3D playback with a dummy device still exercises stream assignment.
 AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaEffects")
 var rows=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/audio/experimental/manifest.json"))
 var bank=load("res://deathmatch/audio/modes/catalog.gd").SOUNDS
 var failures: Array=[];var checked:=0
 for row in rows:
  var kind: String=row.file.trim_suffix(".wav")
  if bank.has(kind):continue # Replaced by the mode bank below.
  var stream: AudioStream=spatial.choose(kind)
  if not stream or stream.get_length()<=0:failures.append(kind);continue
  if absf(stream.get_length()-float(row.seconds))>.02:failures.append(kind+" duration")
  spatial.play(kind,Vector3.ZERO)
  checked+=1
 var mode_rows=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/audio/modes/manifest.json")).outputs
 var lengths: Dictionary={}
 for row in mode_rows:
  var path: String="res://deathmatch/audio/modes/"+row.file
  var stream=load(path)
  if not stream or absf(stream.get_length()-float(row.seconds))>.02:failures.append(row.file+" import/duration")
  lengths[path]=float(row.seconds);checked+=1
 for kind in bank:
  for path in bank[kind]:
   var stream: AudioStream=spatial.choose(kind)
   if not stream or stream.resource_path!=path or absf(stream.get_length()-float(lengths[path]))>.02:failures.append(kind+" variant routing")
  spatial.play(kind,Vector3.ZERO)
 var count: int=spatial.active.size()
 for kind in ["quake_not_a_sound","ut99_../invalid","nonexistent_effect"]:
  spatial.play(kind,Vector3.ZERO)
 if spatial.active.size()!=count:failures.append("Missing sounds allocated playback nodes")
 for i in 4:await process_frame
 spatial.clear();await create_timer(.25).timeout;arena.free();await process_frame
 print("EXPORTED_WEAPON_AUDIO ",JSON.stringify({"pack":args[0],"checked":checked,"passed":failures.is_empty(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
