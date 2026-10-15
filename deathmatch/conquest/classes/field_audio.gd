extends Node3D
## Cosmetic audio from accepted snapshots; no RPCs or authority changes.
const ROOT:="res://deathmatch/audio/cq_field/"
const SHOTS={0:"burst_pistol",1:"assault",2:"pistol",3:"smg",4:"carbine",5:"launcher",9:"pistol_suppressed",10:"beam",11:"guided_launcher"}
const MAX_VOICES:=32
const MAX_LOOPS:=10
const VEHICLE_RANGE:=100.
var game
var streams:Dictionary={}
var voices:Array=[]
var loops:Dictionary={}
var seen:Dictionary={}
var vehicle_seen:Dictionary={}
var firing_seen:Dictionary={}
var box_seen:Dictionary={}
var cooldowns:Dictionary={}
var elapsed:=0.
var epoch:=-1
var primed:=false
var ui:AudioStreamPlayer
var played:Dictionary={}
func setup(arena)->void:
 game=arena
 ui=AudioStreamPlayer.new();ui.bus="ArenaEffects";ui.volume_db=-16;add_child(ui)
func stream(kind:String,looped:bool=false)->AudioStream:
 var key:=kind+":"+str(looped)
 if not streams.has(key):
  var resource:AudioStream=load(ROOT+kind+".wav")
  if looped and resource is AudioStreamWAV:
   resource=resource.duplicate();resource.loop_mode=AudioStreamWAV.LOOP_FORWARD;resource.loop_begin=0;resource.loop_end=roundi(resource.get_length()*resource.mix_rate)
  streams[key]=resource
 return streams[key]
func audible(at:Vector3,radius:float)->bool:
 var camera:Camera3D=game.world_view_camera()
 return camera!=null and camera.global_position.distance_squared_to(at)<radius*radius
func play_cue(kind:String,at:Vector3,level:float=-12,radius:float=15)->bool:
 if game.headless or not game.active or not audible(at,radius):return false
 voices=voices.filter(is_instance_valid)
 if voices.size()>=MAX_VOICES:voices.pop_front().queue_free()
 var voice:AudioStreamPlayer3D=game.spatial.create_player();game.spatial.configure(voice)
 voice.stream=stream(kind);voice.bus="ArenaEffects";voice.volume_db=level;voice.unit_size=2.;voice.max_distance=radius
 if voice.has_method("play_stream"):voice.set("min_attenuation_distance",2.)
 voice.set_meta("dry_db",level);voice.set_meta("expires",Time.get_ticks_msec()/1000.+voice.stream.get_length()+.1)
 add_child(voice);voice.global_position=at;voice.finished.connect(voice.queue_free);voice.play();voices.append(voice)
 played[kind]=int(played.get(kind,0))+1;return true
func shot(weapon:int,at:Vector3)->void:
 if not SHOTS.has(weapon):return
 play_cue(SHOTS[weapon],at,-12 if weapon==9 else -6 if weapon in [0,1,3,4] else -4,18 if weapon==9 else 110 if weapon in [5,11] else 90)
static func vehicle_report(kind:String)->String:
 return {"rocket":"rocket_tank_launch","light":"tank_light_fire","heavy":"tank_heavy_fire","turret":"turret_fire"}.get(kind,"")
func observe_fire(key:String,shot_at:float,kind:String,at:Vector3,alive:bool=true)->bool:
 var previous:float=float(firing_seen.get(key,shot_at))
 firing_seen[key]=maxf(previous,shot_at)
 if not alive or shot_at<=previous:return false
 var report:=vehicle_report(kind)
 return not report.is_empty() and play_cue(report,at,-8 if kind=="turret" else -6,110)
func local_cue(kind:String)->void:
 if game.headless or not game.active:return
 ui.stream=stream(kind);ui.play();played[kind]=int(played.get(kind,0))+1
func allow(key:String,seconds:float)->bool:
 if game.clock<float(cooldowns.get(key,-INF)):return false
 cooldowns[key]=game.clock+seconds;return true
func set_loop(key:String,kind:String,at:Vector3,level:float,radius:float,wanted:Dictionary,pitch:float=1.)->void:
 if not audible(at,radius):return
 wanted[key]=true
 if not loops.has(key):
  if loops.size()>=MAX_LOOPS:return
  var voice:AudioStreamPlayer3D=game.spatial.create_player();game.spatial.configure(voice);voice.stream=stream(kind,true);voice.bus="ArenaEffects";voice.max_distance=radius;voice.unit_size=3
  if voice.has_method("play_stream"):voice.set("min_attenuation_distance",3.)
  add_child(voice);voice.global_position=at;voice.play();loops[key]=voice
 var source:AudioStreamPlayer3D=loops[key];source.global_position=at;source.volume_db=level;source.pitch_scale=pitch;source.set_meta("dry_db",level)
func observe_player(id:int,life:int,state:Dictionary)->Array:
 var old:Dictionary=seen.get(id,{})
 var row:=state.duplicate();row.life=life;seen[id]=row
 if old.is_empty() or old.life!=life:return []
 var cues:Array=[]
 if not old.downed and row.downed:cues.append("downed")
 if old.downed and not row.downed and not row.dead:cues.append("revive")
 if not old.injecting and row.injecting:cues.append("inject_start")
 if not old.charging and row.charging:cues.append("charge")
 if old.cloaked and not row.cloaked and not row.dead:cues.append("cloak_off")
 if old.wet!=row.wet:cues.append("water_enter" if row.wet else "water_exit")
 if not old.locking and row.locking:cues.append("lock_acquire")
 if not old.locked and row.locked:cues.append("lock_ready")
 return cues
func clear()->void:
 for source in voices+loops.values():
  if is_instance_valid(source):source.stop();source.queue_free()
 voices.clear();loops.clear();seen.clear();vehicle_seen.clear();firing_seen.clear();box_seen.clear();cooldowns.clear();primed=false
 if ui:ui.stop()
func _process(delta:float)->void:
 if not game:return
 if epoch!=game.map_epoch:clear();epoch=game.map_epoch
 if not game.active or game.headless:
  if primed or not loops.is_empty() or not voices.is_empty():clear()
  return
 elapsed+=delta
 if elapsed<.1:return
 elapsed=0
 var camera:Camera3D=game.world_view_camera()
 if not camera:
  clear();return
 for key in cooldowns.keys():
  if cooldowns[key]<game.clock-5.:cooldowns.erase(key)
 var wanted:Dictionary={};var mine:int=game.multiplayer.get_unique_id()
 for id in seen.keys():
  if not game.players.has(id):seen.erase(id)
 for id in game.players:
  if not game.fighters.has(id):continue
  var player:Dictionary=game.players[id];var actor=game.fighters[id];var at:Vector3=actor.render_position()+Vector3.UP*.9
  var previous:Dictionary=seen.get(id,{})
  var lock:Dictionary=game.variant_combat.vehicle_lock.locks.get(id,{})
  var row:Dictionary={"downed":game.classes.downed.has(id),"dead":player.dead,"injecting":game.classes.injecting.has(id),"charging":game.variant_combat.charges.has(id),"cloaked":game.classes.cloaked(id),"wet":actor.in_water,"locking":not lock.is_empty(),"locked":lock.get("ready",false),"position":at}
  var cues:=observe_player(id,player.serial,row)
  for cue in cues:
   if cue in ["lock_acquire","lock_ready"]:
    if id==mine:local_cue(cue)
   elif cue=="downed":
    if game.effects:game.effects.play("pain",at,-10)
   else:play_cue(cue,at,-16 if cue in ["cloak_off","charge"] else -12,8 if cue=="cloak_off" else 18)
  if player.dead or player.spectator:continue
  if row.injecting:set_loop("inject:"+str(id),"inject_loop",at,-24,8,wanted)
  if id==mine and row.wet and not previous.is_empty() and at.distance_to(previous.position)>.12 and allow("swim",.65):play_cue("swim",at,-19,10)
 # Rocket motors follow existing accepted projectile state; no additional network traffic.
 if game.get("projectiles") is Dictionary:
  var rockets:Array=game.projectiles.keys()
  rockets.sort_custom(func(a,b):return camera.global_position.distance_squared_to(game.projectiles[a].position)<camera.global_position.distance_squared_to(game.projectiles[b].position))
  for key in rockets:
   var rocket:Dictionary=game.projectiles[key]
   if not rocket.get("stuck",false) and rocket.get("extra",{}).get("battery_shot",false):set_loop("rocket:"+str(key),"rocket_tank_travel",rocket.position,-18,90,wanted)
 # Only nearby, occupied or moving hulls have running engines. Nearest wins the voice budget.
 var vehicles:Array=game.battery_tanks.rows.keys()
 vehicles.sort_custom(func(a,b):return camera.global_position.distance_squared_to(game.battery_tanks.rows[a].position)<camera.global_position.distance_squared_to(game.battery_tanks.rows[b].position))
 for key in vehicles:
  var row:Dictionary=game.battery_tanks.rows[key];var old:Dictionary=vehicle_seen.get(key,{})
  observe_fire("vehicle:"+str(key),float(row.get("shot_at",-100.)),row.kind,row.position+Vector3.UP,row.hp>0)
  var running:bool=row.hp>0 and (row.pilot!=0 or absf(row.speed)>.2)
  if not old.is_empty():
   if old.running!=running and row.hp>0:play_cue("engine_start" if running else "engine_stop",row.position,-12,VEHICLE_RANGE)
   if row.hp>old.hp and old.hp>0 and allow("repair:"+str(key),.65):play_cue("repair",row.position,-18,12)
  vehicle_seen[key]={"running":running,"hp":row.hp}
  if running:
   var kind:String="engine_transport" if row.kind=="transport" else "engine_hover" if row.kind in ["light","heavy"] else "engine_heavy"
   set_loop("vehicle:"+str(key),kind,row.position+Vector3.UP,-18,VEHICLE_RANGE,wanted,lerpf(.85,1.3,clampf(absf(row.speed)/10,0,1)))
 for key in vehicle_seen.keys():
  if not game.battery_tanks.rows.has(key):vehicle_seen.erase(key)
 # Replicated firing timestamps work for native and script authority; RPC flashes stay silent.
 if game.get("turrets"):
  for key in game.turrets.rows:
   var row:Dictionary=game.turrets.rows[key]
   observe_fire("turret:"+str(key),float(row.get("shot_at",-100.)),"turret",row.position+Vector3.UP,row.hp>0)
 for key in firing_seen.keys():
  var parts:=str(key).split(":");var id:=int(parts[1])
  if (parts[0]=="vehicle" and not game.battery_tanks.rows.has(id)) or (parts[0]=="turret" and (not game.get("turrets") or not game.turrets.rows.has(id))):firing_seen.erase(key)
 for key in game.classes.dispensers:
  var box:Dictionary=game.classes.dispensers[key];var old:Dictionary=box_seen.get(key,{})
  if old.is_empty():
   if primed:play_cue("deploy",box.position,-12,15)
  elif box.remaining<old.remaining and allow("supply:"+str(key),1.):play_cue("supply",box.position,-18,8)
  box_seen[key]={"remaining":box.remaining}
 for key in box_seen.keys():
  if not game.classes.dispensers.has(key):box_seen.erase(key)
 for key in loops.keys():
  if not wanted.has(key):loops[key].stop();loops[key].queue_free();loops.erase(key)
 voices=voices.filter(is_instance_valid)
 for source in voices+loops.values():
  if source in voices and Time.get_ticks_msec()/1000.>=source.get_meta("expires",INF):source.queue_free();continue
  var blocked:bool=game.spatial.occluded(camera.global_position,source.global_position)
  source.volume_db=float(source.get_meta("dry_db",-12))-(10 if blocked else 0)
  source.attenuation_filter_cutoff_hz=1800 if blocked else 18000
 # UI clicks only describe the local empty clip, never another player's inventory.
 if game.players.has(mine) and game.classes.alive(mine):
  var player:Dictionary=game.players[mine];var mag:Dictionary=game.variant_combat.magazines.states.get(mine,{})
  if player.get("fire",false) and player.weapon in SHOTS and mag.get("clips",{}).get(player.weapon,1)==0 and mag.get("reloading",-1)<0 and allow("empty",.8):local_cue("empty")
 primed=true
