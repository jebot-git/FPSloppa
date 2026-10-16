extends SceneTree
class Suite extends "res://tools/voxel_battle/grass_test_suite.gd":
 var finishes:=0
 func reset_counters()->void:pass
 func finish(_reason:String)->void:capture=false;finishes+=1
class Grass extends RefCounted:
 var selection_enabled:=true
class Map extends RefCounted:
 var grass=Grass.new()
 var environment_selection_enabled:=true
class HUD extends RefCounted:
 var suite
 var closes:=0
 func show_menu(_open:bool)->void:
  closes+=1
  suite.start_capture() # Repeat the active XR button synchronously on hide.
  suite.toggle_capture() # Also defend the legacy toggle / duplicate input.
class Game extends Node:
 var battle_map=Map.new()
 var hud=HUD.new()
 var menu_open:=true
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=Game.new();root.add_child(game)
 var suite:=Suite.new();game.add_child(suite);suite.set_process(false);suite.game=game;game.hud.suite=suite
 # Avoid the fixture RPC, but exercise the live input guard rather than check mode.
 suite.checking=true;suite.toggle_capture();suite.checking=false
 await process_frame;await process_frame
 check(suite.capture and suite.take==1 and suite.finishes==0,"reentrant menu-close input cannot cancel the new take")
 check(game.hud.closes==1 and not game.menu_open,"menu closes after capture starts")
 suite.start_capture();check(suite.take==1,"repeated START action is idempotent")
 suite.action_deadline_us=0;suite.toggle_capture()
 check(not suite.capture and suite.finishes==1,"intentional later toggle stops capture once")
 game.free();await process_frame
 print("CQ_GRASS_RECORDING ",JSON.stringify({"checks":4,"failures":failures}));quit(0 if failures.is_empty() else 1)
