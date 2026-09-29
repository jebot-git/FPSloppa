extends SceneTree
const Music=preload("res://deathmatch/audio/music/player.gd")
const Catalog=preload("res://deathmatch/audio/music/catalog.gd")
const Settings=preload("res://deathmatch/settings/preferences.gd")
class Lobby extends RefCounted:
	var in_lobby:=false
	func active() -> bool:return in_lobby
class Mode extends RefCounted:
	var kind:="dm"
class FakeGame extends Node:
	var headless:=false
	var active:=false
	var current_map:="lqdm1"
	var map_catalog: Array=[{"id":"de_dust2"},{"id":"de_dust2_rebuilt"},{"id":"de_nuke_rebuilt"},{"id":"ctf_raindance"}]
	var lobby:=Lobby.new()
	var match_mode:=Mode.new()
var failures: Array=[]
var checks:=0
var folder: String
var fixture: String
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func put(name: String):
	var path:=folder.path_join(name);DirAccess.make_dir_recursive_absolute(path.get_base_dir());DirAccess.copy_absolute(fixture,path)
func names(choice: Dictionary) -> Array:return choice.tracks.map(func(path):return path.get_file())
func _initialize():call_deferred("run")
func ready_track(music,path: String) -> bool:
	var until:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<until:
		music._process(.02)
		if music.playing_path.ends_with(path) and music.players[music.current].playing:return true
		await create_timer(.02).timeout
	return false
func run():
	folder=OS.get_cmdline_user_args()[0];fixture=OS.get_cmdline_user_args()[1]
	for name in ["03.OGG","01.ogg","02.ogg","dm_10.ogg","dm_2.ogg","tdm_1.ogg","de_action.ogg","de_dust2.ogg","de_dust2_rebuilt.ogg","de_dust2_rebuilt_02.ogg","ST/02.ogg","ST/01.ogg","ST/album/03.ogg","de_nuke_rebuilt/01.ogg","collection/10.ogg","collection/2.OGG"]:put(name)
	FileAccess.open(folder.path_join("tf.m3u"),FileAccess.WRITE).store_string("\ufeff#EXTM3U\r\n#EXTINF:2,Ignored metadata\r\ncollection/10.ogg\r\ncollection\\2.OGG\r\ncollection/10.ogg\r\nmissing.ogg\r\nhttps://example.invalid/music.ogg\r\nother.mp3\r\n")
	FileAccess.open(folder.path_join("ctf_raindance.m3u8"),FileAccess.WRITE).store_string(folder.path_join("collection/10.ogg")+"\ncollection/2.OGG\n")
	var catalog:=Catalog.new();catalog.scan(folder,["de_dust2","de_dust2_rebuilt","de_nuke_rebuilt","ctf_raindance"])
	check(names(catalog.choose("ig","unknown"))==["01.ogg","02.ogg","03.OGG"],"Unprefixed OGG files play in filename order, case insensitive")
	check(names(catalog.choose("dm","lqdm1"))==["dm_2.ogg","dm_10.ogg"],"Mode tracks override global tracks and sort numeric names naturally")
	check(names(catalog.choose("de","de_dust2_rebuilt"))==["de_dust2_rebuilt.ogg","de_dust2_rebuilt_02.ogg"],"Map track and numbered variants override mode; longest map match wins")
	check(names(catalog.choose("de","de_dust2"))==["de_dust2.ogg"],"A longer map's tracks cannot leak into its shorter prefix")
	check(names(catalog.choose("de","de_other"))==["de_action.ogg"],"Map-named tracks do not leak into other maps of the same mode")
	check(names(catalog.choose("st","ctf_stonehenge"))==["01.ogg","02.ogg","03.ogg"],"Mode folder and nested albums combine in filename order")
	check(catalog.choose("dm","de_nuke_rebuilt").key=="map:de_nuke_rebuilt","Map folder selection is tied to map, independently of mode")
	check(names(catalog.choose("tf","other"))==["2.OGG","10.ogg"],"M3U handles BOM, CRLF, comments and Windows separators; sorts and deduplicates local OGGs")
	check(names(catalog.choose("st","ctf_raindance"))==["2.OGG","10.ogg"],"Map M3U8 supports absolute and relative local files and overrides mode")
	put("de_test.v2.ogg");catalog.scan(folder,["de_test.v2"])
	check(names(catalog.choose("de","de_test.v2.bsp"))==["de_test.v2.ogg"],"Map IDs containing dots retain their full names")
	DirAccess.remove_absolute(folder.path_join("de_test.v2.ogg"))
	catalog.scan(folder+"/absent",[]);check(catalog.choose("dm","map").key=="silent","Absent or empty collection leaves gameplay silent")
	for key in Music.TRACKS:
		var path: String="res://deathmatch/audio/music/"+Music.TRACKS[key]+".ogg"
		var stream=load(path);check(stream.get_length()>90 and stream.get_length()<160,key+" retains its full original internal cue")
	check(Music.TRACKS.keys()==["title","lobby"],"Only title and lobby music are bundled")
	var game:=FakeGame.new();root.add_child(game)
	var server:=Music.new();game.add_child(server);game.headless=true;server.setup(game,folder+"/server-not-created")
	check(server.players.is_empty() and server.worker==null and not DirAccess.dir_exists_absolute(folder+"/server-not-created"),"Dedicated server creates no music folder, resources or worker");server.free();game.headless=false
	var music:=Music.new();game.add_child(music);music.setup(game,folder);music.set_process(false)
	Settings.bus_volume("ArenaMusic",.1);var bus:=AudioServer.get_bus_index("ArenaMusic")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-32),"Existing music gain and 12 dB trim remain")
	Settings.bus_volume("ArenaMusic",0);check(AudioServer.is_bus_mute(bus),"Music mute still works")
	Settings.bus_volume("ArenaMusic",.01);check(not AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus),-52),"Quiet music setting unmutes correctly")
	AudioServer.set_bus_mute(bus,true)
	check(await ready_track(music,"dead_air.ogg"),"Title always starts internal Dead Air despite custom music")
	check(music.players[music.current].stream.loop,"Internal title cue loops")
	game.active=true
	check(await ready_track(music,"dm_2.ogg"),"Gameplay starts first matching external track asynchronously")
	check(music.players[0].playing and music.players[1].playing,"Context changes crossfade on two players")
	check(not music.players[music.current].stream.loop,"External song does not loop ahead of the next song")
	music._process(3);check(not music.players[1-music.current].playing,"Outgoing internal music stops after crossfade")
	var before: int=music.current;game.current_map="lqdm2";music._process(.1)
	check(music.current==before and music.playing_path.ends_with("dm_2.ogg"),"Map changes keep playback position when the selected playlist is unchanged")
	music.players[music.current].seek(music.players[music.current].stream.get_length()-.04)
	check(await ready_track(music,"dm_10.ogg"),"Actual audio completion advances to the second filename")
	music.players[music.current].seek(music.players[music.current].stream.get_length()-.04)
	check(await ready_track(music,"dm_2.ogg"),"Actual audio completion wraps the playlist to its first file")
	game.match_mode.kind="de";game.current_map="de_dust2_rebuilt"
	check(await ready_track(music,"de_dust2_rebuilt.ogg"),"Changing to a map override starts its own queue")
	game.match_mode.kind="tf";game.current_map="unknown"
	check(await ready_track(music,"collection/2.OGG"),"M3U track loads directly without editor import")
	game.lobby.in_lobby=true
	check(await ready_track(music,"please_hold.ogg"),"Lobby always selects internal Please Hold")
	game.lobby.in_lobby=false;game.match_mode.kind="st";music._process(.01);game.active=false
	check(await ready_track(music,"dead_air.ogg"),"A stale async gameplay load cannot replace title music after disconnect")
	game.active=true;music.folder=folder+"/empty";music.refresh();music._process(3)
	check(music.selected=="silent" and music.players.all(func(p):return not p.playing),"Empty folder fades out built-in music and leaves gameplay silent")
	DirAccess.make_dir_recursive_absolute(folder+"/bad");FileAccess.open(folder+"/bad/01.ogg",FileAccess.WRITE).store_string("not ogg")
	DirAccess.copy_absolute(fixture,folder+"/bad/02.ogg");music.folder=folder+"/bad";music.refresh()
	check(await ready_track(music,"bad/02.ogg"),"Malformed OGG is skipped and the next valid track plays")
	check(music.failed.size()==1,"Broken song is remembered rather than retried every frame")
	DirAccess.make_dir_recursive_absolute(folder+"/all-bad");FileAccess.open(folder+"/all-bad/01.ogg",FileAccess.WRITE).store_string("broken ogg")
	music.folder=folder+"/all-bad";music.refresh()
	var until:=Time.get_ticks_msec()+3000
	while not music.exhausted and Time.get_ticks_msec()<until:
		music._process(.02);await create_timer(.02).timeout
	music._process(3)
	check(music.exhausted and music.worker==null and music.players.all(func(p):return not p.playing),"An entirely invalid queue becomes silent without repeated worker jobs")
	DirAccess.copy_absolute(fixture,folder+"/all-bad/01.ogg");music.refresh()
	check(await ready_track(music,"all-bad/01.ogg"),"A rescan retries a repaired file even when the playlist names have not changed")
	music.folder=folder;music.context="";game.match_mode.kind="dm";music._process(.01)
	music.stop();check(music.worker==null and music.prepared==null,"Stop joins the prefetch worker and releases pending audio")
	await create_timer(.1).timeout;game.free()
	check(AudioServer.get_bus_index("ArenaMusic")==-1,"Music releases its owned bus on shutdown")
	var result:={"checks":checks,"failures":failures};print("MUSIC_RESULT ",JSON.stringify(result))
	var args:=OS.get_cmdline_user_args()
	var report: String=args[2] if args.size()>2 else "res://test-results/custom-music.json"
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));quit(0 if failures.is_empty() else 1)
