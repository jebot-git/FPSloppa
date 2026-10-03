extends SceneTree
const A=preload("res://deathmatch/tribes/arsenal.gd")
const T=preload("res://deathmatch/movement/tribes.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Status=preload("res://deathmatch/ui/player_status.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Tribes armour",0,100,30,true,"tdm","tribes")
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200))
	await physics_frame;await physics_frame
	var rules=g.match_mode.tribes;rules.reset()
	var s: Dictionary=g.players[1];var a=g.fighters[1];s.team=0
	var panel=load("res://deathmatch/modes/fortress_panel.gd").new();root.add_child(panel);panel.setup(g);panel.open()
	check(panel.tribes_menu and panel.choice.value=="light" and not panel.tool.visible,"TF menu presents Tribes armour without TF abilities")
	var hud=load("res://deathmatch/vr/status_hud.gd").new();root.add_child(hud)
	for key in ["light","medium","heavy"]:
		g.clock+=1
		var old_class: String=s.get("tribes_class","light");var old_hp: int=s.hp;var before: int=rules.energy[0]
		check(rules.select_equipment(1,key,A.defaults(key),"energy") and s.tribes_class==old_class and s.hp==old_hp and rules.energy[0]==before,"Queue does not refit/heal/spend in combat: "+key)
		check(not rules.select_class(1,key),"Class-request spam throttled: "+key)
		g._spawn(1);var profile: Dictionary=rules.definition(1)
		check(s.tribes_class==key and s.hp==profile.hp and s.armor==0 and a.tribes_state.armour==key,"Spawn applies class durability and movement together: "+key)
		check(rules.energy[0]==before and rules.energy[1]==rules.INITIAL_ENERGY,"Arena loadouts do not spend ST team energy: "+key)
		check(s.owned.filter(func(w):return w<8).size()==profile.guns and not rules.can_carry(1,6) and rules.can_carry(1,2),"Class gun capacity includes ammo pickup for an owned gun: "+key)
		for hz in [30,60,120]:
			a.position=Fixture.ORIGIN+Vector3.UP*.01;a.velocity=Vector3.ZERO;a.reset_tribes()
			for tick in hz:a.simulate(Vector2.RIGHT,0,false,1.0/hz)
			check(absf(a.velocity.x-profile.walk)<.03,"Class walking speed at %d Hz: %s"%[hz,key])
			a.position=Fixture.ORIGIN+Vector3.UP*20;a.velocity=Vector3.ZERO;a.reset_tribes();a.jet_held=true
			for tick in hz:a.simulate(Vector2.ZERO,0,false,1.0/hz)
			check(absf(a.tribes_state.energy-(profile.energy-profile.drain+11))<.03 and absf(a.velocity.y-(profile.thrust-20))<.04,"Class thrust and energy at %d Hz: %s"%[hz,key])
			a.jet_held=false
			for tick in hz*11:a.simulate(Vector2.ZERO,0,false,1.0/hz)
			check(a.tribes_state.energy==profile.energy,"Class recharge cap at %d Hz: %s"%[hz,key])
		a.velocity=Vector3.ZERO;a.apply_blast(Vector3(18,0,0))
		check(absf(a.velocity.x-18*9/profile.mass)<.001,"Armour mass scales blast impulse: "+key)
		a.position=Fixture.ORIGIN+Vector3.UP*30;a.velocity=Vector3.ZERO;a.reset_tribes();a.prediction.clear();a.jet_held=true
		var authority: Dictionary={}
		for tick in range(1,61):
			a.simulate(Vector2.ZERO,0,false,1.0/60)
			a.prediction.remember(tick,a.position,a.velocity,a.collision_height,{},a.tribes_state,a.tribes_command)
			if tick==30:authority={"position":a.position,"velocity":a.velocity,"state":a.tribes_state.duplicate(true)}
		var expected: Vector3=a.position;var expected_energy: float=a.tribes_state.energy
		a.prediction.reconcile(a,30,authority.position,authority.velocity,a.collision_height,false,{},authority.state)
		check(a.position.distance_to(expected)<.003 and absf(a.tribes_state.energy-expected_energy)<.001 and a.tribes_state.armour==key,"Prediction replays newer flight with the authoritative class: "+key)
		a.jet_held=false
		s.invulnerable=0;var hp: int=s.hp
		g._damage(1,1,20,"DISC LAUNCHER")
		check(s.hp==hp-roundi(20*A.RESISTS[key][3]) and s.armor==0,"Static class protection reduces real combat damage: "+key)
		s.hp=profile.hp;g._damage(1,1,20,"CHAINGUN")
		check(s.hp==profile.hp-roundi(20*A.RESISTS[key][2]),"Bullet resistance follows class: "+key)
		var resource:=Status.vitals(g,1)
		check(resource.name=="ENERGY" and resource.maximum==profile.energy and resource.health_max==profile.hp,"Shared desktop/VR vitals use class energy and health: "+key)
		hud.update_status(s,60,20,0,false,false,"",false,g.armory.data(s.weapon),g.armory.max_ammo(),false,resource)
		check(hud.values.resource_name=="ENERGY" and hud.values.resource_max==profile.energy,"VR armour gauge becomes energy gauge: "+key)
		panel.open();check(panel.choice.value==key and not "TEAM ENERGY" in panel.details.text and not panel.inventory_button.visible,"Arena menu restores selection without ST budget or purchases: "+key)
		if DisplayServer.get_name()!="headless" and key=="heavy":
			root.size=Vector2i(1280,900);panel.hide();hud.hide()
			g.menu_open=true;g.hud.show_menu(true);g.hud.fortress_button.pressed.emit()
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/tribes-armour/menu.png")
			var view:=SubViewport.new();view.size=hud.VIEW_SIZE;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
			hud.reparent(view);hud.show();hud.size=hud.VIEW_SIZE
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("res://test-results/tribes-armour/energy-hud.png")
			hud.reparent(root);hud.hide();view.free()
		var invalid:=T.fresh(key);invalid.energy=profile.energy+1
		check(not T.valid_state(invalid),"Class-specific overfill rejected: "+key)
	# Real pickups may heal to the class maximum but never create ablative armour.
	a.position=Fixture.ORIGIN;a.travel_path=[];s.hp=160
	var previous: Array=g.pickups
	g.pickups=[{"kind":"health","item":25,"available":true,"position":a.position},{"kind":"armor","item":2,"available":true,"position":a.position},{"kind":"weapon","item":5,"available":true,"position":a.position}]
	g._collect(1)
	check(s.hp==185 and s.armor==0 and g.pickups[1].available and not s.owned.has(5),"Live pickup path respects heavy health, static protection and carry limit")
	g.pickups=previous
	var before: int=rules.energy[0];g._add_player(55,"Spectator");g.players[55].spectator=true
	check(not rules.select_class(55,"heavy"),"Spectators cannot buy armour")
	g._spawn(55);check(rules.energy[0]==before,"Spectator respawn spends no energy")
	g._peer_left(55);check(rules.energy[0]==before,"Disconnect cannot mint team energy")
	g.clock+=1;check(not rules.select_class(1,"invalid"),"Unknown class is rejected")
	rules.energy[0]=0;g._spawn(1)
	check(s.tribes_class=="heavy" and s.tribes_next=="heavy" and not s.tribes_fallback and rules.energy[0]==0,"Arena respawn keeps chosen armour regardless of ST bank")
	rules.tick(29.9);check(rules.energy[0]==0,"Team-energy refill waits for full interval")
	rules.tick(.2);check(rules.energy[0]==0 and rules.credit==0,"Arena modes do not replenish ST team energy")
	var kit_cost:=A.cost("heavy",A.defaults("heavy"),"energy");rules.energy[0]=kit_cost+300
	g._spawn(1);check(s.tribes_class=="heavy" and rules.energy[0]==kit_cost+300,"Arena equipment leaves the team reserve unchanged")
	rules.energy=[699999,700000,700000];rules.tick(60)
	check(rules.energy==[699999,700000,700000],"Long arena ticks leave ST economy inactive")
	var snapshot: Dictionary=rules.snapshot()
	check(rules.valid_snapshot(snapshot),"Production class and team-energy snapshot validates")
	var bad: Dictionary=snapshot.duplicate(true);bad.energy[0]=-1
	check(not rules.valid_snapshot(bad),"Negative budget rejected")
	bad=snapshot.duplicate(true);bad.players[1]["class"]="unknown"
	check(not rules.valid_snapshot(bad),"Unknown replicated class rejected")
	bad=snapshot.duplicate(true);bad.credit=NAN
	check(not rules.valid_snapshot(bad),"Non-finite refill timer rejected")
	s.tribes_class="light";rules.receive(snapshot);check(s.tribes_class=="heavy","Late snapshot restores class selection")
	g.match_mode.kind="dm";check(rules.bank(1)==2,"FFA has a shared test supply pool")
	g.armory.select("quake");g._spawn(1)
	check(not rules.enabled() and not a.tribes_enabled and s.hp==100 and Status.vitals(g,1).name=="ARMOUR","Other loadouts retain their health, movement and armour HUD")
	check(rules.damage(1,20,"CHAINGUN",false)==20 and rules.can_carry(1,3),"Tribes resistance and gun limit cannot leak into Quake")
	g.match_mode.kind="tf";panel.open();check(not panel.tribes_menu and panel.choice.value=="soldier","Shared menu switches back to normal TF classes")
	rules.reset();check(rules.energy==[5000,5000,5000] and rules.credit==0,"New match resets team economy")
	var report:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	DirAccess.make_dir_recursive_absolute("res://test-results/tribes-armour")
	FileAccess.open("res://test-results/tribes-armour/integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIBES_ARMOUR ",JSON.stringify(report))
	panel.free();hud.free();g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
