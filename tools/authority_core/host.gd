extends Node3D
## Standalone infantry authority fixture. Deliberately separate from production CQ admission.
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Metadata=preload("res://deathmatch/native/cq_metadata.gd")
const Reload=preload("res://deathmatch/conquest/classes/reload_state.gd")
const Runtime=preload("res://deathmatch/native/runtime.gd")
var authority
var ai_timings:Array=[]
var mode_timings:Array=[]
var validator
var cq_mode:=OS.get_cmdline_user_args().has("--cq-core")
var tracked:=OS.get_cmdline_user_args().has("--tracked")
var stress:=OS.get_cmdline_user_args().has("--stress-test")
var jungle:=OS.get_cmdline_user_args().has("--jungle-map")
var player_role:=0
var player_weapon:=4
var native_map
var reach_profile:Dictionary={}
var assembly_size:=0
var publication_bytes:=0
var sent_parts:=0
var finish_acks:Dictionary={}
var warm_seconds:=8.
var native_baseline:Dictionary={}
var sequence_baseline:=-1
var animation_sequence:=0
var transport_stats:Array=[]
var next_transport:=0
var rpc_inputs:=0
var rpc_baseline:=0
var warm_inputs:=0
var received_baseline:=0
var server:=false
var expected:=32
var seconds:=120.0
var life:=0
var sequence:=0
var received:=0
var wire_bytes:=0
var last_tick:=-1
var bad_frames:=0
var disconnected:=0
var transport_closed:=false
var started:=0
var ready_clients:=0
var joined:=0
var last_frame_tick:=-1
var timings:Array[Vector4]=[]
var report_path:=""
var wall_start:=0
var finalising:=false
var checks:=0
var assembly_tick:=-1
var pieces:Array[PackedByteArray]=[]
var piece_count:=0
var piece_bytes:=0
func setup(is_server:bool,players:int,duration:float,report:String="")->void:
 if Runtime.available("FPSCodec"):validator=ClassDB.instantiate("FPSCodec")
 server=is_server;expected=players;seconds=duration;report_path=report;wall_start=Time.get_ticks_msec()
 if server:
  if not Runtime.available("FPSAuthority"):
   push_error("FPSAuthority unavailable");get_tree().quit(1);return
  if tracked:reach_profile=preload("res://deathmatch/avatars/ut_format.gd").read("res://deathmatch/avatars/models/base/soldier.utavatar").manifest.ik_profile
  authority=ClassDB.instantiate("FPSAuthority")
  authority.configure_world(self)
  if cq_mode:
   if not authority.configure_cq({"squads":jungle,"day_cycle":true,"auto_respawn":true}):push_error("CQ core configuration failed");get_tree().quit(1);return
   if not authority.configure_terrain(Metadata.terrain()):push_error("terrain import failed");get_tree().quit(1);return
   var objectives=preload("res://deathmatch/conquest/frontier/objectives.gd").new()
   for site in objectives.sites:authority.configure_zone(site.position,3.)
  if jungle:
   native_map=preload("res://tools/voxel_battle/map.gd").new();add_child(native_map);native_map.build(false)
   if native_map.lighting:
    var lamps:=PackedVector3Array()
    for row in native_map.lighting.metadata.get("lamps",[]):lamps.append(Vector3(row.position[0],row.position[1],row.position[2]))
    authority.configure_lamps(lamps)
  else:
   _box(Vector3(0,-.5,0),Vector3(256,1,256))
   for x in [-24.,24.]:_box(Vector3(x,1.5,0),Vector3(1,3,96))
   _box(Vector3(0,.7,-25),Vector3(12,.5,10),-.14)
   _box(Vector3(12,1.1,0),Vector3(6,.2,8))
  if cq_mode:
   for spec in preload("res://deathmatch/conquest/classes/battery_tank.gd").placements():
    var kind:int=["rocket","light","heavy","transport"].find(spec.kind)
    var vehicle:=CharacterBody3D.new();vehicle.position=spec.position if jungle else Vector3((kind-1)*12.,.05,-35.);var shape:=BoxShape3D.new();shape.size=preload("res://deathmatch/conquest/classes/battery_tank.gd").PROFILES[spec.kind].size
    var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=shape.size.y*.5;vehicle.add_child(collider);add_child(vehicle)
    if authority.attach_vehicle(kind,vehicle,float(spec.yaw),int(spec.team))<0:push_error("native vehicle admission failed");get_tree().quit(1);return
  multiplayer.peer_connected.connect(_join)
  multiplayer.peer_disconnected.connect(_leave)
 else:
  multiplayer.server_disconnected.connect(func():
   transport_closed=true
   if not finalising:disconnected+=1;finalising=true)
func _box(at:Vector3,size:Vector3,tilt:float=0)->void:
 var solid:=StaticBody3D.new();solid.position=at;solid.rotation.x=tilt;solid.collision_layer=1;solid.collision_mask=3
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;solid.add_child(collider);add_child(solid)
func _join(id:int)->void:
 if joined>=expected:return
 var index:=joined;joined+=1
 var actor:=CharacterBody3D.new();actor.position=Vector3((index%8-3.5)*4,0,(index/8-3.5)*5);actor.collision_layer=2;actor.collision_mask=3
 if jungle:actor.position=native_map.spawn_positions[index%native_map.spawn_positions.size()]
 var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;collider.shape=shape;collider.position.y=.83;actor.add_child(collider);add_child(actor);actor.set_meta("peer",id)
 var serial:int=authority.attach_actor(id,actor,collider,index%2 if cq_mode else index%2+1,1<<4,PackedInt32Array([10000,10000,10000,10000]))
 if serial==0:push_error("native admission failed");get_tree().quit(1);return
 var role:int=index%4 if cq_mode else 0
 var weapon:int=[4,9,4,5][role] if cq_mode else 4
 if cq_mode:
  if not authority.configure_player(id,serial,{"role":role,"xp":[7500,7500,7500,7500],"utility":15}):push_error("native class admission failed");get_tree().quit(1);return
 if tracked:
  if not authority.configure_reach(id,reach_profile):push_error("native reach admission failed");get_tree().quit(1);return
 if stress and not authority.configure_stress(id,true):push_error("native stress configuration failed");get_tree().quit(1);return
 if cq_mode and jungle:
  authority.request_action(id,serial,0,11,-1,0,0);authority.request_action(id,serial,1,12,0,0,0)
 _admit.rpc_id(id,serial,role,weapon)
func _leave(id:int)->void:
 if not finalising:
  disconnected+=1
 var state:Dictionary=authority.inspect(id)
 if not state.is_empty():authority.detach_actor(id,state.life)
 for actor in get_children():
  if actor is CharacterBody3D and actor.get_meta("peer",0)==id:actor.queue_free()
@rpc("authority","call_remote","reliable",0)
func _admit(serial:int,role:int,weapon:int)->void:
 life=serial;player_role=role;player_weapon=weapon;_ready_client.rpc_id(1)
@rpc("any_peer","call_remote","reliable",0)
func _ready_client()->void:
 if not server:return
 var id:=multiplayer.get_remote_sender_id()
 var actor_state:Dictionary=authority.inspect(id)
 if actor_state.is_empty():return
 # Exactly one readiness acknowledgement per peer.
 for actor in get_children():
  if actor is CharacterBody3D and actor.get_meta("peer",0)==id:
   if actor.has_meta("ready"):return
   actor.set_meta("ready",true);ready_clients+=1
 if ready_clients==expected:
  started=Time.get_ticks_msec()+int(warm_seconds*1000);_begin.rpc();print("AUTHORITY_READY ",expected)
@rpc("authority","call_remote","reliable",0)
func _begin()->void:started=Time.get_ticks_msec()+int(warm_seconds*1000)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _command(command:PackedByteArray)->void:
 if server:rpc_inputs+=1;authority.submit_packet(multiplayer.get_remote_sender_id(),command)
@rpc("authority","call_remote","unreliable",2)
func _frame_part(tick:int,index:int,count:int,size:int,bytes:PackedByteArray)->void:
 if tick<=last_tick or tick<assembly_tick:return
 if count<1 or count>1093 or size<14 or size>Codec.MAX_FRAME or index<0 or index>=count or bytes.size()>960:bad_frames+=1;return
 if tick!=assembly_tick:
  assembly_tick=tick;pieces.clear();pieces.resize(count);piece_count=0;piece_bytes=0;assembly_size=size
 if pieces.size()!=count or assembly_size!=size:bad_frames+=1;return
 if not pieces[index].is_empty():return
 pieces[index]=bytes;piece_count+=1;piece_bytes+=bytes.size()
 if piece_bytes>Codec.MAX_FRAME:bad_frames+=1;return
 if piece_count!=count:return
 var packed:=PackedByteArray()
 for piece in pieces:packed.append_array(piece)
 var bytes_frame:=packed.decompress(assembly_size,FileAccess.COMPRESSION_FASTLZ)
 if not validator or not validator.validate_authority_frame(bytes_frame,expected,tick):bad_frames+=1;return
 # Only the local recipient's life is needed by a load peer. Every field and TLV
 # was checked above; semantic presentation is tested independently.
 for row in expected:
  var offset:=14+row*104
  if bytes_frame.decode_s64(offset)==multiplayer.get_unique_id():life=bytes_frame.decode_u32(offset+8);break
 last_tick=tick;received+=1;wire_bytes+=piece_bytes
func _physics_process(_delta:float)->void:
 if finalising or (not server and transport_closed):return
 var now:=Time.get_ticks_msec()
 if now-wall_start>int((seconds+45)*1000):push_error("authority fixture timeout");get_tree().quit(1);return
 if server:
  var begin:=Time.get_ticks_usec()
  if not authority.advance():push_error("native tick contract rejected");get_tree().quit(1);return
  var metrics:Dictionary=authority.metrics()
  var tick:int=metrics.tick
  # Only materialise one shared packed frame on publication, then fan out via Godot transport.
  if started>0 and (tick*2)/3!=((tick-1)*2)/3:
   var frame:PackedByteArray=authority.snapshot();var frame_tick:=frame.decode_u64(4)
   if frame_tick!=last_frame_tick:
    var packed:=frame.compress(FileAccess.COMPRESSION_FASTLZ);var parts:=ceili(packed.size()/960.)
    for index in parts:_frame_part.rpc(frame_tick,index,parts,frame.size(),packed.slice(index*960,mini((index+1)*960,packed.size())))
    publication_bytes+=packed.size();sent_parts+=parts
    last_frame_tick=frame_tick
  var total:=Time.get_ticks_usec()-begin
  if started>0 and now>=started:
   if native_baseline.is_empty():native_baseline=metrics.duplicate();rpc_baseline=rpc_inputs
   timings.append(Vector4(total,metrics.movement_us,metrics.combat_us,metrics.snapshot_us));ai_timings.append(metrics.ai_us);mode_timings.append(metrics.mode_us)
   if now-started>=int(seconds*1000):_finish()
 elif started>0:
  if now>=started and sequence_baseline<0:sequence_baseline=sequence;received_baseline=received
  sequence+=1
  animation_sequence=sequence-sequence_baseline if sequence_baseline>=0 else 0
  if now>=next_transport:
   next_transport=now+1000
   var peer=multiplayer.multiplayer_peer.get_peer(1)
   transport_stats.append({"measured":now>=started,"rtt":peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"loss":peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS),"throttle":peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),"sequence":sequence})
  var phase:=float(multiplayer.get_unique_id()%97)
  var command:Dictionary={"life":life,"seq":sequence,"move":Vector2(sin(sequence*.013+phase)*.35,cos(sequence*.009+phase)*.35),"yaw":phase+sin(sequence*.003),"pitch":.6,"weapon":player_weapon,"fire":animation_sequence%300>=260 if player_weapon==5 else animation_sequence%300 in range(60,150),"jump":sequence%200==1,"reload":sequence%150==100,"slow":false,"crouch":sequence%400>280,"prone":sequence%800>720,"blocked":false,"view_time":float(last_tick)/30.-.1 if last_tick>=0 else -1.}
  if player_weapon in [2,9,10]:command.fire=command.fire and animation_sequence%24<3
  if sequence_baseline<0:command.move=Vector2.ZERO;command.jump=false;command.reload=false;command.fire=false
  if tracked:tracked_command(command)
  _command.rpc_id(1,Codec.encode_input(command))
  if cq_mode:
   if animation_sequence%600==5 and player_role==1:_action.rpc_id(1,life,sequence,0)
   if animation_sequence%600==15 and player_role==2:_action.rpc_id(1,life,sequence,2)
   if animation_sequence%600==20 and player_role==2:_action.rpc_id(1,life,sequence,3)
func tracked_command(c:Dictionary)->void:
 var left:bool=multiplayer.get_unique_id()%2==1;var step:=animation_sequence%300
 var basis:=Basis(Vector3.RIGHT,.6);var base:=Vector3(-.3 if left else .3,1.1,-.3)
 var geometry:int=12 if player_weapon in [5,11] else 2 if player_weapon in [2,9,3] else 7
 var point:Vector3=base+basis*(Reload.MAG_POINTS[geometry]*.65);var support:=point;var grip:=false
 if step>=3 and step<16:
  grip=true
  var draw:=minf(maxf(step-3,0)*.03,.12) if step<9 else maxf(0,.12-(step-9)*.025)
  support+=basis*(Vector3.LEFT*draw if geometry==12 else Vector3.DOWN*draw)
 if step>=22 and step<=30:support=Vector3(.29 if left else -.29,.965,0).lerp(point,clampf((step-24)/6.,0,1));grip=step>=23
 if step>=33 and step<=40:
  support=base+basis*(Vector3(.04,.09,.055)*.65+Vector3.UP*.02);grip=step<40;support+=basis*Vector3(0,0,[0.,0.,.025,.05,.065,.04,.015,0.][step-33])
 var weapon:=Transform3D(basis,base);var hand:=Transform3D(Basis.IDENTITY,support)
 c.xr={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":weapon if left else hand,"right":hand if left else weapon,"weapon":weapon,"offhand_weapon":hand,"height":1.65,"left_handed":left};c.vr_device=true;c.reload_grip=grip;c.reload=step==19
@rpc("any_peer","call_remote","reliable",0)
func _action(serial:int,seq:int,kind:int)->void:
 if server:authority.request_action(multiplayer.get_remote_sender_id(),serial,seq,kind)
func _finish()->void:
 finalising=true
 var total:Array=[];var movement:Array=[];var combat:Array=[];var snapshot:Array=[]
 for row in timings:total.append(row.x);movement.append(row.y);combat.append(row.z);snapshot.append(row.w)
 var native:Dictionary=authority.metrics();var warm:Dictionary={}
 for key in ["accepted","rejected","overflow","shots","damage","deaths","projectile_full"]:
  warm[key]=native_baseline.get(key,0);native[key]-=warm[key]
 var result:Dictionary={"warmup_seconds":warm_seconds,"warmup_native":warm,"rpc_inputs":rpc_inputs-rpc_baseline,"fixture":"native-cq-jungle-jolt-enet" if jungle else "native-cq-jolt-enet" if cq_mode else "native-infantry-jolt-enet","players":expected,"seconds":(Time.get_ticks_msec()-started)/1000.,"ticks":timings.size(),"hz":timings.size()/((Time.get_ticks_msec()-started)/1000.),"callback_us":_distribution(total),"movement_and_collision_us":_distribution(movement),"combat_and_queries_us":_distribution(combat),"frame_encoding_us":_distribution(snapshot),"native":native,"disconnected":disconnected,"physics":"Godot Jolt","production_cq":false,"stress_infinite_reserve_invulnerable":stress,"xr":tracked,"cq_gameplay":cq_mode,"jungle_map":jungle,"compressed_publication_bytes":publication_bytes,"snapshot_parts":sent_parts}
 result["ai_us"]=_distribution(ai_timings);result["cq_mode_us"]=_distribution(mode_timings)
 var by_class:Dictionary={}
 for actor in get_children():
  if not actor is CharacterBody3D or not actor.has_meta("peer"):continue
  var state:Dictionary=authority.inspect(actor.get_meta("peer"))
  if not state.is_empty():by_class[state.class_state.role]=int(by_class.get(state.class_state.role,0))+int(state.shots)
 result["shots_by_class_current_life"]=by_class
 if not report_path.is_empty():var f:=FileAccess.open(report_path,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"))
 print("AUTHORITY_RESULT ",JSON.stringify(result));_done.rpc()
 var deadline:=Time.get_ticks_msec()+15000
 while finish_acks.size()<expected and Time.get_ticks_msec()<deadline:await get_tree().process_frame
 await get_tree().create_timer(.3).timeout
 get_tree().quit(0 if disconnected==0 and ready_clients==expected else 1)
@rpc("authority","call_remote","reliable",0)
func _done()->void:
 finalising=true;warm_inputs=maxi(0,sequence_baseline);_finished_ack.rpc_id(1)
@rpc("any_peer","call_remote","reliable",0)
func _finished_ack()->void:
 if server:finish_acks[multiplayer.get_remote_sender_id()]=true
func _distribution(values:Array)->Dictionary:
 values.sort();var sum:=0.
 for v in values:sum+=v
 return {"mean":sum/maxi(1,values.size()),"p50":values[int((values.size()-1)*.5)],"p95":values[int((values.size()-1)*.95)],"max":values[-1]}
