extends SceneTree
var g
var de
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func live_round():
	g.intermission=0;de.begin_round();de.credit(1,10000);de.credit(99,10000)
	de.buy(1,6);de.buy(99,5);g.clock=de.phase_end;de.tick(0)
	de.carrier=1;de.held=true;de.arm_index=3;de.armed_until=g.clock+4
	g.fighters[1].position=de.sites[0]+Vector3(0,0,.8)
	g.fighters[99].position=g.fighters[1].position+Vector3(.6,0,0)
	for id in [1,99,-1]:g.players[id].invulnerable=0;g.players[id].input_blocked=false
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Bomb recovery",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);de=g.match_mode.defusal
	g._add_player(99,"Surviving terrorist");g.players[99].team=0
	await physics_frame;await physics_frame
	live_round();g._damage(1,-1,1000,"USP",true)
	check(g.players[1].dead and de.carrier==0 and not de.held and not de.planted,"Actual carrier death drops an unplanted bomb")
	check(de.arm_index==0 and de.armed_until==0,"Carrier death clears partial arming")
	check(g.dropped_weapons.entries.values().any(func(p):return p.available and p.item==6),"Death also drops the equipped primary at the bomb")
	check(de.nearby_weapon(99)>=0 and de.can_recover_bomb(99),"Survivor can reach both the bomb and the overlapping gun")
	check(de.hint(99)=="USE / GRAB · RECOVER BOMB","Recovery hint takes priority over weapon swapping")
	de.utility.state(99).counts[0]=1;de.utility.equip(99,0)
	g._use_for(99)
	check(de.carrier==99 and not de.held and g.players[99].weapon==5 and not g.players[99].owned.has(6),"Use attaches the recovered bomb to the chest without swapping the gun")
	check(de.utility.selected(99)<0 and de.utility.state(99).counts[0]==1,"Recovery holsters utility without consuming it")
	check(not de.recover_bomb(-2) and de.carrier==99,"A second attacker cannot steal a carried bomb")
	g.fighters[99].position=de.sites[0]+Vector3(0,0,.8);g.players[99].yaw=0.0
	# The synthetic site overlaps the death position; leave the recovered gun
	# behind before testing a deliberate second Use to equip the chest slot.
	for entry in g.dropped_weapons.entries.values():entry.available=false
	de.use(99)
	check(de.held,"Carrier deliberately equips the recovered bomb from its slot")
	for i in 4:g.clock+=.2;de.digit(99,de.arm_code[de.arm_index])
	check(de.plant(99,0) and de.planted,"The surviving terrorist can arm and plant the recovered bomb")
	check(not de.recover_bomb(99),"Planted bombs cannot be picked back up")
	live_round();g._damage(1,-1,1000,"USP",true)
	var floor_position: Vector3=de.bomb_position-Vector3.UP*.2
	g.fighters[-1].position=floor_position
	check(not de.recover_bomb(-1),"Counter-terrorists cannot recover the bomb")
	g.fighters[1].position=floor_position;check(not de.recover_bomb(1),"Dead carrier cannot reclaim the bomb")
	g.players[99].spectator=true;check(not de.recover_bomb(99),"Spectators cannot recover the bomb");g.players[99].spectator=false
	g.fighters[99].position=floor_position+Vector3(4,0,0);check(not de.recover_bomb(99),"Recovery rejects an out-of-range terrorist")
	g.fighters[99].position=floor_position+Vector3(.7,0,0)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.1,2,2);shape.shape=box;wall.add_child(shape);g.add_child(wall);wall.position=floor_position+Vector3(.35,.5,0)
	await physics_frame;await physics_frame
	check(not de.recover_bomb(99),"Recovery rejects a bomb behind a wall");wall.free()
	de.phase="post";check(not de.recover_bomb(99),"Recovery is unavailable after the round")
	de.phase="live";g.fighters[-2].position=floor_position;de.bot_input(-2)
	check(de.carrier==-2,"Another terrorist bot recovers the death drop")
	de.drop(-2);de.attacking=1;g.fighters[-1].position=de.bomb_position-Vector3.UP*.2
	check(de.recover_bomb(-1) and de.carrier==-1,"Recovery follows the terrorist role after the side swap")
	de.attacking=0;live_round();g._damage(1,-1,1000,"USP",true)
	g.fighters[99].position=de.bomb_position+Vector3(0,-.2,.35);g.players[99].yaw=0.0
	var pose: Dictionary=preload("res://deathmatch/vr/poses.gd").neutral();pose.head.origin.y=.95
	pose.weapon=Transform3D(Basis.IDENTITY,Vector3(0,.2,-.35));pose.right=pose.weapon
	g.clock+=.2
	g._accept_input(99,{"seq":1,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":5,"slow":false,"respawn":false,"xr":pose,"de_grip":true})
	de.sample_player(99)
	check(not g.players[99].xr.is_empty() and de.carrier==99 and not de.held,"A tracked-hand grip recovers the dead carrier's bomb in VR")
	for attacking in [0,1]:
		de.drop(99);de.attacking=attacking;g.players[99].team=1-attacking;g.players[-1].team=1-attacking
		var dropped: Vector3=de.bomb_position
		g.fighters[99].position=dropped+Vector3(0,-.2,.35);g.fighters[-1].position=dropped-Vector3.UP*.2
		check(not de.can_recover_bomb(99) and not de.recover_bomb(99),"CT authority rejects recovery with attacking team "+str(attacking))
		g._use_for(99)
		check(de.carrier==0 and de.bomb_position==dropped,"CT Use cannot take the dropped bomb, attacking team "+str(attacking))
		de.input_edges.erase(99);g.players[99].de_grip=true;g.players[99].last_input=g.clock
		de.sample_player(99)
		check(de.carrier==0 and de.bomb_position==dropped,"CT tracked-hand grip cannot take the bomb, attacking team "+str(attacking))
		de.bot_input(-1)
		check(de.carrier==0 and de.bomb_position==dropped,"CT bot cannot take the bomb, attacking team "+str(attacking))
		g.players[99].team=attacking
		check(de.recover_bomb(99),"The same in-range player can recover after becoming T, attacking team "+str(attacking))
	var result:={"checks":checks,"passed":failures.is_empty(),"failures":failures}
	FileAccess.open("res://test-results/defusal/bomb-recovery.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_BOMB_RECOVERY_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();await process_frame;quit(0 if failures.is_empty() else 1)
