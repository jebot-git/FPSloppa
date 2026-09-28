extends SceneTree
var g
var de
var a
var checks:=0
var failures: Array=[]
var heard: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("DE calls",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	de=g.match_mode.defusal;a=g.announcer
	a.cue_received.connect(func(cue,target):heard.append([cue,target]))
	await physics_frame;await physics_frame
	check(a.player==null and a.streams.is_empty(),"Dedicated/headless authority allocates no voice streams")
	g.headless=false;a.setup(g);a.set_process(false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("ArenaAnnouncer"),true)
	check(a.DE_TEAMS.size()==2 and a.DE_EVENTS.size()==3 and a.streams.values().all(func(s):return s!=null and s.get_length()>0),"All DE and existing announcer streams decode")
	de.begin_round();g.players[1].team=de.attacking
	a.update_defusal_team()
	check(a.pending.size()==1 and a.pending[0].cue=="de_terrorists","Player hears their terrorist assignment")
	for i in 30:a.update_defusal_team()
	check(a.pending.size()==1,"Repeated snapshots/frames do not repeat team assignment")
	g.clock+=2;de.attacking=1-de.attacking;a.update_defusal_team()
	check(a.pending.size()==1 and a.pending[0].cue=="de_counter_terrorists","Side swap replaces the old role with counter-terrorists")
	a.pending.clear();g.clock+=2;de.round_id+=1;a.update_defusal_team()
	check(a.pending.size()==1 and a.pending[0].cue=="de_counter_terrorists","A new round repeats the current role once")
	a.clear_audio();de.phase="live";a.update_defusal_team()
	check(a.pending.size()==1 and a.pending[0].cue=="de_counter_terrorists","Late joining player learns their side during a live round")
	a.clear_audio();g.players[1].spectator=true;a.update_defusal_team()
	check(a.pending.is_empty(),"Unassigned spectators do not hear a false team assignment")
	g.players[1].spectator=false;g.players[1].team=de.attacking;g.clock+=2
	g.demos.playing=true;g.demos.selected_player=-1;g.players[-1].team=1-de.attacking;a.update_defusal_team()
	check(a.pending.size()==1 and a.pending[0].cue=="de_counter_terrorists","Replay viewpoint uses the selected player's role")
	g.demos.playing=false;g.demos.selected_player=0;a.clear_audio()
	for attackers in [0,1]:
		de.attacking=attackers
		for winner in [0,1]:
			for reason in ["BOMB EXPLODED","BOMB DEFUSED","TIME EXPIRED","ATTACKERS ELIMINATED","DEFENDERS ELIMINATED"]:
				de.phase="live";g.clock+=2;heard.clear();de.finish_round(winner,reason);de.finish_round(winner,reason)
				check(heard==[["de_terrorists_win" if winner==attackers else "de_counter_terrorists_win",0]],"Single correct role winner for side %d / team %d / %s"%[attackers,winner,reason])
	g.headless=true;de.begin_round();de.phase="live";de.phase_end=g.clock+120
	g.players[1].team=de.attacking;g.players[1].dead=false;g.players[1].spectator=false;g.players[1].yaw=0.0
	g.fighters[1].position=de.sites[0]+Vector3(0,0,.8);de.carrier=1;de.held=true
	for i in 4:g.clock+=.2;de.digit(1,de.arm_code[de.arm_index])
	heard.clear();check(de.plant(1),"Valid surface planting succeeds through authority")
	check(not de.plant(1) and heard==[["de_bomb_planted",0]],"One successful plant sends exactly one cue to everyone")
	g.headless=false;a.clear_audio();g.clock+=2
	a.enqueue("first_blood");a.player.stream=a.streams.first_blood;a.player.play()
	g._announcer_cue("de_bomb_planted",0)
	check(not a.player.playing and a.pending.size()==1 and a.pending[0].cue=="de_bomb_planted","Plant confirmation interrupts and replaces queued kill awards")
	a._process(0)
	check(a.player.playing and a.player.stream==a.streams.de_bomb_planted,"Plant chirp and spoken call play without distance attenuation")
	a.policy(false);heard.clear();a.defusal_event("de_terrorists_win");a.update_defusal_team()
	check(a.pending.is_empty() and heard.is_empty() and not a.player.playing,"Server announcer setting suppresses all DE voices")
	a.policy(true);g.presentation.announcer=0;g._announcer_cue("de_bomb_planted");a.update_defusal_team()
	check(a.pending.is_empty(),"Local announcer mute applies to DE calls")
	g.presentation.announcer=.8;g.match_mode.kind="dm"
	for cue in a.DE_TEAMS+a.DE_EVENTS:a.receive(cue)
	check(heard.is_empty() and a.pending.is_empty(),"DE cues are rejected in other modes")
	a.clear_audio();await create_timer(.15).timeout
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/de-announcements/unit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_ANNOUNCEMENTS_RESULT ",JSON.stringify(result));g.headless=true;g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
