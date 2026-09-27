extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var g
var cs
var checks:=0
var failures: Array=[]
var sequence:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func reset(w: int=2):
	g.clock+=5;g.match_mode.kind="dm";g.armory.select("cs16");g.variant_combat.reset();g.intermission=0;g.dropped_weapons.clear()
	for id in g.players:
		g.players[id].merge({"weapon":w,"owned":range(12),"starting_weapons":[0,2],"ammo":[240,64,300,40],"hp":2000,"armor":0,"dead":false,"spectator":false,"invulnerable":0,"cooldown":0.0,"charge":0.0,"fire":false,"held":false,"alt_fire":false,"reload":false,"weapon_zoom":false,"input_blocked":false,"last_input":g.clock,"yaw":0.0,"pitch":0.0,"vr_device":false,"xr":{},"team":0 if id==1 else 1,"melee":false,"melee_state":{},"offhand_melee_state":{},"melee_seq":-1,"melee_ready_at":0.0},true)
		g.fighters[id].position=Fixture.point(8,8);g.fighters[id].velocity=Vector3.ZERO
	g.fighters[1].position=Fixture.point();g.fighters[-1].position=Fixture.point(0,-3)
func advance(seconds: float,fire: bool=false):
	var dt:=1.0/120
	for i in ceili(seconds/dt):
		g.clock+=dt;var s: Dictionary=g.players[1];s.cooldown=maxf(0,s.cooldown-dt);s.fire=fire;s.last_input=g.clock
		cs.tick_input(1,dt)
		if not s.fire:s.held=false
func swing(x: float,dt: float=.05,alt: bool=false):
	g.clock+=dt;sequence+=1
	var pose:=Poses.neutral();pose.right=Transform3D(Basis.IDENTITY,Vector3(x,1.1,-.65));pose.weapon=pose.right
	g._accept_input(1,{"seq":sequence,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"alt_fire":alt,"melee":true,"weapon":0,"slow":false,"respawn":false,"xr":pose})
	g._update_melee(1)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("CS16 mechanics",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	check(g.armory.kind=="cs16" and g.players[1].owned==[0,2] and g.players[1].ammo==[60,0,0,0],"Selectable loadout spawns knife and USP with 12 + 48 rounds")
	check(not preload("res://deathmatch/server/config.gd").parse('set sv_weapon_rules cs16').has("error"),"Server accepts CS16 preference")
	for w in range(1,12):
		reset(w);var before: Array=g.players[1].ammo.duplicate();var d: Dictionary=g.armory.data(w)
		check(cs.shoot(1) and g.players[1].ammo[d.ammo]==before[d.ammo]-1 and cs.state(1).clips[w]==d.magazine-1,"One shot spends one round from "+d.name)
		check(not cs.shoot(1),d.name+" respects its firing cadence")
	reset(2);cs.shoot(1);advance(.4,true)
	check(cs.state(1).clips[2]==11,"Holding a semi-automatic trigger cannot fire again")
	advance(.01);advance(.01,true);check(cs.state(1).clips[2]==10,"Releasing and pressing semi trigger fires again")
	advance(.3);var total: Array=g.players[1].ammo.duplicate()
	check(cs.begin_reload(1),"Partial magazine can be reloaded")
	advance(2.6);check(cs.state(1).clips[2]==10 and not cs.shoot(1),"Reload blocks firing until full duration")
	advance(.11);check(cs.state(1).clips[2]==12 and g.players[1].ammo==total,"Reload fills magazine without manufacturing ammunition")
	reset(2);g.players[1].ammo[0]=1;check(cs.shoot(1) and cs.state(1).clips[2]==0 and g.players[1].ammo[0]==0,"Last reserve round is consumed exactly once")
	check(not cs.begin_reload(1) and not cs.shoot(1),"No ammo means neither reload nor fire")
	reset(6);cs.state(1).clips[6]=1;cs.shoot(1);advance(.11)
	check(cs.state(1).reloading==6,"Empty automatic weapon starts reload")
	g.players[1].weapon=7;cs.state(1);advance(3)
	g.players[1].weapon=6;check(cs.state(1).clips[6]==0,"Switching cancels reload and retains empty magazine")
	reset(3);cs.state(1).clips[3]=2;cs.begin_reload(1);advance(.54)
	check(cs.state(1).clips[3]==2,"Shotgun respects reload opening delay")
	advance(.02);check(cs.state(1).clips[3]==3,"Shotgun loads one shell at a time")
	advance(.01,true);check(cs.state(1).clips[3]==2 and cs.state(1).reloading<0,"Shotgun firing interrupts shell reload")
	reset(1);g.players[1].alt_fire=true;advance(.01);g.players[1].alt_fire=false;advance(.31);advance(.26,true)
	check(cs.state(1).clips[1]==17 and cs.state(1).burst==0,"Glock burst fires exactly three rounds, including queued shots")
	advance(.6,true);check(cs.state(1).clips[1]==17,"Holding Glock burst trigger does not repeat bursts")
	advance(.01);advance(.26,true);check(cs.state(1).clips[1]==14,"Second Glock press produces a fresh burst")
	reset(1);cs.state(1).modes[1]=true;cs.shoot(1);g.players[1].input_blocked=true;advance(.3)
	check(cs.state(1).clips[1]==19 and cs.state(1).burst==0,"Menu cancels remaining burst rounds")
	for w in [2,7]:
		reset(w);g.players[1].alt_fire=true;advance(.01)
		check(cs.suppressed(1) and cs.definition(1).damage==(30 if w==2 else 33),"Suppressor changes "+g.armory.data(w).name+" damage and replicated mode")
		advance(.5);check(cs.suppressed(1) and not cs.shoot(1),"Held alternate cannot oscillate suppressor, attachment blocks firing")
		g.players[1].alt_fire=false;advance(1.51);check(cs.shoot(1),"Suppressed weapon becomes ready after attachment")
	reset(9);g.players[1].alt_fire=true;advance(.01)
	check(g.players[1].weapon_zoom and cs.shoot(1),"AWP can aim and fire simultaneously")
	check(cs.falloff(g.armory.data(6),36,12.7)==35 and cs.falloff(g.armory.data(1),25,12.7)==19,"Range attenuation follows per-500-unit damage modifiers")
	reset(6);var still: float=cs.definition(1).spread;g.fighters[1].velocity.x=3
	check(cs.definition(1).spread>still,"Moving makes rifle shots less accurate")
	g.fighters[1].velocity=Vector3.ZERO;cs.shoot(1);var hot: float=cs.definition(1).spread;advance(.8)
	check(cs.definition(1).spread<hot,"Accuracy recovers after firing stops")
	reset(6);g.players[1].input_blocked=true;check(not cs.shoot(1),"Blocked input cannot fire")
	g.players[1].input_blocked=false;g.players[1].owned=[0,2];check(not cs.shoot(1),"Unowned weapon cannot fire")
	reset(2);g.players[1].vr_device=true;g.fighters[1].position=Fixture.point(9.5,0)
	var pose:=Poses.neutral();pose.right.origin=Vector3(.8,1.1,0);pose.weapon=Transform3D(Basis(Vector3.UP,-PI/2),pose.right.origin);g.players[1].xr=pose
	check(not cs.shoot(1) and cs.state(1).clips[2]==12,"Tracked hand through wall cannot spend ammo or fire")
	reset(0);g.fighters[-1].position=Fixture.point(0,-1)
	g.players[1].fire=true;cs.tick_input(1,.01)
	check(g.players[-1].hp==1975 and g.players[1].melee_state.get("hit",false),"Desktop knife uses shared melee sweep for a 25-damage slash")
	cs.tick_input(1,.01);check(g.players[-1].hp==1975,"Repeated knife input cannot bypass melee cooldown")
	reset(0);g.fighters[-1].position=Fixture.point(0,-.8);g.players[1].alt_fire=true;cs.tick_input(1,.01)
	check(g.players[-1].hp==1935,"Knife alternate uses shared short-range 65-damage stab")
	reset(0);g.fighters[-1].position=Fixture.point(0,-1);g.players[1].vr_device=true
	check(not g.variant_combat.fire(1) and not g.variant_combat.fire(1,true),"VR knife rejects hitscan trigger attacks")
	for x in [-.8,-.65,-.45,-.3,-.15,0.0,.15]:swing(x)
	check(g.players[-1].hp==1975,"Physical VR knife swing hits once through the existing melee sampler")
	reset(0);g.fighters[-1].position=Fixture.point(0,-1)
	for i in 8:swing(0)
	check(g.players[-1].hp==2000,"Holding knife inside target cannot cause contact damage")
	reset(6);cs.shoot(1);var old: Dictionary=cs.snapshot();cs.receive(old)
	check(cs.view[1][2]==29,"Magazine and mode snapshot validates")
	cs.receive({1:[1,99,999,-1,"bad"]});check(cs.view.is_empty(),"Malformed CS state rejected")
	g.players[1].serial+=1;check(cs.state(1).clips[6]==30,"New player life resets magazine and attachment state")
	reset(6);g.dropped_weapons.drop(1);check(g.dropped_weapons.entries.size()==1,"Non-starting CS weapon uses existing death drops")
	reset(2);g.dropped_weapons.drop(1);check(g.dropped_weapons.entries.is_empty(),"Starting USP never drops")
	for mode in ["tf","tb","as","ig","if","cc"]:
		g.match_mode.kind=mode;g.armory.select("cs16")
		check(g.armory.effective()!="cs16","Special mode "+mode+" retains its fixed weapons")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/combat.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
