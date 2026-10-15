extends Node
## Quiet environmental beds only; no score, combat stingers or network traffic.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const POI=["","industrial","river","industrial","industrial","industrial","river","river","","industrial",""]
var game
var day:AudioStreamPlayer
var river:AudioStreamPlayer3D
var submerged:AudioStreamPlayer
var night:AudioStreamPlayer
var beds:Dictionary={}
var weights:Dictionary={}
var selected:=-1
var scan:=0.
var river_near:=false
func loop(path:String)->AudioStreamOggVorbis:
 var stream:=load(path) as AudioStreamOggVorbis
 if stream:stream=stream.duplicate()
 if stream:stream.loop=true
 return stream
func player(stream:AudioStream)->AudioStreamPlayer:
 var p:=AudioStreamPlayer.new();p.stream=stream;p.bus="ArenaAmbience" if AudioServer.get_bus_index("ArenaAmbience")>=0 else "Master";p.volume_db=-80;add_child(p)
 if stream:p.play()
 return p
func setup(arena)->void:
 game=arena
 if game.headless:set_process(false);return
 submerged=player(loop("res://deathmatch/audio/cq_field/submerged.ogg"))
 river=AudioStreamPlayer3D.new();river.stream=loop("res://deathmatch/audio/cq_field/river.ogg");river.bus="ArenaAmbience" if AudioServer.get_bus_index("ArenaAmbience")>=0 else "Master";river.max_distance=45;river.unit_size=6;river.volume_db=-80;add_child(river);river.play()
 day=player(loop("res://deathmatch/audio/cq_field/forest_day.ogg"));night=player(loop("res://deathmatch/audio/cq_field/forest_night.ogg"))
func _process(delta:float)->void:
 if not day:return
 if not game.active:
  day.volume_db=-80;night.volume_db=-80;river.volume_db=-80;submerged.volume_db=-80
  for bed in beds.values():bed.volume_db=-80
  return
 var camera:Camera3D=game.world_view_camera()
 if not camera:return
 scan-=delta
 if scan<=0:
  scan=.25;selected=-1;var best:=INF
  var nearest:=INF;var river_point:=Vector3.ZERO
  for waterway in Landscape.Hydrology.RIVERS:
   for i in waterway.points.size()-1:
    var a:Vector3=waterway.points[i];var b:Vector3=waterway.points[i+1];var edge:=Vector2(b.x-a.x,b.z-a.z)
    var t:=clampf(Vector2(camera.global_position.x-a.x,camera.global_position.z-a.z).dot(edge)/edge.length_squared(),0,1)
    var at:=a.lerp(b,t);var distance:=camera.global_position.distance_squared_to(at)
    if distance<nearest:nearest=distance;river_point=at
  river.global_position=river_point;river_near=nearest<45*45
  for i in Landscape.CENTERS.size():
   var distance:float=Vector2(camera.global_position.x-Landscape.CENTERS[i].x,camera.global_position.z-Landscape.CENTERS[i].z).length()
   if distance<Landscape.RADII[i]+35 and distance<best:best=distance;selected=i
  if selected>=0 and not POI[selected].is_empty() and not beds.has(selected):
   if beds.size()>=2:
    var oldest:int=beds.keys()[0]
    for key in beds:
     if weights[key]<weights[oldest]:oldest=key
    beds[oldest].queue_free();beds.erase(oldest);weights.erase(oldest)
   beds[selected]=player(loop("res://deathmatch/audio/cq_field/"+POI[selected]+".ogg"));weights[selected]=0.
 var phase:float=preload("res://tools/voxel_battle/jungle_sky.gd").cycle_phase(game.battle_map.lighting.cycle_time(),1200.) if game.battle_map and game.battle_map.lighting else 0.
 var darkness:float=smoothstep(.27,.36,phase)*(1-smoothstep(.64,.75,phase))
 var duck:float=.4 if game.voice and game.voice.transmitting else 1.
 var actor=game.fighters.get(game.multiplayer.get_unique_id())
 var wet:bool=is_instance_valid(actor) and actor.underwater
 submerged.volume_db=-13+linear_to_db(duck) if wet else -80
 river.volume_db=-15+linear_to_db(duck*(.2 if wet else 1.)) if river_near else -80
 var outdoors:float=(.55 if selected>=0 else 1.)*(.25 if wet else 1.)
 if game.battle_map and game.battle_map.lighting:outdoors*=lerpf(1.,.45,game.battle_map.lighting.weather_cloud)
 day.volume_db=linear_to_db(maxf(.0001,(1-darkness)*outdoors*duck))
 night.volume_db=linear_to_db(maxf(.0001,darkness*outdoors*duck))
 for key in beds.keys():
  weights[key]=move_toward(weights[key],1. if key==selected else 0.,delta/2.5)
  beds[key].volume_db=-10+linear_to_db(maxf(.0001,weights[key]*duck*(.2 if wet else 1.)))
  if weights[key]<=0. and key!=selected:beds[key].queue_free();beds.erase(key);weights.erase(key)
