extends SceneTree
class Fighter extends Node3D:
 func render_position():return position
 func eye_height():return 1.5
class Mock extends Node3D:
 var players: Dictionary={}
 var fighters: Dictionary={}
 var camera:=Camera3D.new()
 var match_mode={"defusal":{"carrier":-1}}
func _initialize():run.call_deferred()
func run():
 var game:=Mock.new();root.add_child(game);game.add_child(game.camera)
 var fighter:=Fighter.new();game.add_child(fighter);game.fighters[-1]=fighter
 game.players[-1]={"dead":false,"spectator":false,"team":0,"yaw":0.,"pitch":0.}
 var wall:=StaticBody3D.new();wall.position=Vector3(0,2,2);game.add_child(wall)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10,4,1);collision.shape=box;wall.add_child(collision)
 for frame in 3:await physics_frame
 var director=preload("res://tools/de_penetration/shoulder_camera.gd").new()
 director.update(game,1./30)
 assert(game.camera.position.distance_to(Vector3(0,1.5,0))<2.,"Wall must retract the shoulder camera")
 var sphere:=SphereShape3D.new();sphere.radius=.22
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.collision_mask=1
 var space=game.get_world_3d().direct_space_state
 for frame in range(360):
  game.players[-1].yaw=sin(frame*.013)*2
  game.players[-1].pitch=sin(frame*.02)*.3
  game.camera.position=Vector3(999,999,999)
  director.update(game,1./30)
  query.transform.origin=game.camera.position
  assert(space.intersect_shape(query,1).is_empty(),"Camera intersects wall")
  assert(game.camera.position.distance_to(fighter.position)<4.,"Camera smoothing used overwritten spectator transform")
 assert(director.clearance_failures==0)
 print("SHOULDER_CAMERA_PASS frames=360 wall retraction, collision clearance, persistent position and aim smoothing")
 quit()
