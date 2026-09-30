extends SceneTree
const Delivery=preload("res://deathmatch/network/fire_delivery.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func state() -> Dictionary:return {"serial":1,"weapon":6,"dead":false,"spectator":false,"input_blocked":false,"fire":false,"alt_fire":false,"offhand_fire":false}
func _initialize():
 var misses:=0;var recovered:=0
 for offset in 8:
  var client:=Delivery.new();var s:=state();var old_pressed:=false;var new_pressed:=false
  for tick in 12:
   var command:Dictionary={"weapon":6,"fire":tick==offset,"input_life":1}
   client.sample(command,1,tick/60.)
   if tick%2==0:
    old_pressed=old_pressed or command.fire;client.annotate(command,tick/60.);s.fire=command.fire;Delivery.accept(s,command,tick/60.)
   var saved:=Delivery.begin_attempt(s,tick/60.);new_pressed=new_pressed or s.fire;Delivery.end_attempt(s,saved)
   client.acknowledge(1,s.get("fire_ack",0))
  if not old_pressed:misses+=1
  if new_pressed:recovered+=1
 check(misses==4 and recovered==8,"All short taps survive either 30 Hz send phase; old path missed four of eight")
 var client:=Delivery.new();var s:=state()
 client.sample({"weapon":6,"fire":true},1,0.)
 var lost:Dictionary={"weapon":6,"fire":true,"input_life":1};client.annotate(lost,0.)
 client.sample({"weapon":6,"fire":false},1,.02)
 var wire:Dictionary={"weapon":6,"fire":false,"input_life":1};client.annotate(wire,.04);Delivery.accept(s,wire,.04)
 var saved:=Delivery.begin_attempt(s,.04);check(s.fire,"Dropped initial trigger packet recovers on release packet")
 Delivery.end_attempt(s,saved);check(not s.fire,"Recovered tap restores the released trigger state")
 Delivery.accept(s,wire,.05);saved=Delivery.begin_attempt(s,.05);check(not s.fire,"Repeated event cannot fire twice");Delivery.end_attempt(s,saved)
 client.acknowledge(1,s.fire_ack);wire.erase("fire_event");client.annotate(wire,.06);check(not wire.has("fire_event"),"Acknowledgement stops trigger retransmission")
 var old:=lost.duplicate(true);s=state();s.serial=2;Delivery.accept(s,old,.1);saved=Delivery.begin_attempt(s,.1);check(not s.fire,"Previous life cannot replay a trigger");Delivery.end_attempt(s,saved)
 s=state();Delivery.accept(s,lost,0.);s.weapon=5;saved=Delivery.begin_attempt(s,.02);check(not s.fire,"Weapon change cancels old tap");Delivery.end_attempt(s,saved)
 s=state();Delivery.accept(s,lost,0.);saved=Delivery.begin_attempt(s,.3);check(not s.fire,"Stale trigger cannot fire later");Delivery.end_attempt(s,saved)
 s=state();s.input_blocked=true;Delivery.accept(s,lost,0.);s.input_blocked=false;saved=Delivery.begin_attempt(s,.02);check(not s.fire,"Blocked input cannot replay after menu closes");Delivery.end_attempt(s,saved)
 for bad in [null,[1], [1,6,8],[1,6,"fire"],[1,5,1],[5000,6,1]]:
  s=state();Delivery.accept(s,{"fire_event":bad,"weapon":6,"input_life":1},0.);saved=Delivery.begin_attempt(s,0.);check(not s.fire,"Malformed event rejected: "+str(bad));Delivery.end_attempt(s,saved)
 # Multiple edges must survive together, including independent hands.
 client=Delivery.new();s=state();s.weapon=2
 client.sample({"weapon":2,"fire":true,"yaw":.2,"view_time":.1},1,.1)
 client.sample({"weapon":2,"fire":false},1,.12)
 client.sample({"weapon":2,"offhand_fire":true,"yaw":.8},1,.14)
 wire={"weapon":2,"input_life":1};client.annotate(wire,.14)
 check(wire.fire_events.size()==2,"Primary and offhand events coexist before receipt")
 Delivery.accept(s,wire,.14);saved=Delivery.begin_attempt(s,.14)
 check(s.fire and s.offhand_fire,"Both independent hands are attempted")
 check(is_equal_approx(Delivery.context(s).yaw,.2) and is_equal_approx(Delivery.context(s,true).yaw,.8),"Each edge retains its original aim")
 var primary:=Delivery.shot(s);var other:=Delivery.shot(s,true)
 check(primary==[1,1,1,0,2] and other==[1,2,1,2,2],"Shot identities include life, trigger, ordinal, hand and weapon")
 Delivery.end_attempt(s,saved)
 Delivery.accept(s,wire,.16);saved=Delivery.begin_attempt(s,.16)
 check(not s.fire and not s.offhand_fire,"Retransmitted queue cannot repeat either tap")
 Delivery.end_attempt(s,saved)
 s=state();s.weapon=3;s.cooldown=.04
 Delivery.accept(s,{"weapon":3,"input_life":1,"fire_event":[1,3,1]},0.)
 saved=Delivery.begin_attempt(s,0.)
 check(not s.fire and s.fire_queue.size()==1 and s.fire_ack==1,"Shotgun tap is received but waits for readiness")
 Delivery.end_attempt(s,saved);s.cooldown=0.
 saved=Delivery.begin_attempt(s,.05)
 check(s.fire and Delivery.shot(s)==[1,1,1,0,3],"Buffered shotgun fires once on readiness")
 Delivery.end_attempt(s,saved)
 s=state();s.cooldown=.5
 Delivery.accept(s,{"weapon":6,"input_life":1,"fire_event":[1,6,1]},0.)
 saved=Delivery.begin_attempt(s,0.,true);Delivery.end_attempt(s,saved)
 check(s.fire_queue.is_empty() and s.fire_results[0][1]=="cooldown","Long cooldown rejects rather than firing unexpectedly later")
 s=state()
 var invalid={"weapon":6,"input_life":1,"fire_events":[[[1,6,1],{"yaw":NAN},.25]]}
 Delivery.accept(s,invalid,0.)
 check(s.fire_queue.is_empty() and s.fire_ack==0,"Nonfinite event aim is rejected before acknowledgement")
 print("FIRE_DELIVERY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
