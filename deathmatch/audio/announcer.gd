extends Node
## Server-authorized, non-positional calls with a bounded priority queue.
const CLIPS=["first_blood","double_kill","triple_kill","rampage","dominating","unstoppable","objective_completed"]
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
signal cue_started(cue: String)

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
	if not allowed or not accepts(cue):return
	cue_received.emit(cue,target)
	game.demos.event("_announcer_cue",[cue,target])
	game._announcer_cue(cue,target)

func enqueue(cue: String,priority: int=1) -> void:
	if not accepts(cue) or not allowed or game.headless or not game.active or game.lobby.active() or not streams.has(cue):return
	if float(game.presentation.get("announcer",.8))<=0:return
	if cue!="objective_completed" and game.clock-float(recent.get(cue,-100.0))<1.0:return
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

func accepts(cue: String) -> bool:
	return cue in CLIPS and (cue!="objective_completed" or game.match_mode.kind in ["tf","as"])

func objective_completed() -> void:
	if multiplayer.is_server() and allowed and game.match_mode.kind in ["tf","as"]:
		receive.rpc("objective_completed",0)

func _process(_delta: float) -> void:
	var active: bool=game.active and not game.lobby.active()
	var over: bool=game.intermission>0
	if not active:
		if was_active:clear_audio()
		was_active=false;was_over=false;return
	was_active=active;was_over=over
	if not allowed or float(game.presentation.get("announcer",.8))<=0:clear_audio();return
	pending=pending.filter(func(row):return row.until>game.clock)
	if not player.playing and not pending.is_empty():
		var cue: String=pending.pop_front().cue
		player.stream=streams[cue];player.play();cue_started.emit(cue)

func _exit_tree() -> void:
	clear_audio()
	streams.clear()
	if owned_bus:
		var index:=AudioServer.get_bus_index("ArenaAnnouncer")
		if index>=0:AudioServer.remove_bus(index)
