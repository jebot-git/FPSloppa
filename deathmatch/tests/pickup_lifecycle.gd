extends SceneTree
var game
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="as_frigate";game.start_host("Pickup lifecycle",0,20,10,true,"as")
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	game.set_process(false);game.set_physics_process(false)
	check(game.active and game.match_mode.kind=="as","Assault host starts with authored pickups")
	if not game.active:finish();return
	for map_id in ["as_frigate","as_hislop"]:
		check(game._load_map(map_id),"Load "+map_id)
		for p in game.pickups:
			for other in game.pickups:other.available=false;other.respawn=INF
			# Lightweight scene nodes exercise the same visibility snapshot path
			# in headless tests without allocating art or an audio device.
			p.node=Node3D.new();game.get_node("Map").add_child(p.node)
			p.available=true;p.respawn=0
			var s: Dictionary=game.players[1]
			s.hp=1;s.armor=0;s.ammo=[0,0,0,0];s.owned=[2];s.dead=false;s.spectator=false
			game.fighters[1].position=p.position
			game._collect(1)
			var label: String=map_id+" "+p.kind+" "+str(p.item)+" "+str(p.position)
			var delay:=15 if p.kind=="weapon" else 30
			check(not p.available and is_equal_approx(p.respawn,game.clock+delay),label+": consumed with "+str(delay)+"-second deadline")
			game._send_snapshot()
			check(not p.node.visible,label+": collected model disappears on snapshot")
			var after: Array=[s.hp,s.armor,s.ammo.duplicate()]
			game._collect(1)
			check(after==[s.hp,s.armor,s.ammo],label+": cannot collect twice while unavailable")
			var competitor: Dictionary=game.players[-1]
			competitor.hp=1;competitor.armor=0;competitor.ammo=[0,0,0,0];competitor.owned=[2];competitor.dead=false;competitor.spectator=false
			game.fighters[-1].position=p.position;game._collect(-1)
			check(competitor.hp==1 and competitor.armor==0 and competitor.ammo==[0,0,0,0] and competitor.owned==[2],label+": contested pickup is awarded only once")
			game.clock=p.respawn-.01;game._respawn_pickups();game._send_snapshot()
			check(not p.available and not p.node.visible,label+": remains absent before deadline")
			game.clock=p.respawn;game._respawn_pickups();game._send_snapshot()
			check(p.available and p.node.visible,label+": respawns at deadline and becomes visible")
			if p.kind=="weapon":
				s.ammo=[0,0,0,0];game._collect(1)
				var pool: int=game.armory.data(p.item).ammo
				check(not p.available and s.ammo[pool]==p.amount,label+": respawned owned weapon replenishes ammo")
				game.clock=p.respawn;game._respawn_pickups()
			# No benefit means no collection or timer reset.
			s.hp=200;s.armor=200;s.ammo=game.armory.max_ammo().duplicate()
			game._collect(1)
			check(p.available,label+": full player leaves supply available")
		# A new assault leg restores every consumed item immediately.
		for p in game.pickups:p.available=false;p.respawn=game.clock+30
		game.match_mode.assault.next_leg();game._send_snapshot()
		check(game.pickups.all(func(p):return p.available and p.respawn==0 and (not is_instance_valid(p.node) or p.node.visible)),map_id+": role swap restores all pickups and clears timers")
	var bot=load("res://deathmatch/bots.gd").new();bot.game=game
	var weapon: Dictionary=game.pickups.filter(func(p):return p.kind=="weapon")[0]
	game.players[1].owned=[weapon.item];game.players[1].ammo=[0,0,0,0]
	check(bot.item_value(1,weapon)>0,"AS bots seek respawned owned weapons when they need ammo")
	game.players[1].ammo=game.armory.max_ammo().duplicate()
	check(bot.item_value(1,weapon)==0,"AS bots leave owned weapons when ammo is full")
	bot.free()
	for p in game.pickups:p.available=false;p.respawn=INF
	weapon.item=8;weapon.amount=10;weapon.available=true;weapon.respawn=0
	game.players[1].owned=[2];game.players[1].ammo=[0,0,0,0];game.fighters[1].position=weapon.position
	game._collect(1)
	check(not weapon.available and is_equal_approx(weapon.respawn,game.clock+30),"AS Redeemer uses halved 30-second power-weapon timer")
	game.clock=weapon.respawn-.01;game._respawn_pickups()
	check(not weapon.available,"Power weapon cannot respawn early")
	game.clock=weapon.respawn;game._respawn_pickups()
	check(weapon.available,"Power weapon respawns at its deadline")
	game.match_mode.kind="dm"
	for item in [3,8]:
		weapon.item=item;weapon.available=true;weapon.respawn=0
		game.players[1].owned=[2];game.players[1].ammo=[0,0,0,0]
		game._collect(1)
		check(not weapon.available and is_equal_approx(weapon.respawn,game.clock+(60 if item==8 else 30)),"Non-AS weapon "+str(item)+" retains its normal respawn timer")
	finish()
func finish() -> void:
	print("PICKUP_LIFECYCLE_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
