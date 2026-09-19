extends Node
## Local round-time feedback. Snapshot corrections cannot replay a second's tick.
var game
var player: AudioStreamPlayer
var gong: AudioStreamPlayer
var played: Dictionary={}
var round_key:=""
var previous:=INF
signal ticked(second: int)
signal round_ended
func setup(arena: Node) -> void:
	game=arena
	if game.headless:set_process(false);return
	player=AudioStreamPlayer.new();player.bus="ArenaEffects";player.volume_db=-5
	player.stream=preload("res://deathmatch/audio/round_tick.wav");add_child(player)
	gong=AudioStreamPlayer.new();gong.bus="ArenaEffects";gong.volume_db=-6
	gong.stream=load("res://deathmatch/audio/round_gong.wav");add_child(gong)
func play_gong() -> void:
	round_ended.emit()
	if is_instance_valid(gong):gong.play()
func advance(remaining: float,enabled: bool,key: String) -> bool:
	if not enabled or not is_finite(remaining):played.clear();round_key="";previous=INF;return false
	if key!=round_key or remaining>previous+10.0:played.clear();round_key=key
	previous=remaining
	var second:=ceili(remaining)
	if second<1 or second>10 or played.has(second):return false
	played[second]=true;ticked.emit(second);return true
func _process(_delta: float) -> void:
	if not game:return
	var enabled: bool=game.active and not game.quitting and not game.map_loading and not game.lobby.active() and game.intermission<=0
	var key:=str(game.map_epoch)+":"+str(game.match_mode.assault.leg)
	var preparing:bool=game.match_mode.titanball.preparing()
	var remaining:float=game.match_mode.titanball.preparation_left if preparing else game.round_left
	key+=":preparation" if preparing else ":match"
	if advance(remaining,enabled,key) and is_instance_valid(player):player.play()
func clear() -> void:
	if is_instance_valid(player):player.stop();player.stream=null
	if is_instance_valid(gong):gong.stop();gong.stream=null
	played.clear()
func _exit_tree() -> void:clear()
