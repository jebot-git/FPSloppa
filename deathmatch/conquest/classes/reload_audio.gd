extends Node3D
## Accepted reload state edges; late joins and weapon changes are silent.
const CLIPS={"magazine_out":"res://deathmatch/audio/cq_field/magazine_out.wav","magazine_in":"res://deathmatch/audio/cq_field/magazine_in.wav","bolt_pull":"res://deathmatch/audio/cq_field/bolt_pull.wav","bolt_release":"res://deathmatch/audio/cq_field/bolt_release.wav","cell_cycle":"res://deathmatch/audio/cq_field/supply.wav"}
var game
var seen:Dictionary={}
var voices:Array=[]
var streams:Dictionary={}
var elapsed:=0.
func setup(arena)->void:game=arena
func observe(id:int,life:int,weapon:int,state:Dictionary,automatic:Dictionary={})->Array:
 var old:Dictionary=seen.get(id,{})
 var current:Dictionary=state.duplicate();current.life=life;current.weapon=weapon;current.auto_reload=automatic.get("reloading",-1)==weapon;current.cycling=automatic.get("cycling",-1)==weapon;current.loaded=automatic.get("clips",{}).get(weapon,0);seen[id]=current
 if old.is_empty() or old.life!=life or old.weapon!=weapon:return []
 var cues:Array=[]
 if old.get("mag",true)!=current.get("mag",true):cues.append("magazine_in" if current.get("mag",true) else "magazine_out")
 if not state.has("mag"):
  if not old.auto_reload and current.auto_reload:cues.append("magazine_out")
  elif old.auto_reload and not current.auto_reload and current.loaded>old.loaded:cues.append("magazine_in")
 if old.cycling and not current.cycling:cues.append("cell_cycle")
 var before:float=maxf(old.get("stroke",0.),.7 if old.get("locked",false) else 0.)
 var after:float=maxf(current.get("stroke",0.),.7 if current.get("locked",false) else 0.)
 if before<.6 and after>=.6:cues.append("bolt_pull")
 elif before>=.6 and after<.1:cues.append("bolt_release")
 return cues
func play_cue(kind:String,at:Vector3)->void:
 voices=voices.filter(is_instance_valid)
 var camera:Camera3D=game.world_view_camera()
 if not camera or camera.global_position.distance_squared_to(at)>100:return
 if not streams.has(kind):streams[kind]=load(CLIPS[kind])
 if voices.size()>=12:voices.pop_front().queue_free()
 var voice:=AudioStreamPlayer3D.new();voice.stream=streams[kind];voice.bus="ArenaEffects";voice.volume_db=-9;voice.max_distance=10;voice.unit_size=1.;add_child(voice);voice.global_position=at;voice.finished.connect(voice.queue_free);voice.play();voices.append(voice)
func _process(delta:float)->void:
 if not game or not game.active:seen.clear();return
 elapsed+=delta
 if elapsed<.03:return
 elapsed=0
 for id in seen.keys():
  if not game.players.has(id):seen.erase(id)
 for id in game.players:
  var player:Dictionary=game.players[id];var weapon:int=player.weapon
  var automatic:Dictionary=game.variant_combat.magazines.states.get(id,{})
  var state:Dictionary=automatic.get("physical",{}).get(weapon,{})
  var cues:=observe(id,player.serial,weapon,state,automatic)
  if player.dead or not game.fighters.has(id):continue
  for cue in cues:play_cue(cue,game._weapon_transform(id).origin)
