extends SceneTree
const Music=preload("res://deathmatch/audio/music/player.gd")
const Settings=preload("res://deathmatch/settings/preferences.gd")
class FakeGame extends Node:
	var headless:=false
	var active:=false
	var current_map:="lqdm1"
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var bytes:=0
	for file in ["iron_circuit","pressure_lock","foundry_run","dark_relay"]:
		var track=load("res://deathmatch/audio/music/"+file+".ogg")
		check(track.get_length()>90 and track.get_length()<130,file+" decodes as a complete score")
		bytes+=FileAccess.get_file_as_bytes("res://deathmatch/audio/music/"+file+".ogg").size()
		check(FileAccess.get_file_as_bytes("res://deathmatch/audio/music/"+file+".mod").size()<80000,file+" retains a compact editable tracker source")
	check(bytes<3000000,"Runtime soundtrack remains below 3 MB total")
	var game:=FakeGame.new();root.add_child(game)
	var music:=Music.new();game.add_child(music);music.setup(game);music.set_process(false);music._process(.1)
	check(music.players[music.current].playing and music.players[music.current].stream.loop,"Music begins in menus and loops")
	var first:=music.current
	game.active=true
	for name in ["lqdm1","lqdm2","lqdm4","lqdm7"]:
		game.current_map=name;music._process(.1)
		if music.current!=first:break
	check(music.current!=first and music.players[0].playing and music.players[1].playing,"Changing maps crossfades without an abrupt stop")
	music._process(1)
	check(not music.players[1-music.current].playing,"Previous score stops after the crossfade")
	Settings.bus_volume("ArenaMusic",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("ArenaMusic")),"Music volume zero mutes its independent bus")
	Settings.bus_volume("ArenaMusic",.3)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("ArenaMusic")),"Music can resume at its saved level")
	music.stop()
	await create_timer(.1).timeout
	game.free()
	check(AudioServer.get_bus_index("ArenaMusic")==-1,"Music removes its owned bus on shutdown")
	print("MUSIC_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
