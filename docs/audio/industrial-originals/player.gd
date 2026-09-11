extends Node
const TRACKS={"title":"dead_air","lobby":"please_hold","dm":"iron_circuit","tdm":"pressure_lock","ctf":"dark_relay","koth":"high_ground","ig":"foundry_run","ft":"cryostasis","cc":"carousel_of_teeth","tf":"breach_protocol"}
var game
var players: Array[AudioStreamPlayer]=[]
var selected:=""
var current:=0
var fade:=1.0
var outgoing_gain:=1.0
var owned_bus:=false
var loading: Dictionary={}
var cache: Dictionary={}
func setup(arena: Node) -> void:
	game=arena
	if game.headless:set_process(false);return
	if AudioServer.get_bus_index("ArenaMusic")<0:
		owned_bus=true;AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaMusic")
		AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	for i in range(2):
		var player:=AudioStreamPlayer.new();player.bus="ArenaMusic";add_child(player);players.append(player)
func desired_track() -> String:
	if game.lobby.active():return "lobby"
	if not game.active:return "title"
	return game.match_mode.kind if TRACKS.has(game.match_mode.kind) else "dm"
func _process(delta: float) -> void:
	if players.is_empty():return
	var desired:=desired_track()
	if not cache.has(desired) and not loading.has(desired):
		var path: String="res://deathmatch/audio/music/"+TRACKS[desired]+".ogg"
		if ResourceLoader.load_threaded_request(path)==OK:loading[desired]=path
	for key in loading.keys():
		var status:=ResourceLoader.load_threaded_get_status(loading[key])
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			cache[key]=ResourceLoader.load_threaded_get(loading[key]);loading.erase(key)
		elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:loading.erase(key)
	if selected!=desired and cache.has(desired):
		# On a rapid mode change preserve whichever outgoing track is louder.
		var outgoing:=current if fade>=.5 else 1-current
		outgoing_gain=db_to_linear(players[outgoing].volume_db) if players[outgoing].playing else 0.0
		current=1-outgoing;selected=desired;fade=0
		var stream: AudioStreamOggVorbis=cache[selected].duplicate();stream.loop=true
		players[current].stream=stream;players[current].volume_db=-80;players[current].play()
	fade=minf(1,fade+delta/2.5)
	players[current].volume_db=linear_to_db(maxf(.0001,sin(fade*PI*.5)))
	players[1-current].volume_db=linear_to_db(maxf(.0001,outgoing_gain*cos(fade*PI*.5)))
	if fade>=1 and players[1-current].playing:players[1-current].stop();players[1-current].stream=null
func stop() -> void:
	set_process(false)
	for player in players:player.stop();player.stream=null
	players.clear();cache.clear()
func _exit_tree() -> void:
	stop()
	# Drain any outstanding resource request during teardown only.
	for path in loading.values():ResourceLoader.load_threaded_get(path)
	loading.clear()
	if owned_bus:
		var index:=AudioServer.get_bus_index("ArenaMusic")
		if index>=0:AudioServer.remove_bus(index)
