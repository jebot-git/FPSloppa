extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Exit=preload("res://deathmatch/maps/teleport_exit.gd")
var game
var runtime
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func area(at: Vector3,size: Vector3,target: String) -> Area3D:
 var node:=Area3D.new();node.position=at;node.collision_mask=2;node.collision_layer=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.set_meta("server_geometry_bounds",AABB(-size/2,size));node.add_child(shape);game.add_child(node)
 runtime.regions.append({"area":node,"kind":"trigger_teleport","data":{"target":target}});return node
func command(serial: int,seq: int,yaw: float) -> Dictionary:
 return {"input_life":serial,"seq":seq,"move":Vector2(0,-1),"yaw":yaw,"pitch":.2,"fire":false,"weapon":2,"slow":false,"respawn":false}
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.selected_map="qsrc_dm1";game.start_host("Teleport exits",0,100,10,true)
 game.set_process(false);game.set_physics_process(false);game.bots.free();game.bots=null
 game.get_node("Map/MapRuntime").set_physics_process(false);Fixture.setup(game)
 runtime=preload("res://deathmatch/maps/runtime.gd").new();game.add_child(runtime);runtime.game=game;runtime.triggers.setup(runtime,[]);runtime.set_physics_process(false)
 var actor=game.fighters[1];var state: Dictionary=game.players[1]
 for id in game.fighters:game.fighters[id].position=Fixture.point(15,15)
 state.dead=false;state.spectator=false;state.invulnerable=0.;state.input_blocked=false
 var point:=Fixture.point(0,0)+Vector3.UP*.05
 await physics_frame;await physics_frame
 for angle in [0.,90.,180.,270.,45.]:
  var resolved:=Exit.resolve(runtime,{"position":point,"yaw":deg_to_rad(angle)})
  check(not resolved.is_empty() and resolved.position==point and absf(angle_difference(resolved.yaw,deg_to_rad(angle)))<.001,"Clear authored position and heading preserved: "+str(angle))
 check(is_equal_approx(Exit.yaw({"angle":"270"}),-PI/2),"Scalar Quake angle maps to the correct world heading")
 check(is_equal_approx(Exit.yaw({"angle":"0","angles":"20 90 0"}),PI/2),"Vector angles supply yaw instead of falling back to zero")
 var wall=Fixture.box(game,point+Vector3(0,1,-.75),Vector3(4,3,.2));await physics_frame;await physics_frame
 var repaired:=Exit.resolve(runtime,{"position":point,"yaw":0.})
 check(not repaired.is_empty() and cos(repaired.yaw)<-.99 and repaired.position==point,"Immediately wall-facing exit turns toward unobstructed space")
 wall.free();await physics_frame
 var exit_portal:=area(point+Vector3.UP,Vector3(3,2,.4),"unused")
 await physics_frame;await physics_frame
 var behind:=point+Vector3.BACK*.65
 var result:=Exit.resolve(runtime,{"position":behind,"yaw":0.})
 check(not result.is_empty() and result.position.z<point.z-.5 and result.yaw==0.,"Marker behind the portal arrives beyond its front plane")
 check(Exit.resolve(runtime,result).position.is_equal_approx(result.position),"Resolved exit does not creep forward on repeated use")
 for angle in [PI/2,PI/4]:
  exit_portal.rotation.y=angle
  await physics_frame;await physics_frame
  var forward:=Vector3.FORWARD.rotated(Vector3.UP,angle)
  var angled:=Exit.resolve(runtime,{"position":point-forward*.65,"yaw":angle})
  check(not angled.is_empty() and (angled.position-point).dot(forward)>.5 and angled.position.distance_to(point)<.7,"Rotated portal exits on its front side without excessive offset: "+str(angle))
 exit_portal.rotation.y=0.;await physics_frame;await physics_frame
 wall=Fixture.box(game,point+Vector3(0,1,-.35),Vector3(4,3,.1));await physics_frame;await physics_frame
 # The only outward-facing portal direction is obstructed. Resolution may turn
 # back toward free space, but must never tunnel through the wall.
 result=Exit.resolve(runtime,{"position":behind,"yaw":0.})
 check(result.is_empty() or result.position.z>point.z,"Portal correction never crosses a solid wall")
 wall.free();runtime.regions.clear();exit_portal.free();await physics_frame
 var source:=Fixture.point(-8,0)+Vector3.UP*.05
 var entrance:=area(source+Vector3.UP*.8,Vector3(1,2,1),"exit")
 runtime.destinations={"exit":{"position":point,"yaw":PI/2}}
 actor.position=source;actor.velocity=Vector3(8,3,2);actor.blast_velocity=Vector2(20,10)
 state.yaw=PI;state.pitch=1.;state.move=Vector2(0,-1);state.room=Vector3(1,0,0);state.swim=Vector3.UP;state.jump=true;state.jump_pending=true
 var serial: int=state.serial
 for i in 4:await physics_frame
 check(entrance.overlaps_body(actor),"Production teleport is triggered by a physical capsule overlap")
 runtime._physics_process(1./60.)
 check(actor.position==point and actor.target==point and state.serial==serial+1,"Teleport updates position, interpolation target and life atomically")
 check(is_equal_approx(state.yaw,PI/2) and is_equal_approx(actor.rotation.y,PI/2) and game.local_yaw==state.yaw and game.local_pitch==0.,"Authority, body and local camera immediately face the exit")
 check(actor.velocity==Vector3.ZERO and actor.blast_velocity==Vector2.ZERO,"Entrance motion and knockback cannot push the player behind the exit")
 check(state.move==Vector2.ZERO and state.room==Vector3.ZERO and state.swim==Vector3.ZERO and not state.jump and not state.jump_pending,"Old movement, room-scale displacement and jump are discarded")
 var seq: int=state.last_seq+1
 game._accept_input(1,command(serial,seq,PI))
 check(state.yaw==PI/2 and state.move==Vector2.ZERO and state.last_seq<seq,"Delayed entrance input cannot overwrite exit facing or move the player")
 game._accept_input(1,command(state.serial,seq+1,.4))
 check(is_equal_approx(state.yaw,.4) and state.move!=Vector2.ZERO and not state.has("teleport_input_life"),"Fresh input resumes normally after the teleport snapshot")
 for head_turn in [-PI/2,PI/2,PI]:
  var pose={"head":Transform3D(Basis(Vector3.UP,head_turn),Vector3.UP*1.6),"body":{"hips":Transform3D.IDENTITY}}
  var rig:=Exit.rig_yaw(PI/4,pose)
  check(absf(angle_difference(rig+head_turn,PI/4))<.001,"Physical headset turn is included in world exit facing: "+str(head_turn))
 var blocked=Fixture.box(game,point+Vector3.UP,Vector3(1,3,1));await physics_frame;await physics_frame
 check(Exit.resolve(runtime,{"position":point,"yaw":0.}).is_empty(),"Blocked destination is rejected instead of embedding a player")
 blocked.free();game.free();print("TELEPORT_EXITS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
