extends SceneTree
const Shop=preload("res://deathmatch/counterstrike/buy_wheel.gd")
const Arsenal=preload("res://deathmatch/counterstrike/arsenal.gd")
var checks:=0
var failures: Array=[]
var g
var de
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func empty_inventory(id: int):
	g.players[id].owned=[0];g.players[id].weapon=0;g.players[id].ammo=[0,0,0,0];g.variant_combat.cs.cancel(id);de.account(id).cash=16000
func check_role(id: int,t: bool):
	var expected: Array=["GLOCK-18","USP","M3 SUPER 90","XM1014","MP5 NAVY","M249","AWP","DESERT EAGLE","P90","AK-47" if t else "M4A1"]
	var offers: Array=de.offers(id).filter(func(row):return row.id<12).map(func(row):return row.name)
	expected.sort();offers.sort();check(offers==expected,"Exact CS 1.6 gun menu for "+("T" if t else "CT"))
	for slot in range(1,Arsenal.NAMES.size()):
		empty_inventory(id)
		var permitted: bool=expected.has(Arsenal.NAMES[slot])
		var menu: Array=Shop.rows(de,id,200 if slot in [1,2,10] else 201)
		check(menu.any(func(row):return row.id==slot)==permitted,"Wheel filters "+Arsenal.NAMES[slot]+" for "+("T" if t else "CT"))
		var bought: bool=de.buy(id,slot)
		check(bought==permitted and g.players[id].owned.has(slot)==permitted and de.account(id).cash==(16000-de.PRICES[slot] if permitted else 16000),"Authority validates ownership/payment for "+Arsenal.NAMES[slot])
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Team shops",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0)
	check(g.players[1].owned==[0,1] and g.players[-1].owned==[0,2],"Starting pistols retain T Glock and CT USP")
	check_role(1,true);check_role(-1,false)
	empty_inventory(1);check(not de.request(1,"buy",7,g.map_epoch,de.round_id,g.players[1].serial,100),"Direct T purchase request cannot bypass M4 restriction")
	empty_inventory(-1);check(not de.request(-1,"buy",6,g.map_epoch,de.round_id,g.players[-1].serial,100),"Direct CT purchase request cannot bypass AK restriction")
	check(not de.offer_allowed(1,102) and de.offer_allowed(-1,102),"Only CT shop offers defuse cutters")
	# Purchase restrictions do not prohibit recovering enemy guns.
	g.clock=de.phase_end;de.tick(0)
	for pair in [[1,7],[-1,6]]:
		var id: int=pair[0];var weapon: int=pair[1];empty_inventory(id)
		g.dropped_weapons.clear();g.dropped_weapons.next_id+=1
		g.dropped_weapons.add(g.dropped_weapons.next_id,g.fighters[id].position,weapon,30);g._use_for(id)
		check(g.players[id].owned.has(weapon),"Either team can recover enemy "+Arsenal.NAMES[weapon])
	de.round_id=de.win_limit-1;de.begin_round()
	check(g.players[1].owned==[0,2] and g.players[-1].owned==[0,1],"Halftime swaps starting pistols with roles")
	check_role(1,false);check_role(-1,true)
	check(de.offer_allowed(1,102) and not de.offer_allowed(-1,102),"Kit access switches with CT role at halftime")
	for value in [-1,0,12,999]:check(not Arsenal.can_purchase(value,0) and not Arsenal.can_purchase(value,1),"Knife/unknown slots cannot silently enter the shop: "+str(value))
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/distribution.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_DISTRIBUTION_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
