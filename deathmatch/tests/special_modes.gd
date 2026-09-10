extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
class HitProbe extends RefCounted:
	var impacts:=0
	var pain:=0
	func hit(_id,_pos,_direction,_amount,_dead,_gibbed,_seed):impacts+=1
	func local_hit():pain+=1
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():call_deferred("run")
func prepare(kind: String) -> void:
	g.intermission=0;g.round_left=600;g.match_mode.configure({"sv_gametype":kind});g.match_mode.reset()
	for id in g.players:
		g.players[id].team=0 if id in [1,-2] else 1
		g._spawn(id);g.players[id].invulnerable=0;g.players[id].kills=0
		g.fighters[id].position=Fixture.point(-15,15)
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Tester",0,20,10,true,"ig");g.bots.free();g.bots=null;g.set_physics_process(false)
	check(g.match_mode.kind=="ig" and not g.match_mode.team_game(),"IG host selection remains free-for-all")
	check(g.players[1].owned==[9] and g.players[1].weapon==9,"IG railgun-only spawn")
	prepare("ig");g.players[-1].armor=200;g.players[-1].tier=2
	g._damage(-1,1,10000,"RAILGUN");check(g.players[-1].dead,"Railgun kills armored target")
	g._spawn(-1);g._damage(-1,1,10000,"RAILGUN");check(not g.players[-1].dead,"Railgun respects spawn protection")
	g.players[1].cooldown=0;g.fighters[1].position=Fixture.point(0,8);g.fighters[-1].position=Fixture.point(0,3);g.fighters[-2].position=Fixture.point(0,0);g.fighters[-3].position=Fixture.point(0,-5)
	for id in [-1,-2,-3]:g.players[id].invulnerable=0
	g.players[1].yaw=0;g.players[1].pitch=0;g._fire(1)
	check(g.players[-1].dead and g.players[-2].dead and g.players[-3].dead,"Rail penetrates aligned opponents")
	check(g.players[1].cooldown==1.5 and g.players[1].ammo==[0,0,0,0],"Rail cooldown and unlimited ammunition")
	prepare("ig");g.fighters[1].position=Fixture.point();g.players[1].yaw=-PI/2;g.players[1].cooldown=0;g.fighters[-1].position=Fixture.point(12,0);g._fire(1)
	check(not g.players[-1].dead,"Rail stops at solid wall before target")
	prepare("cc");check(g.players[1].owned==[1],"CC chainsaw-only spawn")
	g.players[1].hp=40;g.players[-1].hp=5;g._damage(-1,1,40,"CHAINSAW")
	check(g.players[1].hp==45,"CC heals actual damage, excluding overkill")
	g.players[1].armor=200;g.match_mode.tick(1.0);check(g.players[1].hp==42,"CC loses 3 health per second through armor")
	var effects=g.effects;var probe:=HitProbe.new();g.effects=probe;g.headless=false;g.hurt_flash=0
	g.match_mode.tick(1.0)
	check(g.hurt_flash>0 and probe.impacts==0 and probe.pain==0,"CC hunger retains screen feedback without impact or pain audio")
	g._damage(1,-1,6,"CHAINSAW")
	check(probe.impacts==1 and probe.pain==1,"Weapon damage in CC retains normal pain audio")
	g.effects=effects;g.headless=true
	g.players[1].hp=1;g.match_mode.tick(1.0);check(g.players[1].dead,"CC hunger can kill")
	prepare("cc");g.players[1].melee=true;g.players[1].melee_state={};g._update_melee(1);check(g.players[1].melee_state.is_empty(),"CC blocks physical melee")
	prepare("ft");g.fighters[-1].position=Fixture.point();g.fighters[-3].position=Fixture.point(1,0)
	g._damage(-1,1,1000,"SHOTGUN");check(g.match_mode.special.frozen.has(-1) and not g.players[-1].dead,"Lethal FT damage freezes instead of respawning")
	g.match_mode.tick(2.9);check(g.match_mode.special.frozen.has(-1),"Thaw requires three full seconds")
	g.fighters[-3].position=Fixture.point(5,0);g.match_mode.tick(.2);check(g.match_mode.special.frozen[-1]==0.0,"Interrupted contact resets thaw timer")
	g.fighters[-3].position=Fixture.point(1,0);g.match_mode.tick(3.0)
	check(not g.match_mode.special.frozen.has(-1) and g.players[-1].hp==100 and g.players[-1].owned==[2],"Friendly contact thaws with fresh pistol")
	g.players[-1].invulnerable=0;g._damage(-1,1,1000,"SHOTGUN");g._damage(-3,1,1000,"SHOTGUN");g.match_mode.tick(.1)
	check(g.match_mode.scores==[1,0] and g.match_mode.special.reset_at>0,"Full team freeze scores exactly once")
	g.match_mode.tick(.1);check(g.match_mode.scores==[1,0],"Freeze round score cannot repeat")
	var replica=preload("res://deathmatch/modes/match.gd").new();replica.setup(g);replica.receive(g.match_mode.snapshot())
	check(replica.special.frozen.size()==2 and replica.special.blocked(1),"Clients receive frozen state and round pause")
	g.clock+=3.1;g.match_mode.tick(.1);check(g.match_mode.special.frozen.is_empty() and g.players[-1].hp==100,"Next freeze round restores everyone")
	print("SPECIAL_MODES_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
