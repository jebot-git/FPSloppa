extends SceneTree
# Use PulseAudio (muted bus) to exercise real mixer cleanup, not Dummy playback.
const Music=preload('res://deathmatch/audio/music/player.gd')
const Settings=preload('res://deathmatch/settings/preferences.gd')
class Lobby extends RefCounted:
	var in_lobby:=false
	func active() -> bool:return in_lobby
class Mode extends RefCounted:
	var kind:='dm'
class FakeGame extends Node:
	var headless:=false
	var active:=false
	var current_map:='lqdm1'
	var lobby:=Lobby.new()
	var match_mode:=Mode.new()
var failures: Array=[]
func check(ok: bool,label: String):
	print('PASS ' if ok else 'FAIL ',label)
	if not ok:failures.append(label)
func _initialize():call_deferred('run')
func ready_track(music,key: String) -> bool:
	var until:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<until:
		music._process(.02)
		if music.selected==key:return true
		await create_timer(.02).timeout
	return false
func run():
	var bytes:=0;var hashes: Array=[]
	for key in Music.TRACKS:
		var file: String=Music.TRACKS[key]
		var track=load('res://deathmatch/audio/music/'+file+'.ogg')
		check(track.get_length()>90 and track.get_length()<160,key+' decodes as a complete score')
		bytes+=FileAccess.get_file_as_bytes('res://deathmatch/audio/music/'+file+'.ogg').size()
		if key in ['title','lobby']:
			var source:=FileAccess.get_file_as_bytes('res://deathmatch/audio/music/'+file+'.mod')
			check(source.slice(1080,1084).get_string_from_ascii()=='8CHN' and source.size()<400000,key+' retains compact eight-channel tracker source')
		else:
			var source=JSON.parse_string(FileAccess.get_file_as_string('res://deathmatch/audio/music/'+file+'.score.json'))
			check(source is Dictionary and source.get('key')==key and source.get('events',[]).size()>100 and source.get('sha256')==FileAccess.get_sha256('res://deathmatch/audio/music/'+file+'.ogg'),key+' metal arrangement matches its rendered audio')
		hashes.append(FileAccess.get_sha256('res://deathmatch/audio/music/'+file+'.ogg'))
	check(bytes<16000000 and hashes.size()==10 and hashes.all(func(h):return hashes.count(h)==1),'Ten distinct runtime scores stay below 16 MB total')
	var game:=FakeGame.new();root.add_child(game)
	var server:=Music.new();game.add_child(server);game.headless=true;server.setup(game)
	check(server.players.is_empty() and server.cache.is_empty(),'Dedicated server loads no music resources');server.free();game.headless=false
	var music:=Music.new();game.add_child(music);music.setup(game);music.set_process(false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index('ArenaMusic'),true)
	check(await ready_track(music,'title'),'Ambient title track starts before entering a match')
	check(music.players[music.current].stream.loop,'Runtime music loops')
	music._process(3);await create_timer(.2).timeout
	game.active=true
	check(await ready_track(music,'dm'),'Entering DM switches to its assigned track')
	check(music.players[0].playing and music.players[1].playing,'Track transition crossfades on two players')
	music._process(3)
	check(not music.players[1-music.current].playing,'Outgoing track stops after the crossfade')
	var before: int=music.current;game.current_map='lqdm2';music._process(.1)
	check(music.current==before and music.selected=='dm','Map changes within one mode do not restart its music')
	for key in ['tdm','ctf','koth','ig','ft','cc','tf']:
		game.match_mode.kind=key
		check(await ready_track(music,key),key+' selects its own track asynchronously')
	game.lobby.in_lobby=true
	check(await ready_track(music,'lobby'),'Lobby elevator music overrides the prior game mode')
	game.active=false;game.lobby.in_lobby=false
	check(await ready_track(music,'title'),'Disconnect returns to ambient title music')
	check(music.loading.is_empty(),'Threaded requests are consumed without pending jobs')
	music.stop();await create_timer(.5).timeout;game.free()
	check(AudioServer.get_bus_index('ArenaMusic')==-1,'Music releases its owned bus on shutdown')
	print('MUSIC_RESULT ',JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
