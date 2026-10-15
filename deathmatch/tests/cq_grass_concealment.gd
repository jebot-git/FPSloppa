extends SceneTree
const Cover=preload("res://tools/voxel_battle/grass_cover.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Spotting=preload("res://deathmatch/conquest/classes/spotting.gd")
const Armory=preload("res://deathmatch/conquest/classes/armory.gd")
var checks:=0
var failures:Array=[]
class Actor extends Node3D:
 var stance:="stand"
 func eye_height()->float:return .48 if stance=="prone" else 1.48
class Classes extends RefCounted:
 var states:Dictionary={}
 func alive(_id:int)->bool:return true
 func cloaked(_id:int)->bool:return false
 func role(id:int)->String:return "scout" if id==2 else "shocktroop"
class Vehicles extends RefCounted:
 func mounted(_id:int)->bool:return false
class WeaponData extends RefCounted:
 var armory
 func weapon_data(_owner:int,weapon:int)->Dictionary:return armory.data(weapon)
class Light extends RefCounted:
 func light_fraction()->float:return 0.
class Game extends Node3D:
 var battle_map=null
 var players:Dictionary={1:{"team":0,"dead":false,"spectator":false},2:{"team":1,"dead":false,"spectator":false}}
 var fighters:Dictionary={}
 var classes=Classes.new()
 var battery_tanks=Vehicles.new()
 var clock:=1.
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var source:=Landscape.new();var coord:=Vector2i(13,35);var data:=source.generate_tile(coord);var roots:PackedVector4Array=data.grass
 check(not roots.is_empty(),"Real forest tile contains rendered grass")
 for i in range(0,roots.size(),maxi(1,roots.size()/24)):
  var root:=Vector3(roots[i].x,roots[i].y,roots[i].z)
  check(Cover.contains(root),"Authoritative contact agrees with rendered tuft roots")
  check(not Cover.contains(root+Vector3.UP*4),"Structures above grass do not gain cover")
 var point:=Vector3(roots[0].x,roots[0].y,roots[0].z)
 check(not Cover.contains(Landscape.CENTERS[0]),"Town pad has no grass cover")
 check(not Cover.contains(Vector3(-553,27,-650)),"River channel has no grass cover")
 check(not Cover.contains(Vector3.INF),"Invalid positions cannot claim cover")
 var game:=Game.new();root.add_child(game)
 for id in [1,2]:var actor:=Actor.new();game.add_child(actor);game.fighters[id]=actor
 game.fighters[1].position=point+Vector3(20,0,0);game.fighters[2].position=point
 check(Spotting.detection_scale(game,2)==1.,"Standing in grass retains normal range")
 game.fighters[2].stance="prone"
 check(Spotting.detection_scale(game,2)==.25,"Prone target in grass has 75 percent range reduction")
 check(Spotting.range_for(game,1)*Spotting.detection_scale(game,2)==18.75,"75m observer becomes 18.75m against concealed target")
 check(Spotting.range_for(game,2)*Spotting.detection_scale(game,2)==37.5,"150m scout becomes 37.5m against concealed target")
 var spotting:=Spotting.new();spotting.tick(game)
 check(spotting.spotted.get(2,[0.,0.])[0]==0.,"Target outside reduced range is not spotted")
 game.clock+=.11;game.fighters[1].position=point+Vector3(10,0,0);spotting.tick(game)
 check(spotting.spotted.get(2,[0.,0.])[0]>game.clock,"Nearby concealed target is spotted with LOS")
 game.fighters[1].position=point+Vector3(30,0,0);game.clock+=.11;spotting.tick(game)
 check(spotting.visible(game,1,2),"Existing ten-second spotting memory is preserved")
 game.clock+=10.1;spotting.tick(game);check(not spotting.visible(game,1,2),"Reduced range does not refresh expired memory")
 game.fighters[2].stance="crouch";game.clock+=.11;spotting.tick(game)
 check(spotting.visible(game,1,2),"Crouching does not receive prone concealment")
 game.fighters[2].stance="prone";game.fighters[2].position=Landscape.CENTERS[0]
 check(Spotting.detection_scale(game,2)==1.,"Prone on cleared ground retains normal range")
 game.players[2].team=0;game.fighters[2].position=point;game.fighters[1].position=point+Vector3(99,0,0)
 check(spotting.visible(game,1,2),"Grass concealment leaves allied name/icon range at 100m")
 game.fighters[1].position=point+Vector3(101,0,0)
 check(not spotting.visible(game,1,2),"Allied name/icon cutoff remains 100m")
 game.battle_map={"lighting":Light.new()}
 check(Spotting.range_for(game,1)*Spotting.detection_scale(game,2)==3.75,"Night minimum is reduced by 75 percent")
 game.classes.states[1]={"nv":true,"nb":0.}
 check(Spotting.range_for(game,1)*Spotting.detection_scale(game,2)==12.5,"Night vision still respects grass concealment")
 game.classes.states[1].nb=game.clock+1
 check(Spotting.range_for(game,1)*Spotting.detection_scale(game,2)==0.,"Concealment does not bypass NVG blindness")
 var armory:=Armory.new();armory.select("ut99");var ballistic:Dictionary=armory.data(5);var guided:Dictionary=armory.data(11)
 check(ballistic.speed*ballistic.speed/ballistic.gravity>=200.,"Launcher ballistic envelope reaches at least 200m")
 check(ballistic.fuse>2*ballistic.speed*sin(PI/4)/ballistic.gravity,"Ballistic fuse survives the full 45 degree arc")
 check(guided.speed*guided.fuse>=500.,"Guided missile lifetime supports at least 500m travel")
 var combat=preload("res://deathmatch/conquest/classes/combat.gd").new()
 var weapons:=WeaponData.new();weapons.armory=armory
 combat.game={"armory":armory,"players":{},"match_mode":{"fortress":weapons}}
 for kind in ["light","heavy"]:
  var shot:Dictionary=combat.definition(1,11,{"hover_shot":kind,"turret_shot":true})
  check(shot.speed*shot.fuse>=300. and shot.gravity==0.,kind+" tank has at least 300m effective projectile range")
 check(preload("res://deathmatch/conquest/classes/turrets.gd").RANGE>=150.,"Turret acquisition range is at least 150m")
 check(preload("res://deathmatch/conquest/classes/vehicle_lock.gd").RANGE>=500.,"Guided launcher can acquire a target at 500m")
 # Rendering state is absent; repeated headless contacts are warm-cache queries.
 var begin:=Time.get_ticks_usec()
 for i in 640:Cover.contains(point+Vector3((i%5)*.05,0,0))
 var elapsed:float=(Time.get_ticks_usec()-begin)/1000.
 check(Cover.tiles.size()<=Cover.MAX_TILES,"Authoritative grass cache is bounded")
 game.free();await process_frame
 print("CQ_GRASS_CONCEALMENT ",JSON.stringify({"checks":checks,"failures":failures,"warm_640_queries_ms":elapsed,"sample_tufts":roots.size(),"ballistic_range_m":ballistic.speed*ballistic.speed/ballistic.gravity,"guided_range_m":guided.speed*guided.fuse}));quit(0 if failures.is_empty() else 1)
