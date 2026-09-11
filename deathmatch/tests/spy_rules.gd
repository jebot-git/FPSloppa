extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("Spy test",0,20,10,true,"tf");game.set_process(false);game.set_physics_process(false)
	if game.bots:game.bots.free();game.bots=null
	var tf=game.match_mode.fortress;var s: Dictionary=game.players[1]
	s.tf_next="spy";s.team=0;tf.spawn(1);tf.cooldowns[1]=0;s.invulnerable=0
	game.fighters[1].position=Fixture.point();game.players[-1].team=1;game.fighters[-1].position=Fixture.point(0,-2)
	check(not tf.spy_invisibility and tf.action(1) and not s.tf_disguise.is_empty() and not tf.cloaked(1),"Default ability disguises without cloak or cell use")
	game.clock+=20;tf.tick(.01)
	check(not s.tf_disguise.is_empty(),"Disguise persists beyond previous six-second cloak")
	tf.revealed(1);check(s.tf_disguise.is_empty(),"Attack/damage reveal clears copied identity")
	tf.spy_invisibility=true;tf.spawn(1);tf.cooldowns[1]=0
	check(s.ammo[3]==50 and tf.definition(1).action.contains("cell"),"Classic alternative supplies cells and describes their use")
	check(tf.action(1) and tf.cloaked(1) and s.tf_disguise.is_empty() and s.ammo[3]==49,"Invisibility consumes activation cell without simultaneous disguise")
	for i in 5:game.clock+=1;tf.tick(1)
	check(s.ammo[3]==44 and tf.cloaked(1),"Cloak consumes cells over time")
	tf.cooldowns[1]=0;check(tf.action(1) and not tf.cloaked(1),"Use toggles invisibility off")
	tf.tick_spy_cells(2);check(s.ammo[3]==46,"Visible spy regenerates cells")
	s.ammo[3]=2;tf.cooldowns[1]=0;tf.action(1);game.clock+=1;tf.tick(1)
	check(s.ammo[3]==0 and not tf.cloaked(1),"Exhausting cells forces reveal")
	tf.cooldowns[1]=0;check(not tf.action(1),"Empty cells prevent activation")
	s.ammo[3]=50;tf.cooldowns[1]=0;tf.action(1);tf.incoming_damage(1,5,"PISTOL",false)
	check(not tf.cloaked(1),"Damage interrupts cell-powered invisibility")
	var state: Dictionary=tf.snapshot();tf.spy_invisibility=false;tf.receive(state)
	check(tf.spy_invisibility,"Server Spy policy replicates with mode state")
	for invisible in [false,true]:
		tf.spy_invisibility=invisible;tf.cooldowns[1]=0;s.ammo[3]=50;tf.revealed(1);tf.action(1)
		game._begin_melee(1,s.melee_state)
		check(tf.cloaked(1) if invisible else not s.tf_disguise.is_empty(),"Beginning a missed swing preserves undercover state (%s)"%invisible)
		var target: Dictionary=game.players[-1];target.dead=false;target.spectator=false;target.team=0;target.hp=100;target.armor=0;target.invulnerable=0
		game._damage(-1,1,10,"WEAPON WHIP")
		check(tf.cloaked(1) if invisible else not s.tf_disguise.is_empty(),"Friendly-fire rejection preserves undercover state (%s)"%invisible)
		target.team=1;target.invulnerable=game.clock+20;game._damage(-1,1,10,"KICK")
		check(tf.cloaked(1) if invisible else not s.tf_disguise.is_empty(),"Spawn-protected target preserves undercover state (%s)"%invisible)
		target.invulnerable=0;game._damage(-1,1,10,"KICK")
		check(not tf.cloaked(1) and s.tf_disguise.is_empty() and target.hp==90,"Damaging kick reveals Spy (%s)"%invisible)
		tf.cooldowns[1]=0;tf.action(1);s.weapon=0;s.owned=[0,2];s.cooldown=0
		game.fighters[-1].position=Fixture.point(12,12);game._fire(1)
		check(tf.cloaked(1) if invisible else not s.tf_disguise.is_empty(),"Fist attack into empty space preserves undercover state (%s)"%invisible)
		s.weapon=2;s.ammo[0]=10;s.cooldown=0;game._fire(1)
		check(not tf.cloaked(1) and s.tf_disguise.is_empty(),"Gunfire still reveals Spy even on a miss (%s)"%invisible)
	s.vr_device=true;s.weapon=0;s.cooldown=0;s.xr=game.VRPoses.neutral()
	var shots: int=s.shots;game._fire(1)
	check(s.shots==shots and s.cooldown==0,"Server rejects VR trigger-fired fist before effects or damage")
	s.vr_device=false;game._fire(1)
	check(s.shots==shots+1,"Desktop trigger-fired fist remains available")
	game.match_mode.configure({"sv_gametype":"tf"});check(not tf.spy_invisibility,"Default server configuration restores disguise policy")
	game.free();await process_frame;print("SPY_RULES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
