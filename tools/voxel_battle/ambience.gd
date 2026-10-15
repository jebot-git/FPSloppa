extends Node
## Quiet environmental beds only; no score, combat stingers or network traffic.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const POI=["market","foundry","docks","bastion","data","transit","garden","docks","arcology","observatory","cathedral"]
var game
var day:AudioStreamPlayer
var night:AudioStreamPlayer
var beds:Dictionary={}
var weights:Dictionary={}
var selected:=-1
var scan:=0.
func loop(path:String)->AudioStreamOggVorbis:
 var stream:=AudioStreamOggVorbis.load_from_file(path)
 if stream:stream.loop=true
 return stream
func player(stream:AudioStream)->AudioStreamPlayer:
 var p:=AudioStreamPlayer.new();p.stream=stream;p.bus="ArenaAmbience" if AudioServer.get_bus_index("ArenaAmbience")>=0 else "Master";p.volume_db=-80;add_child(p)
 if stream:p.play()
 return p
func setup(arena)->void:
 game=arena
 if game.headless:set_process(false);return
 day=player(loop("res://deathmatch/audio/jungle/day.ogg"));night=player(loop("res://deathmatch/audio/jungle/night.ogg"))
func _process(delta:float)->void:
 if not day or not game.active:return
 var camera:Camera3D=game.world_view_camera()
 if not camera:return
 scan-=delta
 if scan<=0:
  scan=.25;selected=-1;var best:=INF
  for i in Landscape.CENTERS.size():
   var distance:float=Vector2(camera.global_position.x-Landscape.CENTERS[i].x,camera.global_position.z-Landscape.CENTERS[i].z).length()
   if distance<Landscape.RADII[i]+35 and distance<best:best=distance;selected=i
  if selected>=0 and not beds.has(selected):
   if beds.size()>=2:
    var oldest:int=beds.keys()[0]
    for key in beds:
     if weights[key]<weights[oldest]:oldest=key
    beds[oldest].queue_free();beds.erase(oldest);weights.erase(oldest)
   beds[selected]=player(loop("res://deathmatch/audio/cq/"+POI[selected]+".ogg"));weights[selected]=0.
 var phase:float=preload("res://tools/voxel_battle/jungle_sky.gd").cycle_phase(game.battle_map.lighting.cycle_time(),1200.) if game.battle_map and game.battle_map.lighting else 0.
 var darkness:float=smoothstep(.27,.36,phase)*(1-smoothstep(.64,.75,phase))
 var duck:float=.4 if game.voice and game.voice.transmitting else 1.
 var outdoors:float=.55 if selected>=0 else 1.
 day.volume_db=linear_to_db(maxf(.0001,(1-darkness)*outdoors*duck))
 night.volume_db=linear_to_db(maxf(.0001,darkness*outdoors*duck))
 for key in beds.keys():
  weights[key]=move_toward(weights[key],1. if key==selected else 0.,delta/2.5)
  beds[key].volume_db=-10+linear_to_db(maxf(.0001,weights[key]*duck))
  if weights[key]<=0. and key!=selected:beds[key].queue_free();beds.erase(key);weights.erase(key)
