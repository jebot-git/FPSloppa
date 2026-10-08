extends SceneTree
const Music=preload("res://deathmatch/audio/music/player.gd")
const Fixture=preload("res://deathmatch/tests/climax_music.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func ready_track(music,path: String) -> bool:
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		music._process(.02)
		if music.playing_path==path and music.players[music.current].playing:return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var game:=Fixture.Game.new();root.add_child(game)
	game.players={1:{"spectator":false,"dead":false,"team":0,"kills":0}}
	var music:=Music.new();game.add_child(music);game.music=music
	music.setup(game,OS.get_cmdline_user_args()[0]);music.set_process(false)
	var bus:=AudioServer.get_bus_index("ArenaMusic");AudioServer.set_bus_volume_db(bus,-12)
	for mode in Music.DEFAULT_MODES:
		game.match_mode.kind=mode;game.current_map="unknown"
		var path: String=Music.MODE_ROOT+mode+".ogg"
		check(await ready_track(music,path),mode+" plays its bundled default without custom files")
		music._process(3)
		check(not music.has_custom_bgm(),mode+" retains environmental ambience")
		check(music.ambience_gain()>.69 and music.ambience_gain()<.88,mode+" blends a partial ambience bed")
		check(music.worker==null and music.prepared==null,mode+" does not prefetch its own looping stream")
		var stream=music.players[music.current].stream
		check(stream!=null and stream.loop,mode+" is a native looping stream")
		if stream:
			music.players[music.current].seek(stream.get_length()-.04)
			await create_timer(.18).timeout
			var position: float=music.players[music.current].get_playback_position()
			check(position>=0 and position<.6 and music.players[music.current].playing,mode+" actually wraps without a finished/prefetch gap")
		var current: int=music.current
		game.current_map="other";music._process(.02)
		check(music.current==current and music.playing_path==path,mode+" preserves playback across maps with no overrides")
	AudioServer.set_bus_mute(bus,true)
	check(is_equal_approx(music.ambience_gain(),1.0),"Muting default music restores the full ambience bed")
	AudioServer.set_bus_mute(bus,false);AudioServer.set_bus_volume_db(bus,-32)
	check(music.ambience_gain()>.99,"Quiet default music does not heavily duck ambience")
	music.stop();game.free();await create_timer(.15).timeout
	print("DEFAULT_MODE_MUSIC_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
