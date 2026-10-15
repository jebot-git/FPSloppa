extends SceneTree
const Prefs=preload("res://deathmatch/settings/preferences.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var checks:=0
var failures:Array=[]
class Actor extends Node3D:
 var jetpack_state:Dictionary={"mode":1,"age":.02}
 var jetpack_enabled:=true
 var alive_state:=true
 var spectator:=false
 var local_player:=true
 var visual_grounded:=true
 var stance:="standing"
 func render_position():return global_position
 func is_supported():return true
class GrassData extends Node:
 var tiles:Dictionary={}
class MapData extends Node3D:
 var grass:Node
class Game extends Node3D:
 var active:=true
 var headless:=false
 var fighters:Dictionary={}
 var players:Dictionary={}
 var camera:Camera3D
 var battle_map
 var voice=null
 var clock:=0.
 func world_view_camera():return camera
 func is_vr():return false
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var owned:Array=[]
 for name in ["ArenaEffects","ArenaAmbience"]:
  if AudioServer.get_bus_index(name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name);owned.append(name)
 Prefs.bus_volume("ArenaEffects",.8);Prefs.bus_volume("ArenaAmbience",.2)
 check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("ArenaAmbience")))-.2)<.001,"ambience has independent volume gain")
 Prefs.bus_volume("ArenaEffects",0.)
 check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("ArenaAmbience")),"muting effects does not mute ambience")
 Prefs.bus_volume("ArenaEffects",1.)
 var values:=Prefs.defaults();values.ambience=.37;values.foveation_dynamic=false
 check(Prefs.save_settings(values,"/tmp/cq-rec-review/audio-profile.cfg")==OK,"audio and foveation settings save")
 var saved:=Prefs.read_settings("/tmp/cq-rec-review/audio-profile.cfg")
 check(is_equal_approx(saved.ambience,.37) and not saved.foveation_dynamic,"ambience and foveation modes persist")
 var game:=Game.new();root.add_child(game);game.camera=Camera3D.new();game.add_child(game.camera)
 var actor:=Actor.new();game.add_child(actor);game.fighters[1]=actor;game.players[1]={"dead":false,"spectator":false,"slow":false}
 var jet=load("res://deathmatch/conquest/classes/jetpack_audio.gd").new();game.add_child(jet);jet.setup(game);jet.set_process(false);jet._process(.01)
 check(jet.loops.size()==1 and jet.loops[1].playing,"accepted burn starts positional jetpack audio")
 check(jet.loops[1].stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and jet.loops[1].max_distance==36 and jet.loops[1].bus=="ArenaEffects","jetpack audio loops within nearby effects channel")
 actor.jetpack_state.age=3.;jet._process(.01)
 check(jet.loops.is_empty(),"jetpack sound stops when thrust ends")
 game.battle_map=MapData.new();game.add_child(game.battle_map);game.battle_map.grass=GrassData.new();game.battle_map.add_child(game.battle_map.grass)
 game.battle_map.grass.tiles[Landscape.bin_key(Vector2.ZERO)]={"rows":PackedVector4Array([Vector4(0,0,0,1)])}
 var grass=load("res://tools/voxel_battle/grass_audio.gd").new();game.add_child(grass);grass.setup(game);grass.set_process(false);grass._process(.1)
 for i in 10:actor.position.x+=.1;game.clock+=.1;grass._process(.1)
 check(grass.emissions==0,"walking through actual grass contact emits no rustle")
 actor.position=Vector3.ZERO;grass.previous[1]=Vector3.ZERO;actor.position.x=.4;game.clock+=.1;grass._process(.1)
 check(grass.emissions==1 and grass.voices[0].volume_db<=-26.,"running rustle is fourteen decibels quieter")
 game.players[1].slow=true;actor.position.x=.8;game.clock+=.4;grass._process(.1)
 check(grass.emissions==1,"walk modifier suppresses rustle even with stale high displacement")
 var ambient=load("res://tools/voxel_battle/ambience.gd").new();game.add_child(ambient);ambient.setup(game);ambient.set_process(false)
 check(ambient.day.bus=="ArenaAmbience" and ambient.night.bus=="ArenaAmbience","adaptive ambience uses its dedicated bus")
 var reload=load("res://deathmatch/conquest/classes/reload_audio.gd").new();game.add_child(reload);reload.setup(game);reload.set_process(false)
 reload.observe(1,1,2,{"mag":true,"stroke":0.})
 check(reload.observe(1,1,2,{"mag":false,"stroke":0.})==["magazine_out"],"accepted ejection produces magazine sound")
 check(reload.observe(1,1,2,{"mag":true,"stroke":0.})==["magazine_in"],"accepted insertion produces magazine sound")
 check(reload.observe(1,1,2,{"mag":true,"stroke":1.})==["bolt_pull"],"charging stroke produces bolt sound")
 check(reload.observe(1,1,2,{"mag":true,"stroke":0.})==["bolt_release"],"charging return produces release sound")
 check(reload.observe(1,2,2,{"mag":true,"stroke":1.}).is_empty(),"late join/new life does not replay reload sounds")
 game.queue_free();await process_frame;await process_frame
 for name in owned:AudioServer.remove_bus(AudioServer.get_bus_index(name))
 print("CQ_LIVE_AUDIO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
