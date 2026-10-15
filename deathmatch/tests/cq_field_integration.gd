extends SceneTree
var game
var failures:Array=[]
var checks:=0
class LightClock extends RefCounted:
 var seconds:=0.
 var weather_cloud:=0.
 func cycle_time()->float:return seconds
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var map=game.BattleMap.new();game.add_child(map);game.battle_map=map;game.spawn_points=[Vector3.ZERO];game.spawn_yaws=[0]
 game.start_host("Field audio integration",0,200,10,true,"tdm","ut99")
 game.camera.global_position=Vector3(0,1.5,0)
 check(game.field_audio!=null,"CQ client creates field audio service")
 check(game.jungle_ambience.day.stream is AudioStreamOggVorbis,"Recorded ambience loads through resource imports")
 for weapon in game.field_audio.SHOTS:game.field_audio.shot(weapon,Vector3(0,1,-2))
 check(game.field_audio.played.size()==9,"All weapon reports run through the real CQ spatial backend")
 check(game.field_audio.voices.all(func(p):return p.playing and p.bus=="ArenaEffects"),"Real spatial voices start on effects bus")
 var key:int=game.battery_tanks.rows.keys()[0];var row:Dictionary=game.battery_tanks.rows[key]
 row.position=Vector3(0,0,-3);row.pilot=1;row.speed=4
 game.field_audio._process(.1)
 check(game.field_audio.loops.has("vehicle:"+str(key)),"Real hull state starts engine")
 if game.spatial.steam.enabled():check(game.field_audio.loops.values().all(func(p):return p.has_method("play_stream")),"Steam Audio handles looped field sources")
 row.pilot=0;row.speed=0;game.field_audio._process(.1)
 check(game.field_audio.loops.is_empty(),"Real hull parking stops engine")
 var report:String=game.field_audio.vehicle_report(row.kind)
 var fire_count:int=game.field_audio.played.get(report,0)
 row.shot_at=game.clock;game.field_audio._process(.1)
 check(game.field_audio.played.get(report,0)==fire_count+1,"Actual vehicle firing timestamp triggers its authored report")
 game._cq_turret_shot(Vector3(0,1,-3),Vector3.FORWARD,0)
 check(game.field_audio.played.get(report,0)==fire_count+1,"Script muzzle-flash RPC does not duplicate snapshot audio")
 check(game.projectile_sound(false,3)=="impact","Projectile SMG retains ballistic impact")
 check(game.projectile_sound(false,4)=="cq_field_energy_impact" and game.projectile_sound(true,11)=="cq_field_ordnance_impact","Native and scripted impact paths select correct damage families")
 var light:=LightClock.new();game.battle_map.lighting=light
 game.jungle_ambience._process(.25)
 check(game.jungle_ambience.day.volume_db>game.jungle_ambience.night.volume_db,"Day uses bird bed")
 light.seconds=600;game.jungle_ambience._process(.25)
 check(game.jungle_ambience.night.volume_db>game.jungle_ambience.day.volume_db,"Night uses insect bed")
 light.seconds=0;game.jungle_ambience._process(.25);var daylight:float=game.jungle_ambience.day.volume_db
 light.weather_cloud=1.;game.jungle_ambience._process(.25)
 check(game.jungle_ambience.day.volume_db<daylight-5,"Storms lower wildlife ambience")
 var mine:int=game.multiplayer.get_unique_id();game.fighters[mine].underwater=true;game.jungle_ambience._process(.25)
 check(game.jungle_ambience.submerged.volume_db>-20 and game.jungle_ambience.day.volume_db<daylight-12,"Submerged model selects filtered water bed without moving viewpoint")
 game.fighters[mine].underwater=false
 game.camera.global_position=Vector3(-553,28,-650);game.jungle_ambience.scan=0;game.jungle_ambience._process(.25)
 check(game.jungle_ambience.river.volume_db>-20,"Authored river has nearby water ambience")
 game.camera.global_position=game.BattleMap.Landscape.CENTERS[1]+Vector3.UP*2;game.jungle_ambience.scan=0;game.jungle_ambience._process(3.)
 check(game.jungle_ambience.beds.has(1),"Industrial site loads recorded machine bed")
 check(game.jungle_ambience.day.playing and game.jungle_ambience.night.playing,"Forest loops run in the actual CQ client")
 game.active=false;game.jungle_ambience._process(.1)
 check(game.jungle_ambience.day.volume_db<=-80 and game.jungle_ambience.river.volume_db<=-80,"Disconnect mutes environment beds")
 game.disconnect_game();game.queue_free();game=null;await process_frame;await create_timer(.5).timeout
 print("CQ_FIELD_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
