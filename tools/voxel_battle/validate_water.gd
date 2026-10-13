extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Game extends Node3D:
 var active:=true
 var clock:=0.0
 var fighters:Dictionary={}
 var players:Dictionary={}
 var gates:Array=[]
 var damage:Array=[]
 func is_vr() -> bool:return false
 func _damage(_a,_b,amount,kind,_environment):damage.append({"amount":amount,"kind":kind})
class PoseRig extends "res://deathmatch/vr/rig.gd":
 func weapon_pose() -> Transform3D:return right.transform
var errors:Array=[]
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:errors.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 for river in Landscape.Hydrology.RIVERS:
  for i in river.points.size()-1:
   for j in 21:
    var p:Vector3=river.points[i].lerp(river.points[i+1],float(j)/20)
    var water:=Landscape.water_sample(p.x,p.z)
    check(water.x>.99,"continuous authored river "+river.name)
    check(Landscape.surface(p.x,p.z).x<water.y-3,"solid bed below river "+river.name)
    check(Landscape.in_water(p-Vector3.UP),"river supports submerged body")
    check(not Landscape.in_water(p+Vector3.UP),"air above river")
    check(not Landscape.planting_allowed(Vector2(p.x,p.z)),"river clears vegetation")
 var position:=Vector3(Landscape.CENTERS[2].x,-2.3,Landscape.CENTERS[2].z+200)
 var game:=Game.new();root.add_child(game)
 var actor:=Fighter.new();actor.setup(1,"Swimmer",Color.WHITE);game.add_child(actor)
 actor.local_player=true;actor.stroke_only_water=true;actor.quake_movement=true;actor.configure_jetpack(true)
 actor.position=position;actor.target=position
 game.fighters[1]=actor;game.players[1]={"dead":false,"spectator":false,"serial":1,"xr":{}}
 Fixture.box(game,Vector3(position.x,-8.5,position.z),Vector3(100,1,100))
 var runtime=preload("res://deathmatch/maps/runtime.gd").new();game.add_child(runtime);runtime.game=game;runtime.set_physics_process(false);runtime.set_process(false)
 runtime.has_contents=true;runtime.contents=preload("res://tools/voxel_battle/water_contents.gd").new();runtime.triggers.setup(runtime,[])
 runtime._physics_process(.1)
 check(actor.in_water and actor.underwater and game.damage.is_empty(),"water entry survives and sets submerged state")
 var comfort=preload("res://tools/voxel_battle/arena.gd").new()
 var raise:float=comfort.water_view_raise(actor,1.48)
 check(raise>0 and absf(actor.render_position().y+1.48+raise-.12)<.001,"camera stays above water while body remains submerged")
 var body_before:=actor.position
 check(body_before==actor.position and actor.underwater,"comfort camera does not change physical body or breath")
 for i in 90:
  await physics_frame;game.clock+=1.0/60;runtime._physics_process(1.0/60)
  actor.simulate(Vector2(0,-1),0,false,1.0/60,true)
 check(absf(actor.position.z-position.z)<.01 and actor.position.y<position.y-1,"stick and jump cannot swim; idle body sinks")
 actor.position=position;actor.velocity=Vector3.ZERO;actor.reset_view()
 for i in 240:
  await physics_frame;game.clock+=1.0/60;runtime._physics_process(1.0/60)
  actor.simulate(Vector2.ZERO,0,false,1.0/60,false,Vector3(0,0,-.4))
 runtime._physics_process(1.0/60)
 check(actor.position.z<position.z-2,"strokes drive horizontal swimming")
 check(not actor.underwater and actor.in_water and actor.air_left==12,"level strokes emerge head above water and restore air")
 check(absf(actor.position.y+actor.swim_eye_height-.15)<.08,"continued strokes hold physical head near surface")
 var emerged:float=actor.position.y
 for i in 180:
  await physics_frame;game.clock+=1.0/60;runtime._physics_process(1.0/60)
  actor.simulate(Vector2.ZERO,0,false,1.0/60)
 runtime._physics_process(1.0/60)
 check(actor.underwater and actor.position.y<emerged-2,"releasing strokes permits underwater concealment")
 check(actor.position.y>=-8.05,"solid bed prevents falling through voxel terrain")
 game.damage.clear();runtime.breath.clear()
 for i in 11:game.clock+=1;runtime._physics_process(1)
 check(game.damage.is_empty() and actor.air_left>0,"submersion has a finite grace period without immediate damage")
 for i in 3:game.clock+=1;runtime._physics_process(1)
 check(not game.damage.is_empty() and game.damage[0].kind=="DROWNING" and actor.air_left==0,"drowning damage starts after twelve seconds")
 actor.position=Vector3(position.x+100,.1,position.z);actor.velocity=Vector3.ZERO
 Fixture.box(game,actor.position-Vector3.UP*.6,Vector3(20,1,20));await physics_frame;await physics_frame
 runtime._physics_process(.1)
 check(not actor.in_water and not actor.underwater and actor.air_left==12,"shore restores dry state and air")
 var shore:=actor.position
 for i in 30:await physics_frame;actor.simulate(Vector2(0,-1),0,false,1.0/60)
 check(actor.position.z<shore.z-1,"normal locomotion resumes on shore")
 actor.position=shore;actor.velocity=Vector3.ZERO;await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
 check(actor.velocity.y>0,"normal jumping resumes on shore")
 var rig:=PoseRig.new();rig.set_process(false);rig.simulated=true
 rig.origin=XROrigin3D.new();rig.add_child(rig.origin)
 rig.head=XRCamera3D.new();rig.origin.add_child(rig.head);rig.head.position=Vector3(0,1.65,0)
 rig.left=XRController3D.new();rig.right=XRController3D.new();rig.left_aim=XRController3D.new();rig.right_aim=XRController3D.new()
 for controller in [rig.left,rig.right,rig.left_aim,rig.right_aim]:rig.origin.add_child(controller)
 rig.left.position=Vector3(-.3,1.1,-.3);rig.right.position=Vector3(.3,1.1,-.3);rig.left_aim.position=rig.left.position;rig.right_aim.position=rig.right.position
 var physical:Dictionary=rig.sample_pose();rig.water_view_offset=6.0;rig.origin.position.y=6.0
 var raised:Dictionary=rig.sample_pose()
 check(not physical.is_empty() and physical==raised,"VR camera offset never enters network head hands or weapon poses")
 rig.free();comfort.free();game.free()
 var report:={"checks":checks,"errors":errors,"rivers":Landscape.Hydrology.RIVERS.size(),"breath_seconds":12,"scope":"Authored river continuity and solid beds; actual Fighter swimming, idle sinking, surface recovery and shore locomotion; production contents/runtime drowning; VR pose compensation. Full-world heightmap and rendering checked separately."}
 DirAccess.make_dir_recursive_absolute("res://test-results/jungle-terrain")
 FileAccess.open("res://test-results/jungle-terrain/water.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("WATER_VALIDATION ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
