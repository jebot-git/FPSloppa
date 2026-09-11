extends SceneTree
# Run through run_announcer_tests.py: mixer lifecycle checks need PulseAudio.
const Config=preload("res://deathmatch/server/config.gd")
const Settings=preload("res://deathmatch/settings/preferences.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	check(Config.parse('').values.sv_announcer==1 and Config.parse('set sv_announcer 0').values.sv_announcer==0,"Server announcer defaults on and can be disabled in config")
	check(Config.parse('set sv_announcer 2').has('error') and Config.parse('set sv_announcer nope').has('error'),"Server toggle rejects invalid values")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.process_mode=Node.PROCESS_MODE_DISABLED
	var a=g.announcer
	check(a.player==null and a.streams.is_empty(),"Headless server loads no announcer audio resources")
	g.active=true;g.clock=100
	for id in [1,2,3]:g.players[id]=g._new_state('Player'+str(id),id)
	var heard: Array=[]
	a.cue_received.connect(func(cue,target):heard.append([cue,target]))
	a.killed(2,1);g.clock+=1;a.killed(2,1);g.clock+=1;a.killed(2,1)
	check(heard==[['first_blood',0],['double_kill',1],['triple_kill',1]],"First blood is global and rapid double/triple kills address only the killer")
	for i in 12:g.clock+=4;a.killed(2,1)
	check(heard.slice(3)==[['rampage',1],['dominating',1],['unstoppable',1]],"Five, ten and fifteen kills earn distinct streak calls")
	a.killed(1,1)
	check(not a.streaks.has(1) and not a.combos.has(1),"Death and suicide reset both streak and combo")
	heard.clear();a.reset_scores();g.match_mode.kind='tdm';g.players[1].team=0;g.players[2].team=0
	a.killed(2,1)
	check(heard.is_empty() and not a.first_blood,"Friendly kills do not award first blood or streaks")
	a.policy(false);g.players[2].team=1;a.killed(2,1);a.receive('first_blood')
	check(heard.is_empty(),"Disabled server suppresses award dispatch and received calls")
	var snap: Dictionary=g.match_mode.snapshot();a.policy(true);g.match_mode.receive(snap)
	check(not a.allowed,"Mode snapshot carries disabled policy for clients and demo playback")
	a.policy(true);a.receive('../unknown')
	check(heard.is_empty(),"Received cues are restricted to bundled names")
	# Exercise real audio resources and queue behavior through the Dummy backend.
	g.headless=false;a.setup(g);a.set_process(false)
	check(a.streams.size()==a.CLIPS.size() and a.streams.values().all(func(s):return s!=null and s.get_length()>0),"Every bundled Ogg decodes into an audio stream")
	check(a.player.bus=='ArenaAnnouncer' and AudioServer.get_bus_send(AudioServer.get_bus_index('ArenaAnnouncer'))=='Master',"Announcer bypasses positional attenuation and world reverb")
	AudioServer.set_bus_mute(AudioServer.get_bus_index('ArenaAnnouncer'),true)
	g.match_mode.kind='dm';a.clear_audio();a.was_active=true
	for cue in ['first_blood','double_kill','triple_kill','rampage','dominating']:a.enqueue(cue)
	check(a.pending.size()==4,"Notification queue remains bounded during bursts")
	g.match_mode.kind='tf';a.enqueue('objective_completed',2)
	check(a.pending[0].cue=='objective_completed',"Capture calls take precedence over queued awards")
	var queued: int=a.pending.size()
	for cue in ['start','team_deathmatch','capture_the_flag','last_man_standing','round_winner','game_over']:a.enqueue(cue,3);a.receive(cue)
	check(a.pending.size()==queued and heard.is_empty(),"Retired match, mode and result voices cannot queue or dispatch")
	a._process(0)
	check(a.player.playing and a.pending.size()==3,"A queued call starts on the single audio player")
	await create_timer(.2).timeout
	a.policy(false)
	check(not a.player.playing and a.pending.is_empty(),"Disabling policy stops current playback immediately")
	# Let the output mixer retire its stopped playback before removing the bus.
	await create_timer(.5).timeout
	a.policy(true);a.was_active=true;a.enqueue('first_blood');g.clock+=7;a._process(0)
	check(a.pending.is_empty() and not a.player.playing,"Stale calls expire without playback")
	a.clear_audio();g.intermission=0;a.was_active=false;a._process(0)
	check(not a.player.playing and a.pending.is_empty(),"Match start is silent")
	g.intermission=8;a._process(0)
	check(not a.player.playing and a.pending.is_empty(),"Match result is silent")
	for mode in ["ctf","dm","ft"]:
		g.match_mode.kind=mode;a.receive("objective_completed")
	check(heard.is_empty(),"Ordinary CTF and other modes do not trigger objective voice")
	for mode in ["tf","as"]:
		g.match_mode.kind=mode;a.objective_completed()
	check(heard==[["objective_completed",0],["objective_completed",0]],"TF and AS objectives dispatch the global objective voice")
	check(a.pending.size()==2,"Separate objectives completed close together each retain their voice")
	a.clear_audio()
	g.presentation.announcer=0;a.enqueue('rampage')
	check(a.pending.is_empty(),"Local zero volume also prevents delayed queues")
	g.headless=true;a.reset();g.players.clear();g.free()
	await create_timer(.1).timeout
	check(AudioServer.get_bus_index('ArenaAnnouncer')<0,"Owned announcer bus is released on shutdown")
	print('ANNOUNCER_RESULT ',JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
