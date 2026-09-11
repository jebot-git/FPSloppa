extends Node
## Server-authorized, non-positional calls with a bounded priority queue.
const CLIPS=["start","first_blood","double_kill","triple_kill","rampage","dominating","unstoppable","team_deathmatch","capture_the_flag","last_man_standing","objective_completed","round_winner","game_over"]
var game
var allowed:=true
var player: AudioStreamPlayer
var streams: Dictionary={}
var pending: Array=[]
var recent: Dictionary={}
var owned_bus:=false
var was_active:=false
var was_over:=false
var first_blood:=false
var streaks: Dictionary={}
var combos: Dictionary={}
signal cue_received(cue: String,target: int)

func setup(arena: Node) -> void:
	game=arena
	if game.headless:set_process(false);return
	if AudioServer.get_bus_index("ArenaAnnouncer")<0:
		owned_bus=true;AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaAnnouncer")
		AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	for cue in CLIPS:streams[cue]=load("res://deathmatch/audio/announcer/"+cue+".ogg")
	player=AudioStreamPlayer.new();player.bus="ArenaAnnouncer";add_child(player)

@rpc("authority","call_remote","reliable",0)
func policy(enabled: bool) -> void:
	if enabled and not allowed:was_active=false;was_over=false
	allowed=enabled
	if not allowed:clear_audio()

@rpc("authority","call_local","reliable",0)
func receive(cue: String,target: int=0) -> void:
	if not allowed or not cue in CLIPS:return
	cue_received.emit(cue,target)
	game.demos.event("_announcer_cue",[cue,target])
	game._announcer_cue(cue,target)

func enqueue(cue: String,priority: int=1) -> void:
	if not allowed or game.headless or not game.active or game.lobby.active() or not streams.has(cue):return
	if float(game.presentation.get("announcer",.8))<=0:return
	if game.clock-float(recent.get(cue,-100.0))<1.0:return
	recent[cue]=game.clock
	if priority>=3:pending.clear()
	pending.append({"cue":cue,"priority":priority,"until":game.clock+6.0})
	pending.sort_custom(func(a,b):return a.priority>b.priority)
	while pending.size()>4:pending.pop_back()

func clear_audio() -> void:
	pending.clear();recent.clear()
	if is_instance_valid(player):player.stop();player.stream=null

func reset() -> void:
	clear_audio();was_active=false;was_over=false;reset_scores()

func reset_scores() -> void:
	first_blood=false;streaks.clear();combos.clear()

func forget(id: int) -> void:
	streaks.erase(id);combos.erase(id)

func killed(victim: int,attacker: int) -> void:
	forget(victim)
	if not allowed or not multiplayer.is_server() or not game.players.has(attacker) or victim==attacker or game.match_mode.same_team(victim,attacker):return
	streaks[attacker]=int(streaks.get(attacker,0))+1
	var previous: Dictionary=combos.get(attacker,{})
	var count:=int(previous.get("count",0))+1 if game.clock-float(previous.get("time",-100.0))<=3.0 else 1
	combos[attacker]={"count":count,"time":game.clock}
	if not first_blood:first_blood=true;receive.rpc("first_blood",0)
	var cue: String={5:"rampage",10:"dominating",15:"unstoppable"}.get(streaks[attacker],"")
	if cue.is_empty():cue="double_kill" if count==2 else "triple_kill" if count==3 else ""
	if not cue.is_empty() and attacker>0:receive.rpc(cue,attacker)

func result_cue() -> String:
	var id: int=game.demos.selected_player if game.demos.playing else multiplayer.get_unique_id()
	var mine: Dictionary=game.players.get(id,{})
	if mine.is_empty() or mine.spectator:return "game_over"
	if game.match_mode.team_game():
		var scores: Array=game.match_mode.scores
		return "round_winner" if mine.team in [0,1] and scores[mine.team]>scores[1-mine.team] else "game_over"
	var contenders: Array=game.players.values().filter(func(s):return not s.spectator)
	var best: int=contenders.map(func(s):return s.kills).max() if not contenders.is_empty() else -999
	return "round_winner" if mine.kills==best and contenders.filter(func(s):return s.kills==best).size()==1 else "game_over"

func _process(_delta: float) -> void:
	var active: bool=game.active and not game.lobby.active()
	var over: bool=game.intermission>0
	if not active:
		if was_active:clear_audio()
		was_active=false;was_over=false;return
	if allowed:
		if over and not was_over:enqueue(result_cue(),3)
		elif not over and (not was_active or was_over):
			clear_audio()
			var mode: String={"tdm":"team_deathmatch","ctf":"capture_the_flag","tf":"capture_the_flag"}.get(game.match_mode.kind,"")
			if not mode.is_empty():enqueue(mode,0)
			enqueue("start",0)
	was_active=active;was_over=over
	if not allowed or float(game.presentation.get("announcer",.8))<=0:clear_audio();return
	pending=pending.filter(func(row):return row.until>game.clock)
	if not player.playing and not pending.is_empty():
		player.stream=streams[pending.pop_front().cue];player.play()

func _exit_tree() -> void:
	clear_audio()
	streams.clear()
	if owned_bus:
		var index:=AudioServer.get_bus_index("ArenaAnnouncer")
		if index>=0:AudioServer.remove_bus(index)
