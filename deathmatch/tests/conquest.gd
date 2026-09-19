extends SceneTree
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Config=preload("res://deathmatch/server/config.gd")
var failures: Array=[]
var assertions:=0
var g
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures.append(label);push_error(label)
func empty() -> Array:
	var result: Array=[]
	for i in 16:result.append([false,false])
	return result
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	create_timer(60).timeout.connect(func():push_error("CQ test watchdog");quit(2))
	var r=Rules.new();var p:=empty()
	check(r.owners==[0,0,1,1,0,0,1,1,1,1,0,0,1,1,0,0],"Diagonal quadrants")
	check(r.scores()==[2,2] and r.winner(true)==-1,"Initial timeout draw")
	p[1][1]=true;r.advance(9,p);check(r.owners[1]==0 and r.progress[1][1]==9,"Perimeter requires 10 points")
	p[1][0]=true;r.advance(20,p);check(r.progress[1][1]==9 and r.contested[1],"Contested capture paused")
	p[1][1]=false;r.advance(.1,p);check(r.progress[1][1]==0,"Absent attacker loses all points")
	p=empty();p[1][1]=true;r.advance(10,p);check(r.owners[1]==1 and r.progress[1]==[0.0,0.0],"Capture clears both progress counters")
	p=empty();p[0][1]=true;r.advance(60,p);check(r.owners[0]==0 and r.progress[0][1]==0,"Homebase locked until all three perimeters")
	r.owners[4]=1;r.owners[5]=1;r.advance(29,p);check(r.owners[0]==0 and r.progress[0][1]==29,"Homebase requires 30 points")
	r.advance(1,p);check(r.owners[0]==1 and r.scores()==[1,3] and r.winner(true)==1,"Homebase capture changes timeout winner")
	r.owners[15]=1;check(r.winner()==1,"Four bases immediately win")
	r.reset();r.owners[1]=1;r.owners[4]=1;r.owners[5]=1;r.progress[0][1]=29
	p=empty();p[0][1]=true;p[1][0]=true;r.progress[1][0]=9;r.advance(1,p)
	check(r.owners[1]==0 and r.owners[0]==0 and r.progress[0][1]==0,"Simultaneous perimeter loss blocks base completion")
	check(Rules.radio_connected(0,1) and Rules.radio_connected(0,4) and Rules.radio_connected(0,0),"Radio direct gate neighbors and current district")
	check(not Rules.radio_connected(0,5) and not Rules.radio_connected(3,4) and not Rules.radio_connected(0,15),"Radio excludes diagonal, row wrap and remote districts")
	check(r.nearest(0,Rules.center(15))==15,"Nearest controlled respawn district")
	r.owners.fill(1);check(r.nearest(0,Vector3.ZERO)==-1,"No enemy territory respawn fallback")
	var a:=Config.parse('set sv_gametype cq\nset sv_maxclients 8\nset sv_cq_maxclients 64\nset sv_cq_bot_fill 64')
	check(not a.has("error") and a.values.sv_maxclients==8 and a.values.sv_cq_maxclients==64 and a.values.sv_weapon_rules=="ut99","Independent CQ capacity and default loadout")
	for source in ['set sv_maxclients 64','set sv_cq_maxclients 65','set sv_cq_bot_fill 65','set sv_gametype cq\nset sv_gametypes "cq dm"','set sv_gametype cq\nset sv_lobby 1','set sv_gametype cq\nset sv_cq_maxclients 32\nset sv_cq_bot_fill 64']:
		check(Config.parse(source).has("error"),"Reject unsafe config: "+source)
	var backend:=Config.parse('set sv_gametype cq\nset sv_cq_backend districts\nset sv_cq_worker_limit 2\nset sv_cq_maxclients 64\nset sv_maxclients 8')
	check(not backend.has("error") and backend.values.sv_cq_worker_limit==2 and backend.values.sv_cq_maxclients==64 and backend.values.sv_maxclients==8,"Worker budget is independent of CQ and ordinary capacity")
	check(Config.parse('').values.sv_cq_backend=="monolithic","Normal startup keeps monolithic backend")
	for source in ['set sv_cq_backend districts','set sv_gametype cq\nset sv_cq_backend unknown','set sv_gametype cq\nset sv_cq_worker_limit 1','set sv_gametype cq\nset sv_cq_worker_limit 17']:
		check(Config.parse(source).has("error"),"Reject unsafe worker config: "+source)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.set_physics_process(false);g.set_process(false)
	g.cq_profile=true;check(g.match_mode.conquest.install().is_empty(),"Baked map installed")
	g.dedicated=true;g.match_mode.configure({"sv_gametype":"cq"});g.selected_map=g.match_mode.conquest.MAP_ID;g.max_clients=64
	g.start_host("CQ tests",0,100,30,true)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():g._peer_left(id)
	check(g.active and g.max_clients==64 and g.armory.effective()=="ut99","CQ host preserves own capacity")
	for i in 64:g._add_player(-1000-i,"CQ %d"%i)
	var counts: Array=[];counts.resize(16);counts.fill(0)
	var teams: Array=[0,0]
	for id in g.players:
		var zone:=Rules.district(g.fighters[id].position);counts[zone]+=1;teams[g.players[id].team]+=1
		check(g.players[id].team==Rules.INITIAL[zone],"Initial spawn friendly")
	check(teams==[32,32] and counts.all(func(n):return n==4),"64 players: 32 per team and four per district")
	check(g.pickups.size()==128,"CQ equipment layout preserves deterministic 128 slots")
	for pickup in g.pickups:
		var home: bool=Rules.district(pickup.position) in Rules.HOMEBASES
		if not home:check(not (pickup.kind=="weapon" and pickup.item in [6,8,9,4]) and not g.powerful_pickup(pickup.kind,pickup.item),"High equipment restricted to homebases")
	await physics_frame
	for zone in 16:
		var pos:=Rules.center(zone)
		var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP,pos-Vector3.UP,1))
		check(not hit.is_empty() and hit.normal.y>.9,"Capture circle has ground %d"%zone)
	g.votes.allowed_modes=["cq","dm"];g.votes.change_mode("dm");g.match_mode.kind="dm"
	check(g.match_mode.kind=="cq" and not g._rotate_map(g.lobby.ID),"CQ mode setter and map transition reject lobby/other mode")
	var admin=preload("res://deathmatch/server/rcon.gd").new();g.add_child(admin);admin.game=g
	check(admin.execute("mode dm").has("error") and admin.execute("match cq prototype_km1 ut99").has("error"),"Admin cannot migrate CQ session")
	var id: int=g.players.keys()[0];var team: int=g.players[id].team
	g.fighters[id].position=Rules.center(2);g.players[id].dead=true;g._spawn(id)
	check(Rules.district(g.fighters[id].position)==g.match_mode.conquest.rules.nearest(team,Rules.center(2)),"Death respawns at nearest friendly district")
	var mates: Array=g.players.keys().filter(func(peer):return g.players[peer].team==team)
	for peer in mates:g.fighters[peer].position=Rules.center(15)
	g.fighters[mates[0]].position=Rules.center(0);g.fighters[mates[1]].position=Rules.center(1);g.fighters[mates[2]].position=Rules.center(5)
	var recipients: Array=g.voice.recipients(mates[0],true)
	check(mates[1] in recipients and not mates[2] in recipients and not mates[3] in recipients,"Authoritative radio relay enforces direct district connectivity")
	for peer in recipients:check(g.players[peer].team==team,"Radio keeps team isolation")
	# Dead actors and spectators cannot contest an enemy's capture.
	for peer in g.players:g.fighters[peer].position=Rules.center(15)+Vector3(20,0,20)
	var enemy: int=g.players.keys().filter(func(peer):return g.players[peer].team==1)[0]
	var friend: int=g.players.keys().filter(func(peer):return g.players[peer].team==0)[0]
	g.fighters[enemy].position=Rules.center(1);g.players[enemy].dead=false
	g.fighters[friend].position=Rules.center(1);g.players[friend].dead=true
	g.match_mode.conquest.tick(10)
	check(g.match_mode.conquest.rules.owners[1]==1,"Actual KOTH presence ignores dead contestants")
	g.match_mode.conquest.reset()
	var snapshot: Dictionary=g.match_mode.snapshot();g.match_mode.receive(snapshot)
	check(g.match_mode.conquest.rules.owners==Rules.INITIAL,"Objective snapshot roundtrip")
	var model_manifest: Dictionary=g.loading.manifest(123456)
	check(model_manifest.size()<=64,"Joining human model manifest stays bounded at full bot capacity")
	var pickup: Dictionary=g.pickups.filter(func(row):return row.kind=="weapon" and row.item==3)[0]
	g.fighters[id].position=pickup.position;g.players[id].dead=false;g.players[id].owned=[0,2,11];g.players[id].ammo=[0,0,0,0]
	g._collect(id)
	check(g.players[id].owned.has(3) and not g.players[id].owned.has(9) and not pickup.available,"Perimeter shock pickup grants no bundled sniper and disappears")
	g.clock=pickup.respawn;g._respawn_pickups();check(pickup.available,"CQ uses normal weapon respawn")
	g.dedicated=false;g.round_left=0;g._server_tick(.01);g.dedicated=true
	check(g.intermission>0 and g.round_message.begins_with("DRAW") and not g.lobby.active(),"Real timeout produces 2-2 draw without lobby")
	g._restart_round()
	check(g.match_mode.kind=="cq" and g.current_map==g.match_mode.conquest.MAP_ID and g.match_mode.scores==[2,2] and g.intermission==0,"Round restart remains CQ and resets base ownership")
	for zone in Rules.HOMEBASES:g.match_mode.conquest.rules.owners[zone]=0
	g.match_mode.conquest.tick(.01)
	check(g.intermission>0 and g.round_message.begins_with("RED WINS"),"Real objective tick ends round at four bases")
	print("CONQUEST_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures,"teams":teams,"district_population":counts}))
	DirAccess.make_dir_recursive_absolute("res://test-results/conquest")
	FileAccess.open("res://test-results/conquest/rules.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"teams":teams,"district_population":counts},"\t"))
	g.disconnect_game();g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
