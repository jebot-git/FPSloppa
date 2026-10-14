extends SceneTree
class Game extends Node3D:
	var headless:=false
	var active:=true
	var battle_map
	var camera:Camera3D
	var fighters:Dictionary={}
	var players:Dictionary={1:{"dead":false,"spectator":false}}
	var clock:=0.0
	func is_vr():return false
class Actor extends Node3D:
	var local_player:=false
	func is_supported():return visual_grounded
	var visual_grounded:=true
	var stance:="standing"
var failures:Array=[]
func check(ok:bool,title:String):
	print("PASS " if ok else "FAIL ",title)
	if not ok:failures.append(title)
func _initialize():run.call_deferred()
func walk(game,audio,actor,steps:int):
	for i in steps:
		game.clock+=.11;actor.position.x+=.06 if actor.stance=="prone" else .22
		audio._process(.11);await create_timer(.11).timeout
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	var game:=Game.new();root.add_child(game)
	game.battle_map=preload("res://tools/voxel_battle/map.gd").new();game.add_child(game.battle_map)
	game.battle_map.grass=preload("res://tools/voxel_battle/grass.gd").new();game.battle_map.add_child(game.battle_map.grass)
	var actor:=Actor.new();game.add_child(actor);actor.position=Vector3(-1000,3,-300);game.fighters[1]=actor
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.position=actor.position+Vector3.UP*1.7;game.camera.current=true
	var rows:=PackedVector4Array()
	for x in range(-2,12):rows.append(Vector4(actor.position.x+x,3,-300,1))
	var audio=preload("res://tools/voxel_battle/grass_audio.gd").new();game.add_child(audio);audio.setup(game);audio.set_process(false)
	var coord:Vector2i=audio.Landscape.bin_key(Vector2(actor.position.x,actor.position.z));game.battle_map.grass.tiles[coord]={"rows":rows}
	var effect:=AudioEffectRecord.new();AudioServer.add_bus_effect(0,effect);effect.set_recording_active(true)
	await walk(game,audio,actor,12);check(audio.emissions>=4,"Walking through grass emits spatial rustles")
	var before:int=audio.emissions
	for i in 5:game.clock+=.11;audio._process(.11);await create_timer(.11).timeout
	check(audio.emissions==before,"Stationary avatar produces no rustling")
	game.camera.position.x-=30;await walk(game,audio,actor,5);check(audio.emissions==before,"Avatar outside twelve metres produces no local audio")
	game.camera.position=actor.position+Vector3.UP*1.7;actor.visual_grounded=false;await walk(game,audio,actor,5);check(audio.emissions==before,"Airborne avatar does not rustle")
	actor.visual_grounded=true;actor.position.z+=10;await walk(game,audio,actor,5);check(audio.emissions==before,"Bare ground does not rustle")
	actor.position.z-=10;actor.stance="prone";await walk(game,audio,actor,10)
	check(audio.emissions>before,"Prone movement still makes quieter nearby rustling")
	await create_timer(.7).timeout;effect.set_recording_active(false)
	DirAccess.make_dir_recursive_absolute("res://test-results/baked-jungle")
	var recording:=effect.get_recording();recording.save_to_wav("res://test-results/baked-jungle/rustle-recording.wav")
	check(recording.data.size()>24000,"Spatial audio reaches the output recording bus")
	check(audio.voices.size()==8 and audio.voices.all(func(voice):return voice.max_distance==12),"Voice pool and attenuation remain bounded")
	print("CQ_RUSTLE_RESULT ",JSON.stringify({"failures":failures,"emissions":audio.emissions,"recorded_bytes":recording.data.size()}));game.free();quit(0 if failures.is_empty() else 1)
