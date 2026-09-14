extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
 g.start_host("Tracked movement test",0,100,10,true,"dm");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.seated=false;rig.origin_offset=Vector3.ZERO;rig.origin.transform=Transform3D.IDENTITY
 g.bindings.physical_crouch=true;g.bindings.physical_prone=true;g.bindings.tracked_leg_animation=true
 var actor=g.fighters[1];var s:Dictionary=g.players[1];var sequence:=10000
 var body:=XRBodyTracker.new();body.name="/user/movement_test_body";body.has_tracking_data=true;XRServer.add_tracker(body)
 for entry in [[XRBodyTracker.JOINT_HIPS,Vector3(0,.92,0)],[XRBodyTracker.JOINT_LEFT_FOOT,Vector3(-.13,.08,0)],[XRBodyTracker.JOINT_RIGHT_FOOT,Vector3(.13,.08,0)]]:
  body.set_joint_transform(entry[0],Transform3D(Basis.IDENTITY,entry[1]));body.set_joint_flags(entry[0],XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
 for posture in [["stand",1.65,9.4],["crouch",1.,5.17],["prone",.45,1.692],["prone",.15,1.692]]:
  actor.position=Fixture.point();actor.velocity=Vector3.ZERO;s.dead=false;s.input_blocked=false
  rig.head.position=Vector3(0,posture[1],0)
  for frame in 90:
   await physics_frame;rig._process(1./60.)
   var command:Dictionary=g._local_command();command.move=Vector2.UP;command.seq=sequence;sequence+=1
   g.clock+=1./60.;g._accept_input(1,command);g._server_tick(1./60.)
  var speed:float=Vector2(actor.velocity.x,actor.velocity.z).length()
  print("TRACKED_STANCE ",JSON.stringify({"posture":posture[0],"height":actor.collision_height,"speed":speed,"assist":actor.tracked_leg_animation,"grounded":actor.is_supported(),"feet":actor.xr_pose.get("body",{}).keys(),"weight":actor.avatar.gait.assist_weight}))
  check(actor.stance==posture[0] and absf(speed-float(posture[2]))<.1,"Tracked "+posture[0]+" selects correct authoritative speed")
  if posture[0]=="stand":check(actor.avatar.gait.assist_weight>.9,"Standing tracked feet animate during forward locomotion")
 XRServer.remove_tracker(body);g.disconnect_game();g.free();await process_frame
 print("TRACKED_LOCOMOTION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
