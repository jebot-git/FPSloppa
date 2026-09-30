extends SceneTree
const Prediction=preload("res://deathmatch/network/projectile_prediction.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Cosmetic test",0,100,10,true,"dm","quake");game.set_process(false);game.set_physics_process(false)
 if game.bots:game.bots.free();game.bots=null
 await physics_frame;await physics_frame
 var sender=game.replication;sender.sequence=100;sender.cached={"old":true}
 game._finish_join(999999)
 check(game.replication==sender and sender.sequence==100 and sender.cached.is_empty(),"joining peer cannot reset established replication sequences")
 var prediction=Prediction.new();var identity:Array=[1,10,1,0,6];var d:Dictionary=game.armory.data(6).duplicate()
 var start:Vector3=Fixture.point()+Vector3.UP*1.3
 var count:int=game.projectiles.size();var ammo:Array=game.players[1].ammo.duplicate()
 prediction.add(game,identity,d,start,Vector3.FORWARD)
 check(prediction.flights.size()==1,"immediate cosmetic launch")
 var node=prediction.flights.values()[0].node
 prediction.step(game,.02,1,6,false,[])
 check(node.position.distance_to(start)>.1,"cosmetic flight advances")
 check(game.projectiles.size()==count and game.players[1].ammo==ammo,"cosmetic flight cannot alter authority or ammunition")
 var handoff:Dictionary=prediction.take(identity)
 check(handoff.node==node and prediction.flights.is_empty(),"exact identity transfers the existing node once")
 check(prediction.take(identity).is_empty(),"duplicate authority cannot claim a second cosmetic")
 node.queue_free()
 prediction.add(game,identity,d,start,Vector3.FORWARD);prediction.step(game,.01,1,6,false,[[10,"empty",1]])
 check(prediction.flights.is_empty(),"rejected fire removes cosmetic")
 prediction.add(game,identity,d,start,Vector3.FORWARD);prediction.step(game,.01,2,6,false,[])
 check(prediction.flights.is_empty(),"respawn removes cosmetic")
 prediction.add(game,identity,d,start,Vector3.FORWARD);prediction.step(game,.01,1,7,false,[])
 check(prediction.flights.is_empty(),"weapon switch removes cosmetic")
 prediction.add(game,identity,d,start,Vector3.FORWARD);prediction.step(game,.51,1,6,false,[])
 check(prediction.flights.is_empty(),"missing authority expires cosmetic")
 for i in 40:prediction.add(game,[1,i,1,0,6],d,start,Vector3.FORWARD)
 check(prediction.flights.size()==Prediction.LIMIT,"cosmetic collection bounded")
 prediction.reset();check(prediction.flights.is_empty(),"map/disconnect cleanup")
 # Swept world clearance: a cosmetic never flies through a nearby wall.
 Fixture.box(game,start+Vector3(0,0,-1),Vector3(4,4,.1))
 await physics_frame;await physics_frame
 prediction.add(game,identity,d,start,Vector3.FORWARD)
 for i in 8:prediction.step(game,.02,1,6,false,[])
 var stopped:Dictionary=prediction.flights.values()[0]
 check(stopped.stopped and stopped.position.z>start.z-1.,"world sweep stops cosmetic before cover")
 prediction.reset()
 # Gravity follows the configured launch without adding speculative collisions.
 var grenade:Dictionary=d.duplicate();grenade.gravity=9.8
 prediction.add(game,identity,grenade,start,Vector3.RIGHT);prediction.step(game,.04,1,6,false,[])
 check(prediction.flights.values()[0].position.y<start.y,"grenade cosmetic obeys gravity")
 prediction.reset()
 var charge:Dictionary=d.duplicate();charge.charge=.8
 check(not Prediction.eligible(charge),"charged launches are not shown prematurely")
 game.disconnect_game();game.free();await process_frame
 print("PREDICTED_PROJECTILES_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
