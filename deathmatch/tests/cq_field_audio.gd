extends SceneTree
const Field=preload("res://deathmatch/conquest/classes/field_audio.gd")
const Reload=preload("res://deathmatch/conquest/classes/reload_audio.gd")
var failures:Array=[]
var checks:=0
class Actor extends Node3D:
 var in_water:=false
 var underwater:=false
 func render_position()->Vector3:return global_position
class Classes extends RefCounted:
 var downed:Dictionary={}
 var injecting:Dictionary={}
 var dispensers:Dictionary={}
 func cloaked(_id:int)->bool:return false
 func alive(_id:int)->bool:return true
class Spatial extends Node3D:
 func create_player()->AudioStreamPlayer3D:return AudioStreamPlayer3D.new()
 func configure(_source:AudioStreamPlayer3D)->void:pass
 func occluded(_a:Vector3,_b:Vector3)->bool:return false
class Game extends Node3D:
 var headless:=false
 var active:=true
 var map_epoch:=1
 var clock:=0.
 var quitting:=false
 var camera:Camera3D
 var spatial:Spatial
 var effects=null
 var fighters:Dictionary={}
 var players:Dictionary={}
 var projectiles:Dictionary={}
 var turrets:Dictionary={"rows":{}}
 var classes=Classes.new()
 var battery_tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd").new()
 var variant_combat=preload("res://deathmatch/conquest/classes/combat.gd").new()
 func world_view_camera()->Camera3D:return camera
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 for name in ["ArenaEffects","ArenaAmbience"]:
  if AudioServer.get_bus_index(name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/audio/cq_field/manifest.json"))
 for key in manifest:
  var row:Dictionary=manifest[key];var stream:AudioStream=load("res://deathmatch/audio/cq_field/"+row.file)
  check(stream!=null and absf(stream.get_length()-row.seconds)<.01,"Valid runtime stream: "+key)
  if stream is AudioStreamWAV:check(stream.stereo==false and stream.mix_rate==24000,"Mono positional WAV at 24 kHz: "+key)
 var audio:=Field.new();var state:Dictionary={"downed":false,"dead":false,"injecting":false,"charging":false,"cloaked":false,"wet":false,"locking":false,"locked":false,"position":Vector3.ZERO}
 check(audio.observe_player(1,1,state).is_empty(),"Initial snapshots do not fabricate cues")
 state.charging=true;check(audio.observe_player(1,1,state)==["charge"],"Charge begins once")
 check(audio.observe_player(1,1,state).is_empty(),"Repeated accepted state is silent")
 state.locking=true;check(audio.observe_player(1,1,state)==["lock_acquire"],"Acquisition edge")
 state.locked=true;check(audio.observe_player(1,1,state)==["lock_ready"],"Lock-ready edge")
 state.downed=true;check(audio.observe_player(1,1,state)==["downed"],"Incapacitation edge")
 state.injecting=true;check(audio.observe_player(1,1,state)==["inject_start"],"Injection contact edge")
 state.downed=false;state.injecting=false;check(audio.observe_player(1,1,state)==["revive"],"Successful revival edge")
 state.wet=true;check(audio.observe_player(1,1,state)==["water_enter"],"Entering water edge")
 state.wet=false;check(audio.observe_player(1,1,state)==["water_exit"],"Reaching shore edge")
 state.cloaked=true;audio.observe_player(1,1,state);state.cloaked=false
 check(audio.observe_player(1,1,state)==["cloak_off"],"Cloak exit edge")
 state.charging=false;check(audio.observe_player(1,2,state).is_empty(),"New life primes silently")
 var reload:=Reload.new()
 reload.observe(1,1,5,{}, {"reloading":-1,"clips":{5:0}})
 check(reload.observe(1,1,5,{}, {"reloading":5,"clips":{5:0}})==["magazine_out"],"Desktop pack reload starts without cocking")
 check(reload.observe(1,1,5,{}, {"reloading":5,"clips":{5:0}}).is_empty(),"Repeated reload snapshots are silent")
 check(reload.observe(1,1,5,{}, {"reloading":-1,"clips":{5:3}})==["magazine_in"],"Pack replacement completion cue")
 reload.observe(1,1,11,{}, {"cycling":11,"clips":{11:2}})
 check(reload.observe(1,1,11,{}, {"cycling":-1,"clips":{11:2}})==["cell_cycle"],"Internal charge refresh has no bolt sound")
 reload.free()
 var game:=Game.new();root.add_child(game);game.camera=Camera3D.new();game.camera.position=Vector3(0,2,5);game.add_child(game.camera);game.camera.current=true
 game.spatial=Spatial.new();game.add_child(game.spatial);game.add_child(game.battery_tanks)
 var actor:=Actor.new();game.add_child(actor);game.fighters[1]=actor;game.players[1]={"serial":1,"dead":false,"spectator":false,"weapon":4,"fire":false}
 game.add_child(audio);audio.setup(game);audio.set_process(false);audio._process(.1)
 check(not audio.play_cue("charge",Vector3(0,0,-100),-10,15),"Distant cosmetic cues are culled")
 var recording:=AudioEffectRecord.new();AudioServer.add_bus_effect(0,recording);recording.set_recording_active(true)
 for weapon in Field.SHOTS:audio.shot(weapon,Vector3(0,1,0))
 check(audio.played.size()==Field.SHOTS.size(),"Every weapon family has an audible report")
 check(audio.voices.all(func(p):return p.bus=="ArenaEffects" and p.stream!=null),"Reports use effects bus")
 for i in 40:audio.play_cue("carbine",Vector3(0,1,0))
 check(audio.voices.size()<=Field.MAX_VOICES,"Report voices are bounded")
 for i in 14:game.battery_tanks.rows[i]={"position":Vector3(i*.1,0,0),"hp":100,"pilot":1,"speed":5.,"kind":"light"}
 game.classes.injecting[1]={"progress":1.};audio._process(.1)
 check(audio.loops.size()==Field.MAX_LOOPS,"Engine/injection loops are bounded")
 check(audio.loops.values().all(func(p):return p.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and p.stream.loop_end==roundi(p.stream.get_length()*p.stream.mix_rate)),"Loops use complete edited clips, not hard-coded lengths")
 var heard_damage:bool=audio.played.has("repair")
 game.battery_tanks.rows[0].hp=90;audio._process(.1)
 check(audio.played.has("repair")==heard_damage,"Vehicle damage does not trigger repair cue")
 game.battery_tanks.rows[0].hp=95;audio._process(.1)
 check(audio.played.has("repair"),"Actual restored hull health cues repair")
 for i in 14:game.battery_tanks.rows[i].pilot=0;game.battery_tanks.rows[i].speed=0
 game.classes.injecting.clear();audio._process(.1);check(audio.loops.is_empty(),"Parked engines and broken injection contact stop loops")
 game.classes.dispensers[1]={"position":Vector3.ZERO,"remaining":1000};audio._process(.1)
 check(audio.played.has("deploy"),"New dispenser has deployment cue")
 game.classes.dispensers[1].remaining=990;audio._process(.1);check(audio.played.has("supply"),"Accepted supply transfer emits one cue")
 # Vehicle/turret reports observe existing replicated timestamps, never initial history.
 for kind in ["rocket","light","heavy","turret"]:
  var key:String="fixture:"+kind
  check(not audio.observe_fire(key,5.,kind,Vector3.ZERO),"Initial firing snapshot is silent: "+kind)
  check(audio.observe_fire(key,6.,kind,Vector3.ZERO),"New accepted fire plays: "+kind)
  check(not audio.observe_fire(key,6.,kind,Vector3.ZERO),"Repeated firing snapshot is silent: "+kind)
  check(not audio.observe_fire(key,5.,kind,Vector3.ZERO) and not audio.observe_fire(key,6.,kind,Vector3.ZERO),"Out-of-order timestamps do not replay shots: "+kind)
 check(Field.vehicle_report("transport")=="","Unarmed transport has no report")
 game.projectiles[101]={"position":Vector3(0,1,0),"extra":{"battery_shot":true}}
 game.projectiles[102]={"position":Vector3.ZERO,"extra":{}}
 audio._process(.1)
 check(audio.loops.has("rocket:101") and not audio.loops.has("rocket:102"),"Only rocket-tank projectiles have motor loops")
 game.projectiles[101].position=Vector3(1,1,0);audio._process(.1)
 check(audio.loops["rocket:101"].global_position==Vector3(1,1,0),"Rocket motor follows accepted projectile position")
 game.projectiles[101].stuck=true;audio._process(.1)
 check(not audio.loops.has("rocket:101"),"A stopped/stuck missile no longer emits a travel motor")
 game.projectiles[101].stuck=false;game.projectiles[101].position=Vector3(500,1,0);audio._process(.1)
 check(not audio.loops.has("rocket:101"),"Distant missile motor is culled")
 game.projectiles[101].position=Vector3.ZERO;audio._process(.1)
 check(audio.loops.has("rocket:101"),"Returning missile restarts motor within the shared loop budget")
 game.projectiles.clear();audio._process(.1)
 check(not audio.loops.has("rocket:101"),"Rocket termination stops its motor")
 game.turrets.rows[1]={"position":Vector3.ZERO,"hp":100,"shot_at":1.}
 audio._process(.1);var turret_count:int=audio.played.get("turret_fire",0)
 game.turrets.rows[1].shot_at=2.;audio._process(.1)
 check(audio.played.get("turret_fire",0)==turret_count+1,"Native/script turret timestamps play one report")
 game.turrets.rows.clear();audio._process(.1)
 check(not audio.firing_seen.has("turret:1"),"Removed turret releases firing history")
 await create_timer(.5).timeout
 recording.set_recording_active(false);var captured:=recording.get_recording()
 check(captured!=null and captured.data.size()>0,"Audio mixer produces a capture")
 if captured:
  DirAccess.make_dir_recursive_absolute("res://test-results/cq-field-audio");captured.save_to_wav("res://test-results/cq-field-audio/mix.wav")
 AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 game.active=false;audio._process(.1);check(audio.loops.is_empty() and audio.voices.is_empty() and audio.seen.is_empty(),"Disconnect silences all cues and clears history")
 game.free();await process_frame;await create_timer(.4).timeout
 var result:Dictionary={"checks":checks,"failures":failures,"assets":manifest.size()}
 FileAccess.open("res://test-results/cq-field-audio/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("CQ_FIELD_AUDIO ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
