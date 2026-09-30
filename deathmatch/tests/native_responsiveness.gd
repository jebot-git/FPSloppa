extends SceneTree
const Codec=preload("res://deathmatch/network/codec.gd")
const InputDelivery=preload("res://deathmatch/network/input_delivery.gd")
const Movement=preload("res://deathmatch/network/movement_delivery.gd")
const Fire=preload("res://deathmatch/network/fire_delivery.gd")
const Poses=preload("res://tools/native_study/remaining_network.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok and failures.size()<20:failures.append(label);push_error(label)
func _initialize():
 var native=Codec.native_codec
 check(native!=null and native.has_method("pack_input") and native.has_method("pack_records"),"New native packing methods loaded")
 if not failures.is_empty():quit(1);return
 var poses:=Poses.new();var moves:=Movement.new();var fire:=Fire.new()
 for tick in 240:
  var command:Dictionary={"seq":tick,"input_life":1,"map_epoch":1,"move":Vector2.RIGHT,"yaw":tick*.01,"pitch":.2,"fire":tick%2==0,"weapon":6,"slow":false,"respawn":false,"xr":poses.full_pose(tick*.05)}
  for field in ["head","left","right","weapon"]:command.xr[field].basis=Basis.from_euler(Vector3(sin(tick*.1),cos(tick*.07),sin(tick*.13))*.3)
  moves.sample(command,1);fire.sample(command,1,tick/60.);moves.annotate(command);fire.annotate(command,tick/60.)
  var before:=var_to_bytes(command)
  var reference:=InputDelivery.pack_reference(command)
  var actual:PackedByteArray=native.pack_input(command)
  check(reference==actual,"Exact input packing bytes including overflow pruning")
  check(var_to_bytes(command)==before,"Input and history are never mutated")
  check(not actual.is_empty() and actual.size()<=1100,"Native input fits budget")
 # Unshrinkable oversized payload must fail without a retry loop or mutation.
 var rng:=RandomNumberGenerator.new();rng.seed=4817
 var noise:=PackedByteArray();noise.resize(4096)
 for i in noise.size():noise[i]=rng.randi()%256
 check(native.pack_input({"noise":noise}).is_empty(),"Unshrinkable input rejected")
 var fixture=preload("res://deathmatch/tests/native_network_packing.gd").new()
 for tick in 30:
  var snapshot:Array=fixture.snapshot(16,32,true,tick)
  var records:Array=[[0,2,tick*.05],[1,"kind","dm"],[4,0,[1,2,3],[],[]]]
  for row in snapshot[0]:records.append([2,row[0],row,snapshot[10].locomotion[row[0]],tick])
  for row in snapshot[7]:records.append([3,row[0],row,{}])
  var encoded:Array=native.encode_records(records)
  for i in records.size():check(encoded[i]==preload("res://deathmatch/network/snapshot_codec.gd").encode(records[i]),"Batched mixed record encoding is byte exact")
 fixture.free()
 var sender:=Replication.new()
 for count in [0,1,2,8,16,32,128,523]:
  for repetition in 8:
   var records:Array=[]
   for i in count:
    var size:int=rng.randi_range(1,1600)
    records.append(noise.slice(0,size) if i%3==0 else PackedByteArray([i%256,0,0,0]))
   var before:=var_to_bytes(records);var header:Array=[1,repetition,repetition*.05]
   var reference:Dictionary={"normal":[],"large":[]}
   sender._pack_records_reference(records,header,reference)
   var actual:Dictionary=native.pack_records(records,header)
   check(not actual.invalid and reference.normal==actual.normal and reference.large==actual.large,"Exact packet boundaries, order and channel choice")
   check(var_to_bytes(records)==before,"Snapshot input remains immutable")
   for packet in actual.normal:check(packet.size()<=1100,"Normal datagram bound")
 check(native.pack_records([],[]).invalid,"Malformed batch header rejected")
 var enormous:=PackedByteArray();enormous.resize(262144)
 var rejected:Dictionary=native.pack_records([enormous],[1,1,1.0])
 check(rejected.invalid and rejected.normal.is_empty() and rejected.large.is_empty(),"Over-limit record rejected without looping")
 poses.free()
 print("NATIVE_RESPONSIVENESS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
