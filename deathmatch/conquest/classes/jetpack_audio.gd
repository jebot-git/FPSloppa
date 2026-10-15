extends Node3D
## Local prediction and accepted remote burns; bounded positional engine loops.
const RANGE:=36.
const VOICES:=16
var game
var loops:Dictionary={}
var ignition:AudioStream
var thrust:AudioStreamWAV
func setup(arena)->void:
 game=arena
 ignition=load("res://deathmatch/audio/cq_field/jetpack_ignite.wav")
 thrust=load("res://deathmatch/audio/cq_field/jetpack_thrust.wav").duplicate();thrust.loop_mode=AudioStreamWAV.LOOP_FORWARD;thrust.loop_begin=0;thrust.loop_end=roundi(thrust.get_length()*thrust.mix_rate)
func burning(actor)->bool:
 var state:Dictionary=actor.jetpack_state
 return actor.alive_state and not actor.spectator and actor.jetpack_enabled and state.mode!=0 and state.age<(1.5 if state.mode==2 else 2.)
func _process(_delta:float)->void:
 if not game:return
 var camera:Camera3D=game.world_view_camera()
 var wanted:Array=[]
 if game.active and camera:
  for id in game.fighters:
   var actor=game.fighters[id]
   if burning(actor) and camera.global_position.distance_squared_to(actor.position)<RANGE*RANGE:wanted.append(id)
  wanted.sort_custom(func(a,b):return camera.global_position.distance_squared_to(game.fighters[a].position)<camera.global_position.distance_squared_to(game.fighters[b].position))
 wanted=wanted.slice(0,VOICES)
 for id in loops.keys():
  if id not in wanted:loops[id].queue_free();loops.erase(id)
 for id in wanted:
  var actor=game.fighters[id]
  if not loops.has(id):
   var player:=AudioStreamPlayer3D.new();player.stream=thrust;player.bus="ArenaEffects";player.volume_db=-14;player.unit_size=2;player.max_distance=RANGE;add_child(player);player.global_position=actor.render_position()+Vector3.UP*1.1;player.play();loops[id]=player
   if actor.jetpack_state.age<.15:
    var start:=AudioStreamPlayer3D.new();start.stream=ignition;start.bus="ArenaEffects";start.volume_db=-10;start.unit_size=2;start.max_distance=RANGE;add_child(start);start.global_position=player.global_position;start.finished.connect(start.queue_free);start.play()
  loops[id].global_position=actor.render_position()+Vector3.UP*1.1;loops[id].pitch_scale=1.08 if actor.jetpack_state.mode==1 else .92
