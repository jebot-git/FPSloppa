extends SceneTree
class Fighter extends Node3D:
 func render_position():return position
class Mock extends Node3D:
 var players: Dictionary={}
 var fighters: Dictionary={}
 var camera:=Camera3D.new()
func _initialize():run.call_deferred()
func run():
 var game:=Mock.new();root.add_child(game);game.add_child(game.camera)
 var map:=Node3D.new();map.name="Map";game.add_child(map)
 for i in range(5):
  var f:=Fighter.new();game.add_child(f);f.position=Vector3(i*2,0,0)
  game.players[-i-1]={"dead":false,"spectator":false,"team":0};game.fighters[-i-1]=f
 var director=load("res://tools/de_penetration/overview_camera.gd").new()
 director.update(game,1./30)
 var previous: Vector3=game.camera.position
 var maximum_speed:=0.
 for frame in range(600):
  for id in game.fighters:game.fighters[id].position+=Vector3(.08,0,.03)
  # Simulate the base game's camera resetting to its free spectator position.
  game.camera.position=Vector3(1000,-1000,1000)
  if frame==180:game.players[-1].dead=true
  if frame==300:game.players[-2].dead=true
  director.update(game,1./30)
  var speed: float=previous.distance_to(game.camera.position)*30
  maximum_speed=maxf(maximum_speed,speed)
  assert(speed<=16.01,"Camera speed exceeded the transition limit")
  assert(game.camera.position.y>director.focus.y+10,"Camera lost its overhead angle")
  previous=game.camera.position
 print("OVERVIEW_CAMERA_PASS frames=600 maximum_speed=",maximum_speed," persistent smoothing, casualties, overhead angle")
 quit()
