extends SceneTree
const Delivery=preload("res://deathmatch/network/movement_delivery.gd")
const Interpolation=preload("res://deathmatch/network/interpolation.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():
 var client:=Delivery.new();var s:Dictionary={"serial":1}
 for seq in 4:
  client.sample({"seq":seq,"move":Vector2.RIGHT,"yaw":0.,"slow":false,"jump":seq==2},1)
 var wire:Dictionary={"seq":3,"input_life":1};client.annotate(wire)
 Delivery.accept(s,wire)
 var jumps:=0
 for i in 4:
  var c:=Delivery.consume(s)
  check(s.movement_ack==i,"One simulated acknowledgement per tick: "+str(i))
  if c.get("jump",false):jumps+=1
 check(jumps==1,"Lost packet recovery retains intermediate jump")
 Delivery.accept(s,wire);Delivery.consume(s)
 check(s.movement_ack==3 and s.movement_queue.is_empty(),"Receipt gaps never acknowledge commands the client has not sent")
 s.serial=2;Delivery.accept(s,wire)
 check(Delivery.consume(s).is_empty(),"Previous life movement cannot replay")
 var interpolation:=Interpolation.new()
 for i in 8:interpolation.push(2,i*.05,Vector3(i*.05,0,0),Vector3.RIGHT,0,1,i*.05)
 interpolation.advance(.35);var before:=interpolation.render_time;interpolation.delay=.15
 interpolation.advance(.36)
 check(interpolation.render_time>before and interpolation.render_time-before<=.01101,"Growing jitter buffer slows playback without freezing")
 var latest:=interpolation.server_time
 for i in 100:interpolation.advance(.4+i*.01)
 check(interpolation.render_time<=latest,"Buffer exhaustion cannot extrapolate through walls")
 interpolation.push(2,2.,Vector3(100,0,0),Vector3.ZERO,0,2,2.)
 check(interpolation.sample(2).position==Vector3(100,0,0),"New life never interpolates through a teleport")
 print("MOVEMENT_DELIVERY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
