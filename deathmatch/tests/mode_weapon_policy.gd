extends SceneTree
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const Runtime=preload("res://deathmatch/maps/runtime.gd")
var failures: Array=[]
var checks:=0
var game
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Mode policy",0,100,60,true,"tf","ut99")
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	game.set_physics_process(false);game.set_process(false)
	check(game.active and game.armory.kind=="quake","TF host forces Quake over requested UT99")
	check(not game.pickups.is_empty() and game.pickups.all(func(p):return p.kind!="weapon"),"TF map weapon caches become collectable class ammunition")
	for role in game.match_mode.fortress.CLASSES:
		game.players[1].tf_next=role;game.match_mode.fortress.spawn(1)
		check(game.players[1].owned.all(func(w):return game.armory.valid(w)),"TF "+role+" has valid class weapons")
	check(game.match_mode.fortress.weapon_data(1,7).ammo==0,"Non-pyro super nailgun uses nails")
	game.players[1].tf_class="pyro"
	check(game.match_mode.fortress.weapon_data(1,7).ammo==3,"Pyro flamethrower uses cells")
	game.armory.select("doom")
	check(game.armory.kind=="quake","Direct selection cannot bypass TF restriction")
	game.match_mode.kind="as"
	check(game.armory.kind=="ut99","Mode switch automatically selects UT99")
	for map_id in ["as_hislop","as_frigate"]:
		check(game._load_map(map_id),"Load "+map_id)
		check(game.pickups.size()==(62 if map_id=="as_hislop" else 40),"Reference pickup total on "+map_id)
		check(game.pickups.filter(func(p):return p.kind=="weapon").size()==(18 if map_id=="as_hislop" else 10),"Reference weapon count on "+map_id)
		check(game.pickups.filter(func(p):return p.kind=="weapon").all(func(p):return game.armory.valid(p.item) and p.item not in [8,11]),"No unlisted Redeemer or translocator on "+map_id)
		check(game.armory.pickup_bundle(3).is_empty() and game.armory.pickup_bundle(5).is_empty(),"AS weapons are separate, without bonus guns")
	var s: Dictionary=game.players[1]
	s.dead=false;s.spectator=false;s.hp=1;s.ammo=[0,0,0,0];s.owned=[0,2];s.armor=0
	# Isolate a single cache from adjacent supplies and test normal authoritative collection.
	var p: Dictionary=game.pickups.filter(func(row):return row.kind=="weapon" and row.item==9)[0]
	for row in game.pickups:row.available=false
	p.available=true;game.fighters[1].position=p.position;game._collect(1)
	check(s.owned.has(9) and not s.owned.has(5) and s.ammo[0]==8,"Sniper pickup grants only sniper and its initial ammo")
	check(not p.available and is_equal_approx(p.respawn,game.clock+15),"AS weapon disappears until its halved respawn")
	s.ammo[0]=0;game._collect(1)
	check(s.ammo[0]==0,"Collected AS weapon cannot be collected again before respawn")
	game.clock=p.respawn;game._respawn_pickups();game._collect(1)
	check(s.ammo[0]==8 and not p.available,"Respawned AS weapon replenishes ammunition for an owned gun")
	p=game.pickups.filter(func(row):return row.kind=="armor" and row.get("amount",0)==150)[0]
	p.available=true;game.fighters[1].position=p.position;game._collect(1)
	check(s.armor==150,"Shield pickup grants 150 armour")
	var previous: String=game.current_map
	game.match_mode.kind="tf";game._load_map(previous)
	check(game.armory.kind=="quake" and game.pickups.all(func(row):return row.kind!="weapon"),"Same BSP reload remaps AS weapons to TF ammo")
	game.match_mode.kind="dm"
	check(game.armory.kind=="doom","Unrestricted mode restores the requested server preset")
	game.votes.allowed_modes=game.match_mode.NAMES.keys()
	var rcon=load("res://deathmatch/server/rcon.gd").new();rcon.game=game
	check(rcon.execute("match as as_frigate quake").has("error"),"RCON rejects a contradictory Assault loadout")
	check(rcon.execute("match tf tf_pressureworks ut99").has("error"),"RCON rejects a contradictory TF loadout")
	rcon.change_match("as","as_hislop","ut99")
	check(game.current_map=="as_hislop" and game.armory.kind=="ut99","RCON transition loads Assault with its required arsenal")
	game.votes.change_mode("tf")
	check(game.match_mode.kind=="tf" and game.armory.kind=="quake","Mode vote transition applies Quake")
	game.votes.change_match("as|as_frigate")
	check(game.current_map=="as_frigate" and game.armory.kind=="ut99","Combined mode/map vote applies UT99")
	rcon.free()
	game.match_mode.kind="as";game.armory.select("quake")
	check(game.armory.kind=="ut99","Direct selection cannot bypass AS restriction")
	game.disconnect_game();await process_frame
	game.selected_map="as_frigate";game.start_host("AS default",0,100,60,true,"as")
	check(game.active and game.armory.kind=="ut99","AS host with default arguments uses UT99")
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("MODE_WEAPON_POLICY_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
