extends SceneTree
var g
var w
var tf
var row:Dictionary
var checks:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks.append({"pass":ok,"name":label});print("PASS " if ok else "FAIL ",label)
func heal_for(seconds:float,step:float=1./60.):
 var elapsed:=0.
 while elapsed<seconds-.0000001:
  var dt:=minf(step,seconds-elapsed);w.heal_pilot(row,dt);elapsed+=dt
func wound(hp:int):g.players[1].hp=hp;row.heal_credit=0.
func run():
 g=load("res://deathmatch/arena.tscn").instantiate()
 g.match_mode.fortress.walkers.free();g.match_mode.fortress.walkers=preload("res://tools/titanball/simulation/class_health_baseline.gd").new()
 g.match_mode.fortress.walkers.name="Walkers";g.match_mode.fortress.add_child(g.match_mode.fortress.walkers)
 root.add_child(g)
 g.start_host("Cockpit healing",0,100,10,true,"tb","quake");g.set_physics_process(false);g.set_process(false)
 g.bots.free();g.bots=null;tf=g.match_mode.fortress;w=tf.walkers
 var ground=preload("res://deathmatch/tests/fixture.gd").box(g,Vector3(1000,-.5,0),Vector3(50,1,50))
 w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}]);row=w.robots.test
 for id in g.players:
  g.players[id].spectator=id in [-2,-3];g.players[id].team=0;g.players[id].tf_class="heavy";g.players[id].dead=false;g.players[id].invulnerable=0
  g.fighters[id].position=Vector3(1010,0,0)
 g.fighters[1].position=Vector3(1000,0,0)
 await physics_frame;await physics_frame
 check(w.try_board(1,"test") and g.players[1].hp==200,"Boarding still restores class maximum")
 wound(20);heal_for(2)
 check(g.players[1].hp==20 and not w.pilot_regeneration,"Experiment defaults off")
 w.pilot_regeneration=true
 # Exercise the real map-station dispenser branch against the new steady rate.
 tf.buildings.clear();tf.buildings[99]={"owner":0,"team":-1,"position":g.fighters[-1].position,"kind":"dispenser","hp":150,"ready":0.,"next":g.clock+1,"expires":0.,"map_owned":true,"universal":true}
 g.players[-1].hp=20
 for second in 10:
  g.clock+=1;tf.tick_sentries();heal_for(1)
 check(g.players[1].hp==120 and g.players[-1].hp==120,"Both cockpit and actual TB dispenser restore 100 HP over ten seconds")
 check(tf.DISPENSER_HEALTH_RATE==10.,"Actual station rate is 10 HP/s")
 for step in [1./60.,1./90.,1./120.,.25,1.0]:
  wound(20);heal_for(3,step)
  check(g.players[1].hp==50,"Healing is independent of physics cadence: "+str(step))
 wound(20);var ammo=g.players[1].ammo.duplicate();var armor=g.players[1].armor
 heal_for(.05);check(g.players[1].hp==20,"Sub-HP credit is accumulated without minimum-per-frame healing")
 heal_for(.05);check(g.players[1].hp==21,"Fractional credit restores exactly one HP after 0.1 s")
 check(g.players[1].ammo==ammo and g.players[1].armor==armor,"Healing does not resupply ammunition or alter permanent armour")
 for role in tf.CLASSES:
  g.players[1].tf_class=role;wound(tf.max_health(1)-2);heal_for(1)
  check(g.players[1].hp==tf.definition(1).hp and tf.max_health(1)==tf.definition(1).hp,"Healing stops at unchanged class maximum: "+role)
 g.players[1].tf_class="heavy";wound(200);heal_for(30);g.players[1].hp=150;heal_for(.05)
 check(g.players[1].hp==150,"Full health cannot bank a burst of healing")
 wound(20);g.map_loading=true;heal_for(2);g.map_loading=false
 check(g.players[1].hp==20,"No healing during map loading")
 g.intermission=5;heal_for(2);g.intermission=0
 check(g.players[1].hp==20,"No healing during intermission")
 g.active=false;heal_for(2);g.active=true
 check(g.players[1].hp==20,"Inactive game cannot heal")
 g.match_mode.kind="tf";heal_for(2);g.match_mode.kind="tb"
 check(g.players[1].hp==20,"Experiment is confined to TB")
 g.players[1].dead=true;g.players[1].hp=0;heal_for(2)
 check(g.players[1].hp==0,"Dead pilots cannot be revived")
 g.players[1].dead=false;wound(20);g.players[1].spectator=true;heal_for(2);g.players[1].spectator=false
 check(g.players[1].hp==20,"Spectators cannot heal")
 g.players[1].serial+=1;heal_for(2);g.players[1].serial-=1
 check(g.players[1].hp==20,"Stale pilot life cannot heal a respawn")
 tf.buildings.clear();g.players[1].tf_class="medic";wound(20);tf.tick_credit=0.;g.players[1].tf_regen=0.
 for tick in 4:g.clock+=.25;tf.tick(.25)
 check(g.players[1].hp==33,"Full TF tick combines 10 HP cockpit healing with Medic's existing 3 HP/s")
 g.players[1].tf_class="heavy";wound(20);heal_for(.05)
 check(row.heal_credit>0 and not w.leave(1),"Original three-second boarding lock is still enforced")
 row.exit_lock=0.;check(w.leave(1,true),"Leaving releases occupied cockpit")
 var hp:int=g.players[1].hp;heal_for(2)
 check(g.players[1].hp==hp and row.heal_credit==0.,"Healing and fractional credit stop on exit")
 row.speed=0.;row.to_speed=0.;g.clock+=2;g.fighters[1].position=w.transform(row)*w.LADDER
 await physics_frame;await physics_frame
 check(w.try_board(1,"test"),"New pilot tenure can board normally")
 wound(20);heal_for(.05);check(g.players[1].hp==20,"New occupant inherits no prior healing credit")
 w.leave(1,true)
 for role in tf.CLASSES:
  g.players[1].tf_class=role;g.players[1].hp=1;g.players[1].weapon=6;g.players[1].armor=35
  row.speed=0.;row.to_speed=0.;g.clock+=2;g.fighters[1].position=w.transform(row)*w.LADDER
  await physics_frame;await physics_frame
  check(w.try_board(1,"test") and g.players[1].hp==tf.definition(1).hp and tf.max_health(1)==tf.definition(1).hp,"Boarding retains original class HP and maximum: "+role)
  g.players[1].hp=40;w.leave(1,true)
  check(g.players[1].hp==40 and tf.max_health(1)==tf.definition(1).hp and g.players[1].armor==35 and g.players[1].weapon==6,"Living exit preserves remaining HP and restores armour and weapon: "+role)
 g.players[1].tf_class="scout";row.speed=0.;row.to_speed=0.;g.clock+=2;g.fighters[1].position=w.transform(row)*w.LADDER
 await physics_frame;await physics_frame;w.try_board(1,"test")
 g.players[1].serial+=1;g.players[1].hp=30;w.tick(0.)
 check(not w.mounted(1) and g.players[1].hp==30,"Stale cockpit cleanup cannot heal a replacement life")
 row.speed=0.;row.to_speed=0.;g.clock+=2;g.fighters[1].position=w.transform(row)*w.LADDER
 await physics_frame;await physics_frame;w.try_board(1,"test")
 g._damage(1,1,100000,"SUICIDE",true)
 check(g.players[1].dead and g.players[1].hp<=0 and not w.mounted(1) and tf.max_health(1)==75,"Death ejects without restoring living health")
 g.disconnect_game();check(not w.pilot_regeneration,"Disconnect clears experimental healing")
 var result={"passed":checks.all(func(c):return c.pass),"checks":checks}
 DirAccess.make_dir_recursive_absolute("res://test-results/titanball/pilot-healing-only")
 FileAccess.open("res://test-results/titanball/pilot-healing-only/unit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("PILOT_HEALING_ONLY_RESULT ",result.passed)
 g.queue_free();await process_frame;await process_frame;quit(0 if result.passed else 1)
