extends SceneTree
const Poses=preload("res://tools/native_study/remaining_network.gd")
const Movement=preload("res://deathmatch/network/movement_delivery.gd")
const Fire=preload("res://deathmatch/network/fire_delivery.gd")
const InputDelivery=preload("res://deathmatch/network/input_delivery.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
const Locomotion=preload("res://deathmatch/network/locomotion_wire.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var poses:=Poses.new();var movement:=Movement.new();var fire:=Fire.new()
 var s:Dictionary={"serial":1,"weapon":6,"dead":false,"spectator":false,"fire":false}
 var maximum:=0
 for tick in 180:
  var pose:Dictionary=poses.full_pose(tick*.05)
  for field in ["head","left","right","weapon"]:
   pose[field].basis=Basis.from_euler(Vector3(sin(tick*.03)*.2,cos(tick*.04)*.2,sin(tick*.07)*.1))
  var command:Dictionary={"seq":tick,"map_epoch":1,"input_life":1,"weapon":6,"move":Vector2.RIGHT,"yaw":0.,"pitch":0.,"fire":tick%2==0,"slow":false,"respawn":false,"jump":tick%30==0,"xr":pose}
  movement.sample(command,1);fire.sample(command,1,tick/60.);movement.annotate(command);fire.annotate(command,tick/60.)
  var bytes:=InputDelivery.pack(command);maximum=maxi(maximum,bytes.size())
  check(not bytes.is_empty() and bytes.size()<=1100,"Saturated tracked input fits datagram")
  var wire=Codec.unpack(bytes,16384)
  check(wire is Dictionary and wire.seq==tick,"Input fits decoder's uncompressed budget")
  check(wire.fire_events[0][0]==command.fire_events[0][0],"Budget pruning retains oldest trigger")
  Fire.accept(s,wire,tick/60.);var saved:=Fire.begin_attempt(s,tick/60.);Fire.end_attempt(s,saved)
  Movement.accept(s,wire);var c:=Movement.consume(s)
  check(not c.is_empty() and c.seq<=tick,"Trimmed gameplay poses pass authority validation")
 var actor=preload("res://deathmatch/fighter.gd").new()
 var state:Dictionary={"height":1.65,"replay":actor.prediction_state(),"shot_counts":{"0:5":3},"fire_results":[[5,"fired",1]]}
 check(Locomotion.decode(Codec.unpack(Codec.pack(Locomotion.encode(state))))==state,"Compact replay state is lossless")
 actor.free();poses.free()
 print("RESPONSIVENESS_PROTOCOL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"maximum_input_bytes":maximum}));quit(0 if failures.is_empty() else 1)
