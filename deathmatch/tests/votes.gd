extends SceneTree
var g
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	g.match_mode.kind="tdm";g.match_mode.reset();g.active=true;g.menu_open=false
	for id in range(1,5):g._add_player(id,"Player"+str(id))
	g._add_player(5,"Observer",true)
	check(not g.votes.start(5,"balance",""),"Spectators cannot propose votes")
	check(not g.votes.start(1,"map","../../bad"),"Vote cannot load a map outside server catalog")
	check(not g.votes.start(1,"arbitrary",""),"Only named vote actions accepted")
	for id in range(1,5):g.players[id].team=0
	check(g.votes.change_team(4,1) and g.players[4].team==1,"Player can join smaller team")
	check(not g.votes.change_team(4,0),"Switch cannot make teams more uneven or bypass cooldown")
	check(g.votes.start(1,"balance",""),"Active player can propose balance vote")
	check(g.votes.ballot.needed==3,"Four eligible players require three yes votes")
	check(not g.votes.cast(1,true) and not g.votes.cast(5,true),"Duplicate votes and spectator votes rejected")
	g._add_player(6,"Late join");check(not g.votes.cast(6,true),"Late join cannot change electorate")
	g.votes.cast(2,true);check(not g.votes.ballot.is_empty(),"Two of four votes do not pass")
	g.votes.cast(3,true)
	var counts: Array=[0,0]
	for s in g.players.values():
		if not s.spectator:counts[s.team]+=1
	check(g.votes.ballot.is_empty() and absi(counts[0]-counts[1])<=1,"Majority vote balances active teams including late join")
	check(not g.votes.start(2,"balance",""),"Proposal cooldown prevents vote spam")
	g.clock+=61;g.votes.start(2,"balance","");g.clock+=26;g.votes.tick();check(g.votes.ballot.is_empty(),"Vote expires after 25 seconds without majority")
	g.clock+=61;g.votes.start(2,"balance","");g.intermission=10;g.votes.tick();check(g.votes.ballot.is_empty(),"Round end cancels pending vote")
	g.intermission=0;g.clock+=61;g.votes.enabled=false;check(not g.votes.start(2,"map","lqdm2"),"Server can disable map and balance voting")
	const External=preload("res://deathmatch/voice/external.gd")
	check(External.valid_url("mumble://voice.example.org:64738/Entryway?version=1.2.0"),"Dedicated Mumble endpoint validates")
	for url in ["https://example.org","mumble://user:password@host/","mumble://host:65536/","mumble://host/;command","file:///tmp/app","mumble://host/?evil=1"]:check(not External.valid_url(url),"Unsafe external voice URL rejected: "+url)
	const Config=preload("res://deathmatch/server/config.gd")
	check(Config.parse('set sv_voice_backend "mumble"').has("error"),"Mumble backend requires explicit valid endpoint")
	check(not Config.parse('set sv_voice_backend "mumble"\nset sv_mumble_url "mumble://voice.example.org:64738/Entryway"').has("error"),"Dedicated server accepts optional Mumble backend")
	check(Config.parse('set sv_gametypes "tdm ctf"').has("error"),"Allowed modes must include initial server mode")
	check(Config.parse('set sv_gametypes "dm arbitrary"').has("error"),"Unknown modes rejected")
	check(Config.parse('set sv_gametypes "dm tdm ctf koth"').values.gametypes.size()==4,"Server can enable four game types")
	g.votes.enabled=true;g.votes.cooldown=0;g.votes.allowed_modes=["tdm"]
	check(not g.votes.start(1,"mode","ctf"),"Single-mode server rejects mode votes")
	g.votes.allowed_modes=["tdm","ctf"]
	check(not g.votes.start(1,"mode","koth"),"Vote cannot select a mode outside server allowlist")
	check(g.votes.start(1,"mode","ctf"),"Multi-mode server accepts permitted game-type proposal")
	check(g.votes.snapshot().title=="MODE: CTF","Game-type ballot replicates its target")
	g.votes.reset()
	print("VOTES_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
