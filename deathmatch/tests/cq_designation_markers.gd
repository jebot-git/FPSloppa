extends SceneTree
const Guide=preload("res://deathmatch/conquest/classes/designation_guide.gd")
const Markers=preload("res://deathmatch/conquest/classes/spotted_markers.gd")
const Spotting=preload("res://deathmatch/conquest/classes/spotting.gd")
var checks:=0
var failures:Array=[]
class Classes extends RefCounted:
 var roles:Dictionary={1:"technician",2:"scout",3:"medic",4:"shocktroop",5:"technician"}
 var states:Dictionary={}
 var hidden:Dictionary={}
 func role(id:int)->String:return roles.get(id,"scout")
 func alive(_id:int)->bool:return true
 func cloaked(id:int)->bool:return hidden.has(id)
class Recon extends RefCounted:
 func detected(_id:int,_team:int)->bool:return false
class Vehicles extends RefCounted:
 const SPEED:=sqrt(100000.)
 const GRAVITY:=20.
 const MAX_RANGE:=5000.
 var rows:Dictionary={}
 func key_for(id:int)->int:
  for key in rows:
   if rows[key].pilot==id or rows[key].get("passenger",0)==id:return key
  return -1
 func mounted(id:int)->bool:return key_for(id)>=0
 func muzzle(_row:Dictionary,_barrel:int)->Vector3:return Vector3(0,2,0)
 func profile(row:Dictionary)->Dictionary:return preload("res://deathmatch/conquest/classes/battery_tank.gd").PROFILES[row.kind]
class Weapons extends RefCounted:
 var armory
 func weapon_data(_id:int,weapon:int)->Dictionary:return armory.data(weapon)
class Game extends Node3D:
 var classes=Classes.new()
 var battery_tanks=Vehicles.new()
 var spotting=Spotting.new()
 var recon_drone=Recon.new()
 var clock:=1.
 var headless:=false
 var active:=true
 var players:Dictionary={}
 var fighters:Dictionary={}
 var designations:Dictionary={}
 var armory=preload("res://deathmatch/conquest/classes/armory.gd").new()
 var variant_combat=preload("res://deathmatch/conquest/classes/combat.gd").new()
 func _shot_solution(_id:int)->Dictionary:return {"origin":Vector3(0,2,0),"blocked":false}
 func _weapon_transform(_id:int)->Transform3D:return Transform3D.IDENTITY
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=Game.new();root.add_child(game);game.armory.select("ut99")
 for id in range(1,6):
  game.players[id]={"team":0 if id==1 else 1,"dead":false,"spectator":false,"weapon":5}
  var actor:=Node3D.new();game.add_child(actor);game.fighters[id]=actor
 var weapons:=Weapons.new();weapons.armory=game.armory
 game.variant_combat.game={"armory":game.armory,"players":game.players,"match_mode":{"fortress":weapons}}
 var profile:=Guide.profile(game,1)
 check(profile.speed==55. and profile.gravity==12. and profile.fuse==15.,"T1 helper reads current gameplay launch parameters")
 check(not Guide.solve(profile,Vector3(200,2,0)).is_empty(),"T1 helper reaches 200m on ballistic curve")
 check(Guide.solve(profile,Vector3(300,2,0)).is_empty(),"T1 helper rejects unreachable 300m")
 var solution:=Guide.solve(profile,Vector3(200,2,0));var impact:Vector3=profile.origin+solution.velocity*solution.time-Vector3.UP*profile.gravity*solution.time*solution.time*.5
 check(impact.distance_to(Vector3(200,2,0))<.01,"Guide integrates to the designated impact point")
 for weapon in [0,1,2,3,4,9,10,11]:
  game.players[1].weapon=weapon;profile=Guide.profile(game,1)
  check(not profile.is_empty() and not Guide.solve(profile,profile.origin+Vector3(0,0,-minf(profile.range*.8,50.))).is_empty(),"Current weapon supports range-limited direct guide: "+str(weapon))
  check(Guide.solve(profile,profile.origin+Vector3(0,0,-profile.range-1.)).is_empty(),"Weapon guide rejects target beyond range: "+str(weapon))
 game.players[1].weapon=7;check(Guide.profile(game,1).is_empty(),"Repair tool has no weapon aiming aid")
 game.classes.roles[1]="medic";check(Guide.profile(game,1).is_empty(),"Only technicians receive guide")
 game.classes.roles[1]="technician";game.players[1].weapon=5
 for kind in ["light","heavy","rocket","transport"]:
  game.battery_tanks.rows[10]={"pilot":1,"kind":kind,"velocity":Vector3.ZERO,"direction":Vector3.FORWARD,"position":Vector3.ZERO,"hp":100,"team":0}
  profile=Guide.profile(game,1)
  if kind=="transport":check(profile.is_empty(),"Unarmed driven transport has no aiming guide")
  elif kind=="rocket":
   check(not Guide.solve(profile,Vector3(0,2,-4000.)).is_empty(),"Rocket tank helper reaches real 5km ballistic envelope")
   check(Guide.solve(profile,Vector3(0,2,-5001.)).is_empty(),"Rocket tank helper enforces weapon envelope")
  else:
   check(not Guide.solve(profile,Vector3(0,2,-399.)).is_empty(),kind+" guide supports 399m within shell life")
   check(Guide.solve(profile,Vector3(0,2,-401.)).is_empty(),kind+" guide rejects 401m beyond shell life")
 game.battery_tanks.rows[10].pilot=2;game.battery_tanks.rows[10].passenger=1
 check(Guide.profile(game,1).is_empty(),"Passenger does not receive driven vehicle's guide")
 game.battery_tanks.rows.clear()
 game.designations={1:{"until":2.,"team":0,"position":Vector3(0,2,-300)},2:{"until":2.,"team":0,"position":Vector3(0,2,-200)},3:{"until":0.,"team":0,"position":Vector3(0,2,-20)},4:{"until":2.,"team":1,"position":Vector3(0,2,-30)}}
 solution=Guide.for_player(game,1)
 check(not solution.is_empty() and solution.target==Vector3(0,2,-200),"Unreachable first designation does not hide reachable allied target")
 check(Guide.points(solution).size()==54,"Guide includes trajectory and aim cross")
 game.players[1].weapon=11
 game.designations={1:{"until":2.,"team":0,"position":Vector3(0,2,-100)},2:{"until":2.,"team":0,"position":Vector3(100,2,-10)}}
 var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6,6,1);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.position=Vector3(0,2,-50)
 await physics_frame;await physics_frame
 solution=Guide.for_player(game,1)
 check(not solution.is_empty() and solution.target==Vector3(100,2,-10),"Obstructed preferred target falls back to a clear allied designation")
 wall.queue_free();await physics_frame
 for id in range(2,6):game.spotting.reveal(id,0,game.clock)
 var targets:=Markers.targets(game,1)
 check(targets.size()==4,"Four spotted enemy class markers")
 for id in range(2,6):check(targets["player:"+str(id)].kind==game.classes.role(id),"Enemy marker differentiates class: "+str(id))
 game.battery_tanks.rows[10]={"pilot":2,"kind":"heavy","position":Vector3.ZERO,"hp":500,"team":1}
 targets=Markers.targets(game,1)
 check(targets.has("vehicle:10") and targets["vehicle:10"].kind=="heavy" and not targets.has("player:2"),"Spotted driver becomes vehicle marker instead of exposed infantry class")
 game.battery_tanks.rows[10].pilot=0;check(not Markers.targets(game,1).has("vehicle:10"),"Empty enemy hull has no driven marker")
 game.battery_tanks.rows[10].pilot=2;game.classes.hidden[2]=true
 check(not Markers.targets(game,1).has("vehicle:10"),"Markers respect existing cloak visibility")
 game.classes.hidden.clear();game.clock=12.
 check(Markers.targets(game,1).is_empty(),"Expired spotting memory hides every enemy marker")
 game.clock=2.;game.players[3].team=0
 check(not Markers.targets(game,1).has("player:3"),"Allies retain existing class badges without enemy markers")
 var markers:=Markers.new();game.add_child(markers);markers.set_process(false);markers.sync(targets)
 check(markers.markers.size()==targets.size(),"Markers instantiate for eligible targets")
 for kind in Markers.TITLES:check(load(Markers.ROOT+kind+".svg") is Texture2D,"Authored marker imports: "+kind)
 markers.sync({});check(markers.markers.is_empty(),"Hidden/removed targets release markers")
 game.free();await process_frame
 print("CQ_DESIGNATION_MARKERS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
