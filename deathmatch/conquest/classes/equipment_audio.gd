extends Node3D
## Accepted state edges only; proximity cues carry no extra network packets/RPCs.
const RANGE:=8.
const MAX_VOICES:=12
const CLIPS={"nvg":"res://deathmatch/audio/equipment/nvg_toggle.wav","cloak":"res://deathmatch/audio/equipment/cloak_on.wav"}
const LEVELS={"nvg":-18.,"cloak":-20.}
var game
var seen:Dictionary={}
var streams:Dictionary={}
var active:Array=[]
var scan:=0.
var epoch:=-1
var played:Dictionary={"nvg":0,"cloak":0}
func setup(arena):game=arena
func observe(id:int,life:int,nvg:bool,cloak:float,now:float)->Array:
 var cloaked:=cloak>now
 var previous:Dictionary=seen.get(id,{})
 if previous.is_empty() or previous.life!=life:
  seen[id]={"life":life,"nvg":nvg,"cloaked":cloaked}
  return [] # Joining/spawning is not an activation.
 var cues:Array=[]
 if previous.nvg!=nvg:cues.append("nvg")
 if cloaked and not previous.cloaked:cues.append("cloak")
 previous.nvg=nvg;previous.cloaked=cloaked
 return cues
func audible(where:Vector3)->bool:
 var camera:Camera3D=game.world_view_camera()
 return camera!=null and camera.global_position.distance_squared_to(where)<RANGE*RANGE
func play_cue(kind:String,where:Vector3)->bool:
 if kind not in CLIPS or game.headless or not game.active or not audible(where):return false
 if not streams.has(kind):streams[kind]=load(CLIPS[kind])
 var stream:AudioStream=streams[kind]
 if not stream:return false
 active=active.filter(is_instance_valid)
 if active.size()>=MAX_VOICES:active.pop_front().queue_free()
 var source:AudioStreamPlayer3D=game.spatial.create_player();game.spatial.configure(source)
 source.stream=stream;source.volume_db=LEVELS[kind];source.unit_size=1.;source.max_distance=RANGE
 if source.has_method("play_stream"):source.set("min_attenuation_distance",1.)
 else:source.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
 source.pitch_scale=1.;source.set_meta("cue",kind);source.set_meta("expires",Time.get_ticks_msec()/1000.+stream.get_length()+.1)
 add_child(source);source.global_position=where;source.finished.connect(source.queue_free);active.append(source);source.play();played[kind]+=1
 return true
func _process(delta:float)->void:
 if not game:return
 if epoch!=game.map_epoch:seen.clear();epoch=game.map_epoch
 if not game.active:
  seen.clear()
  for source in active:
   if is_instance_valid(source):source.queue_free()
  active.clear();return
 var camera:Camera3D=game.world_view_camera();var now:float=Time.get_ticks_msec()/1000.
 for source in active:
  if not is_instance_valid(source):continue
  var distance:float=camera.global_position.distance_to(source.global_position) if camera else RANGE
  if distance>=RANGE or now>=source.get_meta("expires",0.):source.queue_free();continue
  var level:float=LEVELS[source.get_meta("cue")]+linear_to_db(maxf(.0001,1-smoothstep(4.,RANGE,distance)))
  game.spatial.update_source(source,level)
 active=active.filter(is_instance_valid)
 scan-=delta
 if scan>0:return
 scan=.05
 for id in seen.keys():
  if not game.players.has(id):seen.erase(id)
 for id in game.players:
  if not game.classes.states.has(id):continue
  var player:Dictionary=game.players[id];var state:Dictionary=game.classes.states[id]
  var cues:=observe(id,player.serial,state.get("nv",false),state.get("cloak_until",0.),game.clock)
  if player.dead or player.spectator:continue
  var at:Vector3=game.fighters[id].render_position() if game.fighters.has(id) else Vector3.ZERO
  at+=Vector3.UP*1.4
  for cue in cues:play_cue(cue,at)
