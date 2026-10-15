extends SceneTree
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
class Game extends Node:
 var clock:=10.0
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 for kind in ["transport","rocket","light","heavy"]:
  var game:=Game.new();root.add_child(game)
  var tanks:=Tanks.new();game.add_child(tanks);tanks.game=game
  var spawn:={"poi":"test","position":Vector3(4,0,5),"yaw":.7,"team":0,"kind":kind}
  tanks.rows[0]=tanks.spawn_row(spawn);tanks.body(0)
  tanks.rows[0].position=Vector3(50,0,60);tanks.rows[0].team=1;tanks.rows[0].yaw=2.0;tanks.rows[0].reload_at=999.0
  tanks.destroy(0)
  var deadline:float=game.clock+(120.0 if kind=="transport" else 180.0)
  check(tanks.rows[0].respawn_at==deadline,"correct timer "+kind)
  game.clock+=1;tanks.destroy(0)
  check(tanks.rows[0].respawn_at==deadline,"repeated destruction leaves deadline unchanged "+kind)
  game.clock=deadline-1.0/30;tanks.tick(1.0/30)
  check(tanks.rows[0].hp==0 and tanks.bodies[0].collision_layer==0,"wreck remains unavailable before timer "+kind)
  game.clock=deadline;tanks.tick(1.0/30)
  var row:Dictionary=tanks.rows[0]
  check(row.hp==Tanks.PROFILES[kind].hp and row.rounds==Tanks.PROFILES[kind].capacity,"full health and ammo "+kind)
  check(row.position==spawn.position and row.yaw==spawn.yaw and row.team==spawn.team,"original placement and ownership "+kind)
  check(row.pilot==0 and row.seats==[0,0,0,0,0,0,0,0] and row.respawn_at==0.0 and row.reload_at==0.0,"clean respawn state "+kind)
  check(tanks.bodies[0].collision_layer==1 and tanks.bodies[0].velocity==Vector3.ZERO,"collision restored "+kind)
  game.queue_free();await process_frame
 print("CQ_VEHICLE_RESPAWN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
