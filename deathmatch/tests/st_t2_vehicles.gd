extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
 g.start_host("T2 vehicle tests",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var r=g.match_mode.tribes;var c=r.vehicles;var pads=r.stations();var s: Dictionary=g.players[1];var actor=g.fighters[1]
 s.team=0;s.dead=false;s.spectator=false;s.input_blocked=false
 while not g.bots.navigation.ready():await physics_frame
 await physics_frame
 var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
 r.apply_equipment(1,"light",[3,2,0],"energy");r.energy[0]=30000
 for kind in ["wildcat","shrike","havoc","beowulf","thundersword","jericho"]:
  c.reset();actor.position=pads.rows[index].position;actor.velocity=Vector3.ZERO;g.clock+=4
  var d: Dictionary=c.Data.definition(kind);var before: int=r.energy[0]
  check(c.purchase(1,g.map_epoch,s.serial,kind),kind+" purchases from existing Raindance pad")
  check(r.energy[0]==before-d.price,kind+" charges exactly once")
  if c.rows.is_empty():continue
  var key: int=c.rows.keys()[0];g.clock+=4;actor.position=c.seat_position(c.rows[key],0)+Vector3(1.1,0,0)
  check(c.board(1,key,0),kind+" boards with existing Use lifecycle")
  check(c.valid(c.snapshot()),kind+" snapshot validates")
  check(not g.match_mode.st.can_take(1,1),kind+" prevents mounted flag pickup")
  check(c.leave(1),kind+" safe ejection")
  check(not c.board(1,key),kind+" immediate reboarding prevented")
  var scene=load("res://deathmatch/vehicles/tribes/"+kind+".scn")
  check(scene!=null and preload("res://deathmatch/ui/weapon_icons.gd").texture(d.title)!=null,kind+" has native model and purchase icon")
 c.reset()
 Fixture.box(g,Fixture.ORIGIN-Vector3.UP,Vector3(700,2,700));await physics_frame
 for kind in c.Data.KINDS:
  var d: Dictionary=c.Data.definition(kind)
  var row:={"kind":kind,"yaw":0.0,"pitch":0.0,"bank":0.0,"velocity":Vector3.ZERO}
  var control: Dictionary=c.Data.controls({"move":Vector2(0,-1),"vr_device":true,"fly":1.0})
  for i in 120:c.Data.advance(row,control,d.altitude,1./60.)
  check(row.velocity.z<0 and absf(row.velocity.y)<.01,kind+" forward input works at ceiling")
  row.velocity=Vector3.ZERO;control.move=Vector2.ZERO
  for i in 120:c.Data.advance(row,control,10.0 if d.get("hover",false) else 1.,1./60.)
  check(row.velocity.y<0 if d.get("hover",false) else row.velocity.y>0,kind+" ground following / existing analog lift")
  control.lift=0;row.velocity=Vector3(0,5,0)
  for i in 120:c.Data.advance(row,control,d.altitude if d.get("hover",false) else 5.,1./60.)
  check(absf(row.velocity.y)<.05,kind+" neutral lift settles")
 # Real occupied transport state, including the fifth Heavy passenger.
 c.rows[1]={"kind":"havoc","position":Fixture.ORIGIN+Vector3.UP*4,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":0.0,"bank":0.0,"hp":400.,"pilot":0,"life":-1,"passengers":[0,0,0,0,0],"passenger_lives":[-1,-1,-1,-1,-1],"team":0,"owner_team":0,"ready":0.0,"next_fire":0.0,"idle_until":g.clock+120}
 c.make_body(1);g.clock+=5;actor.position=c.seat_position(c.rows[1],0);check(c.board(1,1,0),"Havoc pilot boards")
 for slot in range(1,6):
  g._add_player(-slot,"Passenger"+str(slot));g.players[-slot].team=0;g.players[-slot].input_blocked=false;g.players[-slot].dead=false;g.players[-slot].spectator=false
  r.apply_equipment(-slot,"heavy",[3,2,4,1,7],"energy");g.fighters[-slot].position=c.seat_position(c.rows[1],slot)
  check(c.board(-slot,1,slot),"Heavy passenger %d boards assigned seat"%slot)
 check(c.valid(c.snapshot()) and c.occupants(c.rows[1]).size()==6,"Six distinct Havoc occupants survive snapshot validation")
 check(not c.fire(1),"Havoc has no invented pilot weapon")
 c.damage(1,0,10000,"IMPACT")
 check(c.rows.is_empty() and not c.mounted(1),"Transport destruction releases every occupant")
 # Blaster projectile format, direct hit path, cooldown and old Scout recordings.
 c.rows[2]={"kind":"shrike","position":Fixture.ORIGIN+Vector3.UP*5,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":0.0,"bank":0.0,"hp":150.,"pilot":0,"life":-1,"passengers":[],"passenger_lives":[],"team":0,"owner_team":0,"ready":0.0,"next_fire":0.0,"idle_until":g.clock+120}
 c.make_body(2);g.clock+=5;actor.position=c.seat_position(c.rows[2],0);check(c.board(1,2,0),"Shrike pilot boards")
 check(c.fire(2),"Shrike fires blaster with normal Fire")
 check(not c.fire(2),"Shrike fire cooldown enforced")
 check(c.rockets.size()==1 and c.rockets.values()[0].speed==180 and c.rockets.values()[0].kind=="shrike","Shrike projectile is distinct from Scout rocket")
 check(c.valid(c.snapshot()),"Shrike projectile network snapshot validates")
 var bad: Dictionary=c.snapshot();bad.rockets.values()[0].kind="havoc";check(not c.valid(bad),"Unarmed projectile kind rejected")
 bad=c.snapshot();bad.rockets.values()[0].life=1000.;check(not c.valid(bad),"Excess projectile life rejected")
 check(c.Data.projectile("shrike").radius==0,"Blaster has direct damage and no explosive splash")
 var bolt: Dictionary=c.rockets.values()[0].duplicate(true)
 for rocket in c.rockets.values():rocket.life=.001
 s.last_input=g.clock;s.fire=false;c.tick(.02)
 check(c.rockets.is_empty(),"Expired blaster removed without explosion")
 c.rows[3]=c.rows[2].duplicate(true);c.rows[3].pilot=0;c.rows[3].life=-1;c.rows[3].position+=Vector3(30,0,0);c.rows[3].velocity=Vector3.ZERO;c.rows[3].idle_until=g.clock+120
 c.make_body(3);await physics_frame;await physics_frame
 for friendly in [false,true]:
  c.rows[3].team=0 if friendly else 1;c.rows[3].hp=150.
  bolt.position=c.rows[3].position+Vector3(0,0,4);bolt.direction=Vector3.FORWARD;bolt.velocity=Vector3.FORWARD*180;bolt.life=3.;bolt.team=0
  c.rockets[100]=bolt.duplicate(true);c.tick(.04)
  check(c.rows[3].hp==150. if friendly else c.rows[3].hp<150.,"Shrike direct hit respects friendly fire" if friendly else "Shrike bolt damages enemy hull")
 await remaining_vehicles()
 c.reset();g.disconnect_game();g.queue_free();await process_frame
 var result:={"checks":checks,"failures":failures}
 print("T2_VEHICLES_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func remaining_vehicles():
 var r=g.match_mode.tribes;var c=r.vehicles;var actor=g.fighters[1];var s: Dictionary=g.players[1]
 for kind in ["beowulf","thundersword","jericho"]:
  c.reset();g.clock+=10;var d: Dictionary=c.Data.definition(kind)
  c.rows[1]={"kind":kind,"position":Fixture.ORIGIN+Vector3.UP*(1.25 if kind=="jericho" else 25.),"velocity":Vector3.ZERO,"yaw":0.,"pitch":0.,"bank":0.,"hp":d.hp,"pilot":0,"life":-1,"passengers":[],"passenger_lives":[],"team":0,"owner_team":0,"ready":0.,"next_fire":0.,"idle_until":g.clock+120}
  var row: Dictionary=c.rows[1];row.passengers.resize(d.seats.size()-1);row.passengers.fill(0);row.passenger_lives.resize(d.seats.size()-1);row.passenger_lives.fill(-1)
  if kind=="jericho":row.deployed=false
  c.make_body(1);actor.position=c.seat_position(row,0);s.dead=false;s.input_blocked=false;s.team=0
  check(c.board(1,1,0),kind+" fixture pilot boards")
  if kind!="jericho":
   check(c.fire(1),kind+" solo pilot fires main weapon")
   check(not c.fire(1),kind+" main weapon cadence is enforced")
   var projectile: Dictionary=c.rockets.values()[0];var vy: float=projectile.velocity.y
   s.fire=false;s.last_input=g.clock;c.tick(.05)
   check(projectile.velocity.y<vy,kind+" projectile follows a ballistic arc")
   if kind=="thundersword":check(projectile.direction==Vector3.DOWN,"Bomber releases bombs below the belly")
  for slot in range(1,d.seats.size()):
   var id: int=-slot;var crew: Dictionary=g.players[id];crew.team=0;crew.dead=false;crew.spectator=false;crew.input_blocked=false;crew.last_input=g.clock
   r.apply_equipment(id,"heavy",[3,2,4,1,7],"energy");g.fighters[id].position=c.seat_position(row,slot)
   check(c.board(id,1,slot),kind+" heavy crew boards slot "+str(slot))
   g.clock+=3
   check(c.fire(1,id),kind+" crew primary fires mounted weapon "+str(slot))
   check(c.weapon_operator(id),kind+" crew personal weapon is suppressed")
   if kind!="jericho":check(not c.fire(1),kind+" occupied main gun prevents pilot double fire")
  check(c.valid(c.snapshot()),kind+" full crew and weapon snapshot validates")
  var bad: Dictionary=c.snapshot();bad.rows[1]["deployed"]="yes";check(not c.valid(bad),kind+" malformed deployment state rejected")
  if kind=="jericho":
   c.rockets.clear();c.leave(-1,true);g.clock+=3;await physics_frame;await physics_frame
   row.velocity=Vector3(4,0,0);check(not c.deploy(1),"Jericho cannot deploy while moving")
   row.velocity=Vector3.ZERO;check(c.deploy(1),"Jericho deploys on level ground")
   var controls: Dictionary=c.Data.controls({"move":Vector2(0,-1),"fly":1.,"vr_device":true})
   c.Data.advance(row,controls,1.25,1.);check(row.velocity==Vector3.ZERO,"Deployed base cannot drive or fly")
   c.leave(1,true);actor.position=c.frame(row)*Vector3(0,-1.25,5.5)
   check(c.mobile_station(1)==1 and r.can_refit(1),"Friendly rear inventory supports refitting")
   s.hp=20;r.energy[0]=3000;r.stations().tick(r,1.)
   check(s.hp>20,"Mobile inventory heals using station service")
   s.team=1;check(c.mobile_station(1)<0 and not r.can_refit(1),"Enemy cannot use mobile inventory");s.team=0
   g.players[-1].team=1;g.players[-1].dead=false;g.fighters[-1].position=row.position+Vector3(20,0,0);g.clock+=3;await physics_frame
   c.base_defence(1);check(not c.rockets.is_empty() and c.rockets.values()[0].team==0,"Deployed base defends its team without a pilot")
   check(c.valid(c.snapshot()),"Unoccupied deployed base snapshot validates")
   g.clock+=4;actor.position=c.seat_position(row,0);check(c.board(1,1,0),"Friendly pilot reboards deployed base")
   check(c.deploy(1) and not row.deployed,"Pilot packs mobile base for driving")
  c.damage(1,0,10000,"IMPACT");check(c.rows.is_empty() and not c.mounted(1),kind+" destruction ejects complete crew")
