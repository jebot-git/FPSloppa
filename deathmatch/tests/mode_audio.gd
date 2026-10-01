extends SceneTree
const Spatial=preload("res://deathmatch/audio/spatial.gd")
const Bank=preload("res://deathmatch/audio/modes/catalog.gd")
const Ambience=preload("res://deathmatch/audio/ambience.gd")
class Rules extends RefCounted:
	var kind:="quake"
	func effective():return kind
class Lobby extends RefCounted:
	var waiting:=false
	func active():return waiting
class MusicState extends RefCounted:
	var custom:=false
	func has_custom_bgm(_include_climax: bool=true):return custom
	func ambience_gain():return 1.0
class Fixture extends Node:
	var headless:=false
	var active:=true
	var map_loading:=false
	var quitting:=false
	var menu_open:=false
	var intermission:=0.0
	var current_map:="qsrc_dm6"
	var armory=Rules.new()
	var lobby=Lobby.new()
	var music=MusicState.new()
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var mixer:=Spatial.new();mixer.prewarm()
	var size:=mixer.cache.size()
	for key in Bank.SOUNDS:
		var paths: Array=Bank.SOUNDS[key];var first=mixer.choose(key)
		check(first!=null and first is AudioStreamWAV,"PCM mode sound loads: "+key)
		for i in paths.size()-1:check(mixer.choose(key)!=first,"Variation advances: "+key)
		check(mixer.choose(key)==first,"Variation wraps: "+key)
	check(mixer.cache.size()==size,"All variants are prewarmed")
	check(Bank.SOUNDS.cs16_weapon_2!=Bank.SOUNDS.cs16_weapon_2_alt,"USP suppressor has its own sound")
	check(Bank.SOUNDS.cs16_weapon_7!=Bank.SOUNDS.cs16_weapon_7_alt,"M4 suppressor has its own sound")
	check(Bank.SOUNDS.cs16_weapon_0[0].contains("cs16_weapon_0"),"Knife no longer uses pistol report")
	check(Bank.SOUNDS.ut99_weapon_3!=Bank.SOUNDS.ut99_weapon_3_alt,"Shock beam differs from orb")
	for pair in [["de_dust2_rebuilt","desert"],["de_nuke_rebuilt","industrial"],["ctf_raindance","rain"],["ctf_katabatic","alpine"],["as_frigate","coast"],["qsrc_dm6","gothic"]]:
		check(Ambience.profile_for(pair[0],"doom")==pair[1],"Map soundscape: "+pair[0])
	check(Ambience.profile_for("custom_map","ut99")=="arena","Unknown maps inherit mode identity")
	var translocator=preload("res://deathmatch/art.gd").weapon(11,2,"ut99");root.add_child(translocator)
	var disc: Node3D=translocator.get_node("TranslocatorDisc")
	var core: Node3D=translocator.get_node("DiscCore")
	var disc_mesh: MeshInstance3D=disc.find_children("*","MeshInstance3D",true,false)[0]
	var disc_bounds: AABB=translocator.global_transform.affine_inverse()*disc_mesh.global_transform*disc_mesh.get_aabb()
	for mesh in translocator.find_children("*","MeshInstance3D",true,false):
		if disc.is_ancestor_of(mesh) or core.is_ancestor_of(mesh):continue
		var bounds: AABB=translocator.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		check(not disc_bounds.intersects(bounds),"Translocator disc clears "+str(mesh.name))
	translocator.free()
	var game:=Fixture.new();root.add_child(game)
	var ambience:=Ambience.new();root.add_child(ambience);ambience.setup(game,mixer);ambience.set_process(false)
	check(ambience.players.size()==2,"Bounded two-player ambience")
	for stream in ambience.streams.values():check(stream.loop and stream.get_length()>10,"Long looping ambience")
	for i in 80:ambience._process(.025)
	check(ambience.profile=="gothic" and ambience.players[ambience.selected].playing,"Map ambience becomes audible")
	var player: AudioStreamPlayer=ambience.players[ambience.selected];var dry:=player.volume_db
	ambience.combat_pulse();for i in 10:ambience._process(.025)
	check(player.volume_db<dry-5,"Close combat ducks the bed")
	for i in 120:ambience._process(.025)
	check(absf(player.volume_db-dry)<.8,"Ambience recovers after combat")
	game.current_map="ctf_raindance"
	for i in 80:ambience._process(.025)
	check(ambience.profile=="rain" and ambience.players.size()==2,"Map change crossfades without adding players")
	game.menu_open=true
	for i in 80:ambience._process(.025)
	check(not ambience.players[0].playing and not ambience.players[1].playing,"Menu suspends ambience")
	game.menu_open=false;game.lobby.waiting=true
	for i in 80:ambience._process(.025)
	check(not ambience.players[ambience.selected].playing,"Waiting room stays clear of gameplay ambience")
	game.lobby.waiting=false
	for i in 80:ambience._process(.025)
	game.music.custom=true
	ambience._process(.025)
	check(not ambience.players[0].playing and not ambience.players[1].playing,"Custom BGM suspends both ambience beds")
	game.music.custom=false
	for i in 80:ambience._process(.025)
	check(ambience.players[ambience.selected].playing,"Ambience resumes when custom BGM is absent")
	ambience.clear();check(ambience.profile=="" and ambience.gains==[0.0,0.0],"Clear stops both beds")
	await create_timer(.25).timeout
	ambience.free();game.free();mixer.free()
	check(AudioServer.get_bus_index("ArenaAmbience")==-1,"Ambience bus released on shutdown")
	await create_timer(.1).timeout
	print("MODE_AUDIO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
