extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Magazines=preload("res://deathmatch/conquest/classes/magazines.gd")
class TestArena extends Base:
	func _load_map(_id:String)->bool:spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";return true
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run()->void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Supply",28783,100,10,false)
	for id in [2,3]:game._add_player(id,"Supply %d"%id)
	game.classes.choose(2,"technician");game._spawn(2);game.classes.choose(3,"medic");game._spawn(3)
	for id in game.players:game.players[id].team=0
	var rules=game.classes
	for id in [2,3]:
		check(rules.level(id)==0 and rules.dispenser_limit(id)==1,"Starting specialist has one box")
		check(rules.deploy(id,Vector3.ZERO),"Initial specialist deployment")
		var first:int=rules.next_dispenser
		game.clock+=29.999;check(not rules.deploy(id,Vector3.ONE) and rules.dispensers.has(first),"Early deployment rejected without destroying old box")
		game.clock+=.001;check(rules.deploy(id,Vector3.ONE) and not rules.dispensers.has(first),"Deployment at 30 seconds replaces oldest at one-box limit")
		rules.award(id,4999);check(rules.level(id)==9 and rules.dispenser_limit(id)==1,"One box through level nine")
		rules.award(id,1);check(rules.level(id)==10 and rules.dispenser_limit(id)==2,"Second box unlocks at 5000 class XP")
		game.clock+=30;check(rules.deploy(id,Vector3(2,0,0)),"Second deployment fits level-ten limit")
		var owned:Array=rules.dispensers.keys().filter(func(key):return rules.dispensers[key].owner==id);owned.sort();var oldest:int=owned[0]
		game.clock+=30;check(rules.deploy(id,Vector3(3,0,0)) and not rules.dispensers.has(oldest),"Oldest of two is destroyed on replacement")
		rules.award(id,2499);check(rules.dispenser_limit(id)==2,"No third box at 7499 XP")
		rules.award(id,1);game.clock+=30;check(rules.dispenser_limit(id)==3 and rules.deploy(id,Vector3(4,0,0)),"Third box unlocks at 7500 class XP")
		rules.award(id,5000);check(rules.dispenser_limit(id)==3,"Three-box hard cap at higher levels")
	game.clock+=30;rules.deploy(2,Vector3.ZERO);var key:int=rules.next_dispenser;var tech:Dictionary=game.players[2]
	tech.ammo[2]=0
	check(rules.transfer(key,2,299)==0 and tech.ammo[2]==0,"A launcher pack cannot be supplied for fewer than 300 units")
	check(rules.transfer(key,2,300)==300 and tech.ammo[2]==3 and rules.dispensers[key].remaining==700,"300 units purchase exactly one three-charge pack")
	check(rules.transfer(key,2,600)==600 and tech.ammo[2]==9 and rules.dispensers[key].remaining==100,"Two further packs cost 600 units")
	tech.ammo[2]=8;check(rules.transfer(key,2,1000)==0 and tech.ammo[2]==8,"No partial pack top-off")
	tech.ammo[2]=6;check(rules.transfer(key,2,1000)==0,"Box with 100 units cannot grant a 300-unit pack")
	game.grenades.state(1).counts[0]=0
	check(rules.transfer(key,1,99)==0,"Grenade costs at least 100 units")
	check(rules.transfer(key,1,100)==100 and game.grenades.state(1).counts[0]==1 and not rules.dispensers.has(key),"Shocktrooper grenade costs 100 and exhausted box is removed")
	game.clock+=30;rules.deploy(2,Vector3.ZERO);key=rules.next_dispenser
	check(rules.transfer(key,1,100)==0,"A full grenade inventory cannot drain a box")
	game.players[1].team=1;game.grenades.state(1).counts[0]=0;check(rules.transfer(key,1,100)==0,"Enemy cannot draw supplies");game.players[1].team=0
	game.fighters[2].position=Vector3.ZERO;game.fighters[1].position=Vector3(100,0,0);game.fighters[3].position=Vector3(100,0,0)
	rules.dispensers={key:rules.dispensers[key]}
	tech.ammo[2]=6
	for tick in 149:game.tick_class_tools(.1)
	check(tech.ammo[2]==6,"Continuous contact accrues pack credit without issuing partial charges")
	game.tick_class_tools(.1);check(tech.ammo[2]==9 and rules.dispensers[key].remaining==700,"Live transfer loop supplies full pack after 300 units accrue")
	for w in [5,11]:
		var d:Dictionary=game.armory.data(w)
		check(is_equal_approx(d.reload,3*game.armory.data(4).reload),"Launcher pack reload lasts three magazine reloads")
		var p:Dictionary=Magazines.Reload.make(0);p.weapon=12;p.mag=false
		Magazines.pack_delay(p,true,0,0,0,d.reload);p.mag=true;p.ready=true
		Magazines.pack_delay(p,false,0,3,1,d.reload);check(not p.ready,"Fast VR seating cannot bypass pack reload time")
		Magazines.Reload.interrupt(p);Magazines.pack_delay(p,true,3,3,6.599,d.reload);check(not p.ready,"VR holster/tracking interruption cannot bypass timer")
		Magazines.pack_delay(p,true,3,3,d.reload,d.reload);check(p.ready and not p.has("pack_until"),"VR pack becomes ready exactly at deadline")
	# A full recipient cannot bank idle healing credit for an instant future heal.
	game.clock+=30;rules.deploy(3,Vector3.ZERO);var health_key:int=rules.next_dispenser
	rules.dispensers={health_key:rules.dispensers[health_key]};game.supply_budgets.clear()
	game.fighters[2].position=Vector3(100,0,0);game.fighters[3].position=Vector3.ZERO
	game.players[3].hp=100
	for tick in 200:game.tick_class_tools(.1)
	game.players[3].hp=50;game.tick_class_tools(.1)
	check(game.players[3].hp==52,"Full-health players cannot bank idle supply credit for burst healing")
	var mags=game.variant_combat.magazines;tech.weapon=5;tech.last_input=game.clock;tech.input_blocked=false;tech.vr_device=false
	var c:Dictionary=mags.state(2);var p:Dictionary=Magazines.Reload.make(3);p.weapon=12;p["pack_until"]=game.clock+5;p.ready=false;c.physical[5]=p;c.clips[5]=3
	check(not mags.tick(2),"Switching from VR to desktop cannot bypass an arming pack")
	check(game.armory.data(11).cycle_reload==2.7,"Guided launcher charge cycling retains its existing timing")
	print("CQ_SUPPLY_BALANCE_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
