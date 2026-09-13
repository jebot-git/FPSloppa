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
	var bytes:=0;var hashes: Array=[];var unique_files: Array=[]
	for key in Music.TRACKS:
		var file: String=Music.TRACKS[key]
		var track=load('res://deathmatch/audio/music/'+file+'.ogg')
		check(track.get_length()>90 and track.get_length()<160,key+' decodes as a complete score')
		if file not in unique_files:
			unique_files.append(file)
			bytes+=FileAccess.get_file_as_bytes('res://deathmatch/audio/music/'+file+'.ogg').size()
			hashes.append(FileAccess.get_sha256('res://deathmatch/audio/music/'+file+'.ogg'))
		if key in ['title','lobby']:
			var source:=FileAccess.get_file_as_bytes('res://deathmatch/audio/music/'+file+'.mod')
			check(source.slice(1080,1084).get_string_from_ascii()=='8CHN' and source.size()<400000,key+' retains compact eight-channel tracker source')
		elif key=='as':
			var source=JSON.parse_string(FileAccess.get_file_as_string('res://deathmatch/audio/music/'+file+'.score.json'))
			check(source is Dictionary and source.get('key')=='as' and source.get('source_format')=='XM' and source.get('license')=='Public Domain' and source.get('sha256')==FileAccess.get_sha256('res://deathmatch/audio/music/'+file+'.ogg'),'Assault uses the attributed public-domain XM conversion')
		else:
			var source=JSON.parse_string(FileAccess.get_file_as_string('res://deathmatch/audio/music/'+file+'.score.json'))
			var score_key: String='ft' if key=='if' else key
			check(source is Dictionary and source.get('key')==score_key and source.get('events',[]).size()>100 and source.get('sha256')==FileAccess.get_sha256('res://deathmatch/audio/music/'+file+'.ogg'),key+' arrangement matches its rendered audio')
	check(bytes<21000000 and hashes.size()==12 and hashes.all(func(h):return hashes.count(h)==1),'Twelve distinct runtime scores stay below 21 MB total, with IF sharing FT')
	var game:=FakeGame.new();root.add_child(game)
	var server:=Music.new();game.add_child(server);game.headless=true;server.setup(game)
	check(server.players.is_empty() and server.cache.is_empty(),'Dedicated server loads no music resources');server.free();game.headless=false
	var music:=Music.new();game.add_child(music);music.setup(game);music.set_process(false)
	Settings.bus_volume('ArenaMusic',.1)
	var bus:=AudioServer.get_bus_index('ArenaMusic')
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-32.),'Ten-percent music is 12 dB quieter at the music bus')
	Settings.bus_volume('ArenaMusic',0)
	check(AudioServer.is_bus_mute(bus),'Zero music remains fully muted')
	Settings.bus_volume('ArenaMusic',.01)
	check(not AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus),-52.),'One-percent music unmutes at a quiet level')
	Settings.bus_volume('ArenaMusic',.1)
	AudioServer.set_bus_mute(AudioServer.get_bus_index('ArenaMusic'),true)
	check(await ready_track(music,'title'),'Ambient title track starts before entering a match')
	check(music.players[music.current].stream.loop,'Runtime music loops')
	music._process(3);await create_timer(.2).timeout
	game.active=true
	check(await ready_track(music,'dm'),'Entering DM switches to its assigned track')
	check(music.players[0].playing and music.players[1].playing,'Track transition crossfades on two players')
	music._process(3)
	check(not music.players[1-music.current].playing,'Outgoing track stops after the crossfade')
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-32.),'Music trim survives a track change and crossfade')
	var before: int=music.current;game.current_map='lqdm2';music._process(.1)
	check(music.current==before and music.selected=='dm','Map changes within one mode do not restart its music')
	for key in ['tdm','ctf','koth','ig','ft','if','cc','tf','tb','as']:
		game.match_mode.kind=key
		check(await ready_track(music,key),key+' selects its own track asynchronously')
		if key=='tb':
			check(Music.TRACKS[key]=='escape_velocity','Titanball selects Escape Velocity rather than the TF track')
			music._process(3)
			var player: AudioStreamPlayer=music.players[music.current]
			player.seek(player.stream.get_length()-.10)
			await create_timer(.35).timeout
			check(player.playing and player.get_playback_position()<1.0,'Titanball playback wraps at the loop boundary')
	game.lobby.in_lobby=true
	check(await ready_track(music,'lobby'),'Lobby elevator music overrides the prior game mode')
	game.active=false;game.lobby.in_lobby=false
	check(await ready_track(music,'title'),'Disconnect returns to ambient title music')
	check(music.loading.is_empty(),'Threaded requests are consumed without pending jobs')
	music.stop();await create_timer(.5).timeout;game.free()
	check(AudioServer.get_bus_index('ArenaMusic')==-1,'Music releases its owned bus on shutdown')
	print('MUSIC_RESULT ',JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
