extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Config=preload("res://deathmatch/server/config.gd")
var g
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func setup_mode(mode: String,enabled: bool):
	g.jetpacks.clear();g.current_map="jetpack_fixture";g.spawn_points=[Fixture.point(-8),Fixture.point(8),Fixture.point(0,6)];g.spawn_yaws=[0.0,0.0,0.0]
	g.map_objectives={"red":Fixture.point(-8),"blue":Fixture.point(8)}
	g.pickups=[]
	for row in [["health",100,Fixture.point(-4)],["weapon",3,Fixture.point(4)],["ammo",0,Fixture.point(0,5)]]:
		g.pickups.append({"kind":row[0],"item":row[1],"position":row[2],"available":true,"respawn":0.0,"node":null})
	g.match_mode.configure({"sv_gametype":mode,"sv_jetpacks":int(enabled)})
	g.match_mode.reset();g.clock=100;g.intermission=0
	for id in g.players:g._spawn(id);g.players[id].invulnerable=0
func run():
	check(Config.DEFAULTS.sv_jetpacks==0,"Jetpacks default to disabled")
	check(Config.parse('set sv_jetpacks "1"').values.sv_jetpacks==1,"Server config accepts the opt-in switch")
	check(Config.parse('set sv_jetpacks "2"').has("error") and Config.parse('set sv_jetpacks "yes"').has("error"),"Jetpack option rejects invalid values")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	g.set_process(false);g.set_physics_process(false);g.active=true
	g.spawn_points=[Fixture.point(-8),Fixture.point(8)];g.spawn_yaws=[0.0,0.0]
	g._add_player(1,"Collector");g._add_player(-1,"Competitor")
	await physics_frame;await physics_frame
	for mode in ["dm","tdm","ctf","ig","if","ft","koth","cc","tf","tb","as"]:
		setup_mode(mode,false);check(g.jetpacks.positions().is_empty(),mode+": disabled config creates no jetpack")
		setup_mode(mode,true)
		var supported: bool=mode in g.jetpacks.MODES
		check(g.jetpacks.positions().size()==(2 if mode=="ctf" else 1 if supported else 0),mode+": exact map/base pickup cap")
		if not supported:continue
		var locations: Array=g.jetpacks.positions();g.jetpacks.rebuild()
		check(g.jetpacks.positions()==locations,mode+": rebuilding the same map cannot duplicate pickups")
		if mode=="ctf":
			check(locations[0].distance_to(g.match_mode.bases[0])<locations[0].distance_to(g.match_mode.bases[1]) and locations[1].distance_to(g.match_mode.bases[1])<locations[1].distance_to(g.match_mode.bases[0]),"CTF has one pickup in each flag-base region")
		var p: Dictionary=g.pickups.filter(func(item):return item.kind=="jetpack")[0]
		var s: Dictionary=g.players[1];g.fighters[1].position=p.position;g._collect(1)
		check(s.jetpack and g.fighters[1].jetpack_enabled and not p.available,mode+": touch grants a usable jetpack and consumes its pickup")
		check(is_equal_approx(p.respawn-g.clock,g.pickup_respawn_delay({"kind":"health","item":100})),mode+": timer is shared with megahealth")
		g.fighters[-1].position=p.position;g._collect(-1)
		check(not g.players[-1].get("jetpack",false),mode+": contested pickup is awarded once")
		g.clock=p.respawn-.001;g._respawn_pickups();check(not p.available,mode+": pickup cannot respawn early")
		g.clock=p.respawn;g._respawn_pickups();check(p.available,mode+": pickup respawns at the megahealth deadline")
		g._collect(1);check(p.available,mode+": an equipped player cannot consume a second pack")
		g._collect(-1);check(g.players[-1].jetpack and not p.available,mode+": another player can take the respawned pack")
		var snapshot: Dictionary=g.match_mode.snapshot()
		check(snapshot.jetpacks and snapshot.jetpack_pickups==locations and g.fighters[1].locomotion_state().has("jetpack"),mode+": layout, option and flight state are replicated")
		if mode in ["ig","if"]:
			var ordinary: Dictionary=g.pickups[0];ordinary.available=true;s.hp=50;g.fighters[1].position=ordinary.position;g._collect(1)
			check(ordinary.available and s.hp==50,mode+": jetpacks do not enable ordinary health pickups")
		g._spawn(1);check(not s.jetpack and not g.fighters[1].jetpack_enabled,mode+": respawn removes ownership and flight state")
	setup_mode("dm",true)
	var s: Dictionary=g.players[1];var a=g.fighters[1]
	g._accept_input(1,{"seq":500,"move":Vector2.RIGHT,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false,"input_life":s.serial,"jetpack":true,"jetpack_event":1})
	g.jetpacks.configure_player(1);a.simulate(Vector2.RIGHT,0,false,.02,g.input_delivery.consume(s,a))
	check(not s.jetpack and not a.jetpack_enabled and a.jetpack_state.mode==0,"Client cannot forge ownership with a boost input")
	g.jetpacks.collect(1);a.jetpack_requested=true;a.simulate(Vector2.RIGHT,0,false,.02)
	g._send_snapshot();check(a.jetpack_state.mode==1,"Authority snapshot does not reset an active acquired pack")
	g._damage(1,1,1000,"Test",true);check(not s.jetpack and not a.jetpack_enabled and a.jetpack_state.mode==0,"Death clears the pack without creating additional map pickups")
	setup_mode("ft",true);g.jetpacks.collect(1);g.match_mode.special.freeze(1,-1)
	check(not s.jetpack and not a.jetpack_enabled,"Freeze removes the pack and cannot preserve flight")
	setup_mode("dm",true);g.jetpacks.collect(1);g._end_round()
	check(not a.jetpack_enabled,"Intermission suspends flight and exhaust")
	g._restart_round();check(not s.jetpack and g.jetpacks.positions().size()==1 and g.pickups.all(func(p):return p.respawn==0),"Round restart restores one pickup and clears ownership/timers")
	g.match_mode.jetpacks=false;g.jetpacks.rebuild();check(g.jetpacks.positions().is_empty(),"Disabling the option removes generated pickups")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/jetpacks/pickups.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("JETPACK_PICKUPS_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
