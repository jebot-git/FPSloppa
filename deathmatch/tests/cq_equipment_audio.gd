extends SceneTree
const Audio=preload("res://deathmatch/conquest/classes/equipment_audio.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var audio=Audio.new();root.add_child(audio)
 check(audio.observe(1,1,false,0,10).is_empty(),"initial equipment state primes silently")
 check(audio.observe(1,1,true,0,10)==["nvg"],"accepted NVG activation produces one cue")
 check(audio.observe(1,1,true,0,10).is_empty(),"repeated snapshot does not replay cue")
 check(audio.observe(1,1,false,0,10)==["nvg"],"NVG deactivation has quiet switch cue")
 check(audio.observe(1,1,false,18,10)==["cloak"],"accepted cloak activation produces cue")
 check(audio.observe(1,1,false,18,11).is_empty(),"cloak duration snapshots do not repeat cue")
 check(audio.observe(1,1,false,18.02,11).is_empty(),"snapshot clock offset jitter does not replay cloak cue")
 check(audio.observe(1,1,false,0,11).is_empty(),"cloak cancellation is not a new activation")
 check(audio.observe(1,2,true,18,12).is_empty(),"respawn baseline does not fabricate activation")
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 # A lightweight active fixture uses the actual spatial backend and world camera.
 var map=game.BattleMap.new();game.add_child(map);game.battle_map=map;game.spawn_points=[Vector3.ZERO];game.spawn_yaws=[0]
 game.start_host("Equipment audio QA",0,200,10,true,"tdm","ut99");audio.setup(game)
 game.camera.global_position=Vector3(0,1.5,0)
 check(not audio.play_cue("nvg",Vector3(0,1.5,-8.1)),"listeners beyond eight metres hear no activation")
 check(audio.play_cue("nvg",Vector3(0,1.5,-1.5)),"nearby listener receives spatial NVG cue")
 check(audio.play_cue("cloak",Vector3(1,1.5,-2)),"nearby listener receives cloak cue")
 check(audio.active.all(func(p):return p.max_distance==8 and p.unit_size==1. and p.volume_db<=-18 and p.bus=="ArenaEffects"),"equipment voices use quiet short-range effects bus")
 check(audio.active.all(func(p):return p.stream!=null and p.stream.get_length()<.5),"activation streams are short and valid")
 for i in 20:audio.play_cue("nvg",Vector3(0,1.5,-1))
 check(audio.active.size()<=Audio.MAX_VOICES,"activation voice count is bounded")
 game.active=false;audio._process(.05);check(audio.active.is_empty() and audio.seen.is_empty(),"disconnect clears voices and accepted-state history")
 audio.queue_free();game.disconnect_game();game.queue_free();await process_frame;await process_frame
 print("CQ_EQUIPMENT_AUDIO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
