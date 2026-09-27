extends SceneTree
var checks:=0
var failures: Array=[]
var g
var de
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func drop(w: int,amount: int,offset:=Vector3.ZERO) -> int:
	g.dropped_weapons.next_id+=1;var key: int=g.dropped_weapons.next_id
	g.dropped_weapons.add(key,g.fighters[1].position+offset,w,amount);return key
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Use pickups",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0);de.credit(1,10000);de.buy(1,6)
	var s: Dictionary=g.players[1];var c: Dictionary=g.variant_combat.cs.state(1);var ammo: int=g.armory.data(6).ammo
	s.ammo[ammo]=60;c.clips[6]=9
	var incoming:=drop(7,25)
	g._collect(1);check(s.owned.has(6) and not s.owned.has(7) and g.dropped_weapons.entries[incoming].available,"Walking over DE weapon cannot collect it")
	g._use_for(1)
	check(s.owned.has(7) and not s.owned.has(6) and s.owned.has(1) and s.owned.has(0),"Use swaps primary while preserving sidearm and knife")
	check(not g.dropped_weapons.entries[incoming].available and g.dropped_weapons.entries.values().any(func(p):return p.available and p.item==6 and p.amount==9),"Previous slot weapon drops with its loaded rounds")
	check(s.ammo[ammo]==76 and c.clips[7]==25,"Swap preserves ammunition accounting and incoming magazine")
	g._collect(1);check(s.weapon==7 and not s.owned.has(6),"Dropped old weapon cannot automatically swap back")
	g._use_for(1);check(s.weapon==7,"Held/repeated Use is debounced")
	g.dropped_weapons.clear();g.clock+=.3;c.clips[1]=5;var secondary:=drop(10,7);g._use_for(1)
	check(s.owned.has(10) and not s.owned.has(1) and s.owned.has(7),"Use swaps sidearm without dropping primary")
	check(g.dropped_weapons.entries.values().any(func(p):return p.available and p.item==1 and p.amount==5),"Starting pistol also drops on an intentional swap")
	g.dropped_weapons.clear();g.clock+=.3;c.clips[10]=3;drop(10,6);g._use_for(1)
	check(c.clips[10]==6 and g.dropped_weapons.entries.values().any(func(p):return p.available and p.item==10 and p.amount==3),"Same model swaps the physical gun and magazine too")
	g.dropped_weapons.clear();g.clock+=.3;drop(9,10,Vector3(3,0,0));g._use_for(1)
	check(not s.owned.has(9),"Use cannot take a distant gun")
	g.dropped_weapons.clear();g.clock+=.3;drop(9,10);s.dead=true;g._use_for(1)
	check(not s.owned.has(9),"Dead spectators cannot pick up guns")
	s.dead=false;de.phase="post";g._use_for(1);check(not s.owned.has(9),"Post-round pickups are rejected")
	de.phase="live";de.carrier=1;de.held=true;g._use_for(1);check(not s.owned.has(9),"Held bomb interaction cannot swap guns")
	de.held=false;g.clock+=.3;g._use_for(1);check(s.owned.has(9) and s.owned.has(10),"Live Use pickup shares the preparation swap path")
	g.dropped_weapons.clear();de.phase="live";de.carrier=0
	drop(5,30,Vector3(.5,0,0));var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.1,2,2);shape.shape=box;wall.add_child(shape);g.add_child(wall);wall.position=g.fighters[1].position+Vector3(.25,.6,0)
	await physics_frame;await physics_frame
	g.clock+=.3;g._use_for(1);check(not s.owned.has(5),"Use cannot collect through a wall")
	wall.free();g.match_mode.kind="dm";g.dropped_weapons.clear();drop(5,30);g._collect(1)
	check(s.owned.has(5),"Arena modes retain automatic pickups")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/pickups.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_PICKUP_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();await process_frame;quit(0 if failures.is_empty() else 1)
