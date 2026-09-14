extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Delivery=preload("res://deathmatch/network/input_delivery.gd")
func _initialize():run.call_deferred()
func run():
 var failures:Array=[]
 var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(80,1,80))
 for latency in [1,2,3,6]:
  for short in [false,true]:
   var a:=Fighter.new();a.setup(1,"Local",Color.WHITE);world.add_child(a);a.position=Vector3(10,.01,0);a.quake_movement=true
   var b:=Fighter.new();b.setup(2,"Server",Color.WHITE);world.add_child(b);b.position=Vector3(-10,.01,0);b.quake_movement=true
   await physics_frame;await physics_frame
   var delivery:=Delivery.new();var s:Dictionary={"serial":1,"dead":false,"spectator":false,"jump":false};var inputs:Array=[];var snapshots:Array=[];var ack:=-1;var apices:Array=[];var peak:=0.;var velocity_impulses:=0;var corrections:Array=[]
   for tick in 720:
    var pressed:bool=tick%72>=20 and tick%72<(21 if short else 32)
    var command:Dictionary={"jump":pressed,"seq":tick};delivery.sample(command,1,tick/60.)
    if tick%2==0:delivery.annotate(command,tick/60.);inputs.append({"at":tick+latency,"command":command})
    a.simulate(Vector2.ZERO,0,false,1./60.,pressed);a.prediction.remember(tick,a.position,a.velocity)
    while not inputs.is_empty() and inputs[0].at<=tick:
     var cmd:Dictionary=inputs.pop_front().command;Delivery.accept(s,cmd);s.jump=cmd.jump;ack=cmd.seq
    b.simulate(Vector2.ZERO,0,false,1./60.,Delivery.consume(s,b))
    if tick%3==0:snapshots.append({"at":tick+latency,"ack":ack,"position":b.position+Vector3(20,0,0),"velocity":b.velocity,"jump_ack":s.get("jump_ack",0),"grounded":b.is_supported()})
    while not snapshots.is_empty() and snapshots[0].at<=tick:
     var snap:Dictionary=snapshots.pop_front();delivery.acknowledge(1,snap.jump_ack)
     var v:Vector3=a.velocity;var p:Vector3=a.position;a.prediction.reconcile(a,snap.ack,snap.position,snap.velocity,-1,snap.grounded)
     if absf(a.velocity.y-v.y)>.8:velocity_impulses+=1;corrections.append({"tick":tick,"before":v.y,"after":a.velocity.y,"y":p.y})
    peak=maxf(peak,a.position.y)
    if tick%72==71:apices.append(peak);peak=0
   if velocity_impulses!=0:failures.append([latency,short,velocity_impulses])
   print("JUMP_COMPARE ",JSON.stringify({"latency_ticks":latency,"short":short,"stats":a.prediction.stats,"apices":apices,"velocity_impulses":velocity_impulses,"changes":corrections}))
   a.free();b.free()
 world.free();print("PREDICTION_LANDINGS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
