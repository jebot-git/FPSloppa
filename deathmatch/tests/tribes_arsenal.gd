extends SceneTree
const A=preload("res://deathmatch/tribes/arsenal.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func equip(armour: String,guns: Array,pack: String="energy"):
	g.clock+=1;g.match_mode.tribes.energy=[100000,100000,100000]
	check(g.match_mode.tribes.select_equipment(1,armour,guns,pack),"Accept valid equipment "+armour+"/"+pack)
	g._spawn(1);g.fighters[1].position=Fixture.ORIGIN;g.fighters[1].velocity=Vector3.ZERO;g.players[1].cooldown=0;g.players[1].invulnerable=0;g.players[1].input_blocked=false;g.players[1].yaw=0;g.players[1].pitch=0
func clear_projectiles():
	for id in g.projectiles.keys():g._projectile_end(id,g.projectiles[id].position,g.projectiles[id].weapon)
func step_projectiles(seconds: float):
	for i in ceili(seconds*120):g._update_projectiles(1.0/120)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Tribes arsenal",0,100,30,true,"tdm","tribes");g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200));await physics_frame;await physics_frame
	var rules=g.match_mode.tribes;var combat=rules.combat;var s: Dictionary=g.players[1];var actor=g.fighters[1]
	check(g.armory.data(0).name=="BLASTER" and g.armory.data(7).name=="MORTAR" and not g.armory.vr_physical_only(0),"Dedicated weapon table replaces Quake axes and rockets")
	check(not A.valid_loadout("light",[3,2,4,1],"energy") and not A.valid_loadout("light",[3,3],"energy"),"Light carry cap and duplicate weapons rejected")
	check(not A.valid_loadout("medium",[5],"energy") and not A.valid_loadout("light",[5],"shield") and not A.valid_loadout("medium",[7],"ammo"),"Laser needs light plus energy pack; mortar needs heavy")
	equip("light",[0,5,6]);s.weapon=0
	var energy: float=actor.tribes_state.energy
	check(combat.fire(1) and is_equal_approx(actor.tribes_state.energy,energy-6),"Blaster spends shared jet energy")
	clear_projectiles();s.cooldown=0;actor.tribes_state.energy=4.9
	check(not combat.fire(1) and g.projectiles.is_empty(),"Blaster cannot fire below minimum energy")
	s.weapon=5;s.cooldown=0;actor.tribes_state.energy=45
	check(combat.fire(1) and actor.tribes_state.energy==0,"Laser consumes the remaining energy pool")
	equip("light",[3,2,4]);s.weapon=3;actor.velocity=Vector3(20,0,0)
	check(combat.fire(1) and s.tribes_ammo[3]==14,"Disc consumes its own ammo without magazines")
	var shot: Dictionary=g.projectiles.values()[0]
	check(shot.velocity.is_equal_approx(Vector3(10,0,-65)),"Disc inherits half of lateral skiing velocity")
	step_projectiles(.2);check(shot.velocity.x>9.9 and shot.velocity.z<-65.9,"Disc accelerates while preserving lateral inheritance")
	clear_projectiles();s.weapon=2;s.cooldown=0
	check(not combat.fire(1),"Chaingun requires spin-up")
	s.fire=true;s.last_input=g.clock;combat.tick(.5)
	check(combat.fire(1) and s.tribes_ammo[2]==99,"Half-second spin-up permits chaingun shot")
	shot=g.projectiles.values()[0];check(absf(shot.velocity.x-20)<2.2,"Chaingun bullet inherits full skiing velocity")
	clear_projectiles();s.fire=false;combat.tick(1.5);check(absf(combat.spins[1]-.5)<.001,"Chaingun coasts down over three seconds")
	s.tribes_ammo[2]=0;s.cooldown=0;combat.spins[1]=1
	check(not combat.fire(1),"Empty chaingun cannot fire despite generic energy-free definition")
	equip("heavy",[3,2,4,1,7],"ammo")
	check(s.tribes_ammo[2]==350 and s.tribes_ammo[7]==20 and s.tribes_ammo[9]==18 and s.tribes_ammo[10]==8,"Ammo pack extends each original inventory capacity")
	actor.tribes_state.energy=0;actor.Tribes.energy_tick(actor.tribes_state,false,1)
	check(absf(actor.tribes_state.energy-8)<.001,"Non-energy packs recharge at base eight energy per second")
	equip("medium",[3,2,1],"shield");rules.action(1);var before: int=s.hp
	g._damage(1,1,40,"DISC LAUNCHER")
	check(s.hp==before and actor.tribes_state.energy<80,"Shield absorbs damage by draining jet energy")
	actor.tribes_state.energy=1;g._damage(1,1,40,"DISC LAUNCHER")
	check(s.hp<before and actor.tribes_state.energy==0,"Depleted shield spills remaining damage into armour condition")
	equip("light",[3,2,4],"repair");s.hp=50;s.weapon=8
	for i in 10:s.cooldown=0;combat.fire(1)
	check(s.hp==57 and actor.tribes_state.energy==50,"Repair pack self-repairs continuously and competes with jets")
	check(rules.kit(1) and s.hp==87 and not rules.kit(1),"One carried repair kit heals once")
	equip("heavy",[3,2,4,1,7]);s.hp=200
	g._damage(1,1,100,"PLASMA GUN");check(s.hp==160,"Heavy armour uses plasma resistance rather than ablative armour")
	s.hp=200;g._damage(1,1,100,"DISC LAUNCHER",false,Vector3.ZERO,Vector3.ZERO,true);check(s.hp==140,"Explosion route preserves heavy disc resistance")
	var held_weapon: int=s.weapon;rules.cycle_for(1,1)
	check(s.weapon==held_weapon and s.tribes_grenade==10,"Turn-stick selection chooses mine without unequipping gun")
	var snapshot: Dictionary=rules.snapshot();check(rules.valid_snapshot(snapshot),"Equipment/ammo/class snapshot validates")
	var bad: Dictionary=snapshot.duplicate(true);bad.players[1].ammo[2]=9999;check(not rules.valid_snapshot(bad),"Over-cap ammo rejected at replay boundary")
	bad=snapshot.duplicate(true);bad.players[1].guns=[7,7];check(not rules.valid_snapshot(bad),"Duplicate loadout rejected at replay boundary")
	var bank: int=rules.bank(1);var money: int=rules.energy[bank];g.clock+=1
	check(not rules.select_equipment(1,"light",[0,3,2],"energy",true) and s.tribes_class=="heavy" and rules.energy[bank]==money,"Remote base-refit request cannot equip or heal away from base")
	s.cooldown=0;s.weapon=9;actor.velocity=Vector3.ZERO;clear_projectiles();combat.fire(1)
	step_projectiles(2.05);check(g.projectiles.is_empty(),"Hand grenade detonates after its two-second fuse")
	var wheel=preload("res://deathmatch/tribes/buy_wheel.gd").new();wheel.open(s);wheel.select(202,rules,1);wheel.select(400,rules,1)
	check(wheel.armour=="light" and wheel.guns.size()<=3 and not 7 in wheel.guns,"Buy wheel armour change removes incompatible mortar and excess guns")
	var panel=preload("res://deathmatch/ui/defusal_panel.gd").new();g.add_child(panel);panel.setup(rules);panel.toggle();check(panel.tribes and panel.opened and panel.view.rows.size()==8,"Desktop reuses buy wheel with Tribes inventory and team energy")
	panel.close();panel.free()
	g.armory.select("cs16");g._spawn(1);check(not rules.enabled() and g.armory.data(1).name=="GLOCK-18","CS arsenal remains isolated")
	var report:={"checks":checks,"failures":failures};FileAccess.open("res://test-results/tribes-arsenal/mechanics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("TRIBES_ARSENAL ",JSON.stringify(report))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
