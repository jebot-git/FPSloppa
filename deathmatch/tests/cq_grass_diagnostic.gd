extends SceneTree
class Arena extends Node3D:
 var headless:=false
 var active:=true
 var camera:Camera3D
 var battle_map
 var fighters:Dictionary={}
 var players:Dictionary={1:{"dead":false,"spectator":false,"slow":false}}
 var clock:=0.
 func is_vr()->bool:return false
class TestMap extends Node3D:
 var grass
class Actor extends Node3D:
 var local_player:=false
 var visual_grounded:=true
 var stance:="stand"
 func is_supported()->bool:return visual_grounded
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func move(arena,audio,actor)->void:
 for i in 8:
  actor.position.x+=.5;arena.camera.position=actor.position+Vector3.UP*1.7;arena.clock+=.11;audio._process(.11)
func _initialize()->void:run.call_deferred()
func run()->void:
 var arena:=Arena.new();root.add_child(arena)
 var map:=TestMap.new();arena.add_child(map);arena.battle_map=map
 map.grass=preload("res://tools/voxel_battle/grass.gd").new();map.add_child(map.grass)
 var actor:=Actor.new();arena.add_child(actor);actor.position=Vector3(-1000,3,-300);arena.fighters[1]=actor
 arena.camera=Camera3D.new();arena.add_child(arena.camera)
 var audio=preload("res://tools/voxel_battle/grass_audio.gd").new();arena.add_child(audio);audio.setup(arena);audio.set_process(false);audio.profiling_enabled=true
 var rows:=PackedVector4Array()
 for x in range(-1002,-970):rows.append(Vector4(x,3,-300,1))
 var coord:Vector2i=audio.Landscape.bin_key(Vector2(-1000,-300));map.grass.load_tile(coord,{"grass":rows,"height_bounds":Vector2(3,3)})
 move(arena,audio,actor)
 check(audio.scans==8 and audio.emissions>0,"normal running performs scans and emits rustles")
 check(audio.cell_builds==0 if audio.native_audio and map.grass.native_world else audio.cell_builds>0,"native audio reuses grass cache; reference index construction counted")
 audio.set_enabled(false)
 check(audio.voices.all(func(v):return not v.playing),"audio off stops already playing voices")
 var scans:int=audio.scans;var emissions:int=audio.emissions
 move(arena,audio,actor)
 check(audio.scans==scans and audio.emissions==emissions and audio.update_us==0,"audio off bypasses scans and playback")
 audio.set_enabled(true);audio.set_playback_enabled(false);move(arena,audio,actor)
 check(audio.scans>scans and audio.emissions==emissions,"query-only condition still scans without emitting")
 check(audio.voices.all(func(v):return not v.playing),"query-only condition remains silent")
 audio.set_playback_enabled(true);move(arena,audio,actor)
 check(audio.emissions>emissions,"normal playback resumes after isolated conditions")
 arena.free();await process_frame
 print("CQ_GRASS_DIAGNOSTIC ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
