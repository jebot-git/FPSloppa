extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
var g
var de
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fresh():
	g.intermission=0;g.match_mode.reset();g.clock+=100
	for id in g.players:g._spawn(id)
	de.tick(0)
func live():g.clock=de.phase_end;de.tick(0)
func arm(id: int,site: int=0):
	g.fighters[id].position=de.sites[site]+Vector3(0,0,.8);de.carrier=id;de.held=true
	for i in 4:g.clock+=.2;de.digit(id,de.arm_code[de.arm_index])
func run():
	var cfg: Dictionary=Config.parse('set sv_gametype "de"\nset sv_weapon_rules "doom"')
	check(not cfg.has("error") and cfg.values.sv_weapon_rules=="cs16" and cfg.values.map=="de_dust2_rebuilt" and cfg.values.maps==preload("res://deathmatch/modes/defusal_maps.gd").IDS,"Server DE config forces CS loadout and defaults to classic map rotation")
	check(Config.parse('set sv_de_prepare "0"').has("error") and Config.parse('set sv_de_bombtime "999"').has("error"),"Invalid DE timers rejected")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="de_dust2_rebuilt"
	g.start_host("Bomb test",0,20,10,true,"de","doom")
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false);de=g.match_mode.defusal
	await physics_frame;await physics_frame
	check(g.active and g.current_map==de.MAP and g.armory.effective()=="cs16","Practice starts DE on Dust2 with forced CS weapons")
	check(not g._load_map("qsrc_dm1"),"Unsupported map cannot be loaded as DE")
	check(g.maps_for_mode("de").size()==5 and g.maps_for_mode("de").has(de.MAP),"Host/votes expose all five supported DE maps")
	for role in 2:
		for p in de.starts[role]:
			var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.3,1))
			check(not hit.is_empty(),"Role %d spawn has floor %s"%[role,p])
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.65;query.shape=capsule;query.collision_mask=1;query.transform.origin=p+Vector3.UP*.83
			check(g.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Role %d spawn has a clear standing capsule %s"%[role,p])
	for p in de.sites:
		var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.3,1))
		check(not hit.is_empty(),"Bomb site uses authored floor mark "+str(p))
	fresh()
	check(de.phase=="prepare" and de.round_id==1,"Both teams start preparation round")
	check(g.players[1].owned==[0,1] and g.players[-1].owned==[0,2],"T starts Glock; CT starts USP; both retain knife")
	check(de.account(1).cash==800 and de.account(-1).cash==800,"Opening economy grants $800")
	check(g.pickups.all(func(p):return not g.jetpacks.allowed(p)),"DE suppresses all arena supplies and jetpacks")
	var s: Dictionary=g.players[1];var a=g.fighters[1];var before: Vector3=a.position
	s.move=Vector2.ONE;s.fire=true;s.last_input=g.clock;g._server_tick(.1)
	check(a.position==before and s.hp==100,"Preparation freezes movement and weapons")
	g._damage(1,-1,1000,"USP");check(not s.dead,"Preparation is protected from combat")
	var cs=g.variant_combat.cs;var c: Dictionary=cs.state(1);c.clips[s.weapon]=1;s.cooldown=0.0;s.reload=true;s.last_input=g.clock
	g._server_tick(.1);check(c.reloading==s.weapon,"Desktop can reload a surviving gun during frozen preparation")
	g.clock=c.reload_at+.01;s.last_input=g.clock;s.reload=false;g._server_tick(.1)
	check(c.clips[s.weapon]==20 and s.ammo[0]==60,"Preparation reload fills magazine without creating ammunition")
	check(de.buy(1,10) and de.account(1).cash==150 and s.owned==[0,10],"Buy charges exact price and replaces secondary")
	check(not de.buy(1,10) and not de.buy(1,6) and de.account(1).cash==150,"Duplicate and unaffordable purchases cannot debit money")
	de.credit(1,99999);check(de.account(1).cash==16000,"Money capped at $16000")
	check(not de.buy(1,7) and not de.buy(1,102),"Attackers cannot purchase CT M4/cutters")
	check(de.buy(1,6) and de.buy(1,5) and s.owned.count(5)==1 and not s.owned.has(6),"Primary purchases replace only the primary slot")
	var inventory: Array=s.owned.duplicate();g._collect(1);check(s.owned==inventory,"Replacement drops cannot auto-swap back or duplicate inventory")
	check(de.buy(-1,102) and de.account(-1).kit,"CT can buy cutters for $200")
	var money: int=de.account(-1).cash;check(not de.buy(-1,102) and de.account(-1).cash==money,"Duplicate cutters do not charge again")
	check(not de.request(1,"buy",3,g.map_epoch-1,de.round_id,s.serial,1),"Reject stale map purchase")
	check(not de.request(1,"buy",3,g.map_epoch,de.round_id-1,s.serial,2),"Reject stale round purchase")
	check(not de.request(1,"buy",3,g.map_epoch,de.round_id,s.serial-1,3),"Reject stale life purchase")
	check(de.request(1,"buy",3,g.map_epoch,de.round_id,s.serial,4),"Current life purchase accepted")
	money=de.account(1).cash;g.clock+=.2
	check(not de.request(1,"buy",4,g.map_epoch,de.round_id,s.serial,4) and de.account(1).cash==money,"Reliable duplicate request cannot double-spend")
	live();check(de.phase=="live" and not de.buy(1,4),"Preparation expiry closes purchase authority")
	check(not de.plant(1,0),"Unarmed bomb cannot plant")
	arm(1);check(de.arm_index==4 and de.armed_until>g.clock,"Four correct digits arm bomb")
	g.clock=de.armed_until;de.tick(0);check(de.arm_index==0 and de.armed_until==0,"Five-second placement window expires")
	de.held=true;g.clock+=.2;de.digit(1,(int(de.arm_code[0])+1)%10)
	check(de.arm_index==0,"Incorrect keypad entry resets arming")
	arm(1);check(de.plant(1,0) and de.planted and de.carrier==0 and de.planted_site==0,"Armed carrier plants only at a valid site")
	check(is_equal_approx(de.fuse_end-g.clock,45),"CS bomb fuse is 45 seconds")
	check(not de.digit(1,0),"Attackers cannot defuse their planted bomb")
	g._damage(1,1,1000,"Test",true);g._damage(-2,-2,1000,"Test",true);de.tick(0)
	check(de.phase=="live","All attackers dead still requires bomb defusal")
	var serial: int=s.serial;s.want_respawn=true;g.clock+=3.1;g._server_tick(.1)
	check(s.dead and s.serial==serial,"Dead players cannot auto-respawn or press to respawn")
	g.fighters[-1].position=de.bomb_position+Vector3(0,0,.7)
	check(de.use(-1) and de.account(-1).tool,"CT equips purchased cutters near the bomb")
	for wire in 3:g.clock+=.2;de.cut(-1,wire)
	check(de.phase=="post" and g.match_mode.scores==[0,1] and de.message=="BOMB DEFUSED","Three distinct wire cuts win for CT")
	var rewards: int=de.account(-1).cash;de.finish_round(1,"BOMB DEFUSED")
	check(g.match_mode.scores==[0,1] and de.account(-1).cash==rewards,"Round result and money are awarded once")
	g.clock=de.phase_end;de.tick(0)
	check(de.phase=="prepare" and de.round_id==2 and not s.dead and not de.account(1).kit,"Next round revives dead players with fresh loadout")
	check(de.account(-1).kit,"Survivor retains purchased kit")
	live();arm(1,1);de.plant(1,1)
	g.fighters[-1].position=de.bomb_position+Vector3(0,0,.7);de.account(-1).tool=false
	for i in 8:g.clock+=.2;de.digit(-1,de.defuse_code[de.defuse_index])
	check(de.phase=="post" and g.match_mode.scores==[0,2],"Eight correct digits defuse without cutters at site B")
	fresh();live();arm(1);de.plant(1,0);g.clock=de.fuse_end;de.tick(0)
	check(de.phase=="post" and g.match_mode.scores==[1,0] and de.message=="BOMB EXPLODED","Fuse deadline wins exactly once for T")
	check(not de.digit(-1,0) and not de.cut(-1,0),"Defusal cannot complete after explosion deadline")
	fresh();live();var starting_cash: int=de.account(1).cash;g.clock=de.phase_end;de.tick(0)
	check(de.message=="TIME EXPIRED" and g.match_mode.scores==[0,1],"Unplanted round timeout wins for CT")
	check(de.account(1).cash==starting_cash,"Surviving attackers receive no timeout loss bonus")
	fresh();live();g._damage(-1,-1,1000,"Test",true);g._damage(-3,-3,1000,"Test",true);de.tick(0)
	check(de.message=="DEFENDERS ELIMINATED" and g.match_mode.scores==[1,0],"Eliminating defenders wins for T")
	fresh();live();de.carrier=1;de.held=true;de.drop(1)
	check(de.carrier==0 and not de.held and de.bomb_position.is_finite(),"Death/disconnect drops a recoverable unarmed bomb")
	g.fighters[-2].position=de.bomb_position-Vector3.UP*.2
	check(de.use(-2) and de.carrier==-2,"Another attacker can recover dropped bomb")
	g._add_player(99,"Late player")
	check(g.players[99].dead and g.players[99].hp==0,"Late live join waits until next round")
	check(not g.votes.change_team(1,1,true),"Mid-round team switch cannot grant another life")
	fresh();de.round_id=de.win_limit-1;de.account(1).cash=9999;var attacking: int=de.attacking;de.begin_round()
	check(de.attacking==1-attacking and de.account(1).cash==800 and g.players[1].owned==[0,2],"Halftime swaps roles and resets pistol economy")
	# Preparation cancellation must neither award cash nor switch sides twice.
	var cash_before: int=de.account(1).cash
	for id in g.players:
		if g.players[id].team==0:g.players[id].spectator=true
	de.tick(0);check(de.phase=="waiting" and de.account(1).cash==cash_before,"Missing team cancels preparation without farming money")
	de.tick(0);check(de.phase=="waiting","Empty team keeps match waiting")
	for id in g.players:g.players[id].spectator=false
	de.tick(0);check(de.phase=="prepare" and de.attacking==1-attacking,"Resumed halftime preparation cannot swap roles twice")
	de.win_limit=1;live();de.finish_round(0,"TEST");g.clock=de.phase_end;de.tick(0)
	check(g.intermission>0 and de.phase=="finished","Win limit ends match through existing intermission/vote flow")
	for digit in 10:check(Contact.key_at(Contact.key_point(digit))==digit,"Rendered/interactive keypad digit "+str(digit))
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/rules.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
