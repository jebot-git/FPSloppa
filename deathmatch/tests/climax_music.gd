extends SceneTree
const Music=preload("res://deathmatch/audio/music/player.gd")
const Cue=preload("res://deathmatch/audio/music/climax.gd")
const Catalog=preload("res://deathmatch/audio/music/catalog.gd")
const Ambience=preload("res://deathmatch/audio/ambience.gd")
class Lobby extends RefCounted:
	var waiting:=false
	func active():return waiting
class Titan extends RefCounted:
	var preparation_left:=0.0
	var winner:=-1
	var route_id:="delivery"
	func preparing():return preparation_left>0
class Mode extends RefCounted:
	var kind:="dm"
	var flags: Array=[]
	var scores: Array=[0,0]
	var winning_score:=20
	var assault=preload("res://deathmatch/modes/assault.gd").new()
	var defusal=preload("res://deathmatch/modes/defusal.gd").new()
	var titanball=Titan.new()
	var fortress:={"walkers":{"robots":{}}}
	func limit():return winning_score
class Rules extends RefCounted:
	func effective():return "quake"
class Game extends Node:
	var active:=true
	var headless:=false
	var quitting:=false
	var map_loading:=false
	var menu_open:=false
	var intermission:=0.0
	var current_map:="ctf_raindance"
	var map_catalog: Array=[{"id":"ctf_raindance"},{"id":"de_dust2_rebuilt"}]
	var frag_limit:=20
	var players: Dictionary={}
	var lobby=Lobby.new()
	var match_mode=Mode.new()
	var armory=Rules.new()
	var music
var checks:=0
var failures: Array=[]
var folder: String
var fixture: String
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func put(name: String):
	var path:=folder.path_join(name);DirAccess.make_dir_recursive_absolute(path.get_base_dir());DirAccess.copy_absolute(fixture,path)
func names(choice: Dictionary) -> Array:return choice.tracks.map(func(path):return path.get_file())
func ready_track(music,path: String) -> bool:
	var until:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<until:
		music._process(.02)
		if music.playing_path.ends_with(path) and music.players[music.current].playing:return true
		await create_timer(.02).timeout
	return false
func _initialize():run.call_deferred()
func run():
	folder=OS.get_cmdline_user_args()[0];fixture=OS.get_cmdline_user_args()[1]
	var game:=Game.new();root.add_child(game);var mode=game.match_mode
	game.players={1:{"spectator":false,"dead":false,"team":0,"kills":18},2:{"spectator":false,"dead":false,"team":1,"kills":0},3:{"spectator":false,"dead":false,"team":0,"kills":0},4:{"spectator":true,"dead":false,"team":-1,"kills":19}}
	for kind in ["dm","ig","cc"]:
		mode.kind=kind;game.players[1].kills=18
		check(not Cue.active(game,1),kind+" two frags away stays ambient")
		game.players[1].kills=19
		check(Cue.active(game,1) and not Cue.active(game,2) and not Cue.active(game,3),kind+" cue is personal")
		check(not Cue.active(game,4) and not Cue.active(game,99),kind+" spectators/missing listener excluded")
		game.players[1].kills=20;check(not Cue.active(game,1),kind+" only exactly one frag away")
	for kind in ["tdm","if","tf"]:
		mode.kind=kind;mode.winning_score=5 if kind=="tf" else 20;mode.scores=[mode.winning_score-1,0]
		check(Cue.active(game,1) and Cue.active(game,3) and not Cue.active(game,2),kind+" only scoring team hears cue")
		check(not Cue.active(game,4),kind+" spectator excluded")
		game.players[3].dead=true;check(Cue.active(game,3),kind+" team cue survives teammate death");game.players[3].dead=false
		mode.scores[0]-=1;check(not Cue.active(game,1),kind+" score reduction cancels cue")
	mode.scores=[0,0]
	for kind in ["st","ctf","tf"]:
		mode.kind=kind;mode.flags=[{"carrier":0},{"carrier":1}]
		check(Cue.active(game,1) and not Cue.active(game,2) and not Cue.active(game,3),kind+" flag cue is carrier-only")
		game.players[1].dead=true;check(not Cue.active(game,1),kind+" stale flag after death cannot play");game.players[1].dead=false
		mode.flags[1].carrier=0;check(not Cue.active(game,1),kind+" dropping/capturing flag cancels")
	for kind in ["ft","koth"]:
		mode.kind=kind;mode.scores=[mode.winning_score-1,0];check(not Cue.active(game,1),kind+" has no unsolicited cue")
	mode.kind="as";mode.assault.stage=0;check(not Cue.active(game,1),"AS begins ambient")
	mode.assault.stage=1
	for id in [1,2,3,4,99]:check(Cue.active(game,id),"AS global, including spectator/late join "+str(id))
	mode.assault.switching=true;check(not Cue.active(game,1),"AS role switch clears cue");mode.assault.switching=false
	mode.assault.finished=true;check(not Cue.active(game,1),"AS completion clears cue");mode.assault.finished=false
	mode.assault.stage=0;check(not Cue.active(game,1),"AS next leg starts ambient")
	mode.kind="de";mode.defusal.phase="live";mode.defusal.planted=false;check(not Cue.active(game,1),"DE before plant stays ambient")
	mode.defusal.planted=true
	for id in [1,2,4,99]:check(Cue.active(game,id),"DE plant global "+str(id))
	mode.defusal.phase="post";check(not Cue.active(game,1),"DE resolved bomb cancels despite retained planted flag")
	mode.defusal.phase="prepare";mode.defusal.planted=false;check(not Cue.active(game,1),"DE next round resets cue")
	mode.kind="tb"
	var robot:={"id":"delivery","loop":false,"points":[Vector3.ZERO,Vector3(350,0,0)],"position":Vector3(340,0,0)}
	mode.fortress.walkers.robots={"delivery":robot}
	check(not Cue.active(game,1),"TB exactly 10m does not trigger")
	robot.position.x=340.01
	for id in [1,2,4,99]:check(Cue.active(game,id),"TB under 10m global "+str(id))
	robot.position=Vector3(349,20,0);check(not Cue.active(game,1),"TB uses 3D distance to actual delivery endpoint")
	robot.position=Vector3(345,0,0);mode.titanball.preparation_left=1;check(not Cue.active(game,1),"TB preparation suppressed")
	mode.titanball.preparation_left=0;mode.titanball.winner=0;check(not Cue.active(game,1),"TB finished suppressed")
	mode.titanball.winner=-1;robot.loop=true;check(not Cue.active(game,1),"Unrelated looping walker excluded");robot.loop=false
	mode.titanball.route_id="other";check(not Cue.active(game,1),"Non-objective route excluded");mode.titanball.route_id="delivery"
	for field in ["map_loading","quitting"]:
		game.set(field,true);check(not Cue.active(game,1),field+" clears cue");game.set(field,false)
	game.active=false;check(not Cue.active(game,1),"Disconnect clears cue");game.active=true
	game.intermission=10;check(not Cue.active(game,1),"Intermission clears cue");game.intermission=0
	game.lobby.waiting=true;check(not Cue.active(game,1),"Lobby clears cue");game.lobby.waiting=false
	for name in ["normal.ogg","WIN_10.ogg","win_2.ogg","win_dm_10.ogg","win_dm_2.ogg","win_ctf_raindance_01.ogg","win_st/album/02.ogg","st/win_01.ogg","st/03.ogg","win_de_dust2_rebuilt/01.ogg","collection/10.ogg"]:put(name)
	FileAccess.open(folder.path_join("win_tf.m3u"),FileAccess.WRITE).store_string("#EXTM3U\ncollection/10.ogg\ncollection/10.ogg\nhttps://example.invalid/a.ogg\n")
	var catalog:=Catalog.new();catalog.scan(folder,["ctf_raindance","de_dust2_rebuilt"])
	check(names(catalog.choose("ig","unknown"))==["normal.ogg"],"Win files never leak into ordinary global BGM")
	check(names(catalog.choose("ig","unknown",true))==["win_2.ogg","WIN_10.ogg"],"Win global queue sorts naturally/case insensitive")
	check(names(catalog.choose("dm","unknown",true))==["win_dm_2.ogg","win_dm_10.ogg"],"Win mode overrides win global")
	check(names(catalog.choose("dm","ctf_raindance",true))==["win_ctf_raindance_01.ogg"],"Win map overrides win mode")
	check(names(catalog.choose("st","unknown",true))==["02.ogg","win_01.ogg"],"Win folders and prefixed files inherit mode scope")
	check(names(catalog.choose("st","unknown"))==["03.ogg"],"Folder's prefixed cue excluded from ordinary queue")
	check(catalog.choose("de","de_dust2_rebuilt",true).key=="win:map:de_dust2_rebuilt","Win longest map folder takes precedence over mode")
	check(names(catalog.choose("tf","unknown",true))==["10.ogg"],"Win M3U local references deduplicate")
	check(catalog.scope("win_win_theme")=="win:global","Only one win prefix is stripped")
	mode.kind="dm";game.current_map="other";game.players[1].kills=18
	var music:=Music.new();game.add_child(music);game.music=music;music.setup(game,folder+"/playback");music.set_process(false)
	var ambience:=Ambience.new();game.add_child(ambience);ambience.setup(game,{"enclosure":0.0});ambience.set_process(false)
	for i in 160:ambience._process(.025)
	check(ambience.players[ambience.selected].playing and music.selected=="silent","Normal gameplay starts ambience only")
	game.players[1].kills=19
	check(await ready_track(music,"tower_defense_climax.ogg"),"Trigger loads bundled cue asynchronously")
	check(not music.has_custom_bgm(),"Bundled cue does not masquerade as custom BGM")
	check(music.players[music.current].stream.loop and is_equal_approx(music.players[music.current].stream.loop_offset,Music.WIN_LOOP_OFFSET),"Bundled cue loops at authored offset")
	check(music.ambience_gain()>.98 and music.players[music.current].volume_db < -25,"Entry fades up from silence while ambience remains")
	for i in 50:music._process(.025);ambience._process(.025)
	check(music.ambience_gain()>.5 and music.ambience_gain()<.8 and ambience.gains[ambience.selected]>0,"Mid-crossfade both ambience and cue are audible")
	for i in 160:music._process(.025);ambience._process(.025)
	check(music.worker==null and music.prepared==null,"Internal cue has no redundant prefetch worker")
	check(not ambience.players[ambience.selected].playing,"Full cue suspends ambience bed")
	music.players[music.current].seek(74.96)
	await create_timer(.18).timeout
	var playback: float=music.players[music.current].get_playback_position()
	check(playback>=Music.WIN_LOOP_OFFSET and playback<Music.WIN_LOOP_OFFSET+.5,"Actual Ogg playback wraps to authored loop offset without restarting buildup")
	game.players[1].kills=18;music._process(.01)
	check(music.players[1-music.current].playing and music.ambience_gain()<.02,"End begins outgoing fade without abrupt stop")
	for i in 160:music._process(.025);ambience._process(.025)
	check(music.players.all(func(p):return not p.playing) and ambience.players[ambience.selected].playing,"End returns smoothly to ambience")
	put("playback/dm_01.ogg");music.refresh()
	check(await ready_track(music,"dm_01.ogg"),"Ordinary custom BGM loads")
	music._process(3);var generation: int=music.generation
	game.players[1].kills=19;music._process(.02)
	check(music.playing_path.ends_with("dm_01.ogg") and music.generation==generation,"Ordinary custom BGM overrides bundled cue without restarting")
	put("playback/win_01.ogg");music.refresh()
	check(await ready_track(music,"win_01.ogg"),"Explicit win replacement overrides ordinary custom BGM")
	music._process(3);check(music.has_custom_bgm() and not music.has_custom_bgm(false),"Custom win replacement participates in ambience crossfade")
	game.players[1].kills=18;check(await ready_track(music,"dm_01.ogg"),"Ending cue restores ordinary custom playlist")
	# A cue-state change must not rescan a user's library on the render thread.
	put("playback/win_dm_01.ogg");game.players[1].kills=19
	check(await ready_track(music,"win_01.ogg"),"Trigger uses cached catalog until explicit/map rescan")
	music.refresh();check(await ready_track(music,"win_dm_01.ogg"),"Explicit rescan discovers more specific win override")
	# Also verify win-only folders fade naturally from ambience, including rapid reversal.
	music.folder=folder+"/win-only";DirAccess.make_dir_recursive_absolute(music.folder)
	DirAccess.copy_absolute(fixture,music.folder.path_join("win_01.ogg"));game.players[1].kills=18;music.refresh();music._process(3)
	for i in 160:ambience._process(.025)
	game.players[1].kills=19;ambience._process(.025)
	check(ambience.players[ambience.selected].playing,"Pending custom win load does not cut ambience")
	check(await ready_track(music,"win-only/win_01.ogg"),"Win-only custom replacement starts")
	music._process(.3);var gain: float=db_to_linear(music.players[music.current].volume_db)
	game.players[1].kills=18;music._process(.001)
	check(music.players[1-music.current].playing and absf(music.outgoing_gain-gain)<.001,"Rapid cue reversal preserves actual outgoing level")
	for i in 120:music._process(.025);ambience._process(.025)
	check(ambience.players[ambience.selected].playing,"Rapid reversal recovers ambience")
	game.players[1].kills=19;music._process(.01);game.active=false
	check(await ready_track(music,"dead_air.ogg"),"Stale cue worker cannot replace title after disconnect")
	ambience.clear();music.stop();ambience.free();music.free();game.free()
	# Let the audio server retire stopped playback objects before tree shutdown.
	await create_timer(.15).timeout
	var result:={"checks":checks,"failures":failures};print("CLIMAX_MUSIC_RESULT ",JSON.stringify(result))
	FileAccess.open("res://test-results/climax-music.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));quit(0 if failures.is_empty() else 1)
