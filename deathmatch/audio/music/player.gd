extends Node
const TRACKS=[preload("res://deathmatch/audio/music/iron_circuit.ogg"),preload("res://deathmatch/audio/music/pressure_lock.ogg"),preload("res://deathmatch/audio/music/foundry_run.ogg"),preload("res://deathmatch/audio/music/dark_relay.ogg")]
var game
var players: Array[AudioStreamPlayer]=[]
var selected:=-1
var current:=0
var fade:=1.0
var owned_bus:=false
func setup(arena: Node) -> void:
	game=arena
	if game.headless:return
	if AudioServer.get_bus_index("ArenaMusic")<0:
		owned_bus=true;AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaMusic")
	for i in range(2):
		var player:=AudioStreamPlayer.new();player.bus="ArenaMusic";add_child(player);players.append(player)
func _process(delta: float) -> void:
	if players.is_empty():return
	var desired:=posmod(str(game.current_map).hash(),TRACKS.size()) if game.active else 0
	if selected!=desired:
		selected=desired;current=1-current;fade=0
		var stream: AudioStreamOggVorbis=TRACKS[selected].duplicate();stream.loop=true
		players[current].stream=stream;players[current].volume_db=-60;players[current].play()
	fade=minf(1,fade+delta/.9)
	players[current].volume_db=linear_to_db(maxf(.001,fade))
	players[1-current].volume_db=linear_to_db(maxf(.001,1-fade))
	if fade>=1 and players[1-current].playing:players[1-current].stop()
func stop() -> void:
	set_process(false)
	for player in players:
		player.stop()
		player.stream=null
	players.clear()
func _exit_tree() -> void:
	stop()
	if owned_bus:
		var index:=AudioServer.get_bus_index("ArenaMusic")
		if index>=0:AudioServer.remove_bus(index)
