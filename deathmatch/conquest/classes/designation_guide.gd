extends RefCounted
## Client-only guidance uses the same launch parameters as gameplay.
const Attribution=preload("res://deathmatch/server/attribution.gd")
const Ballistics=preload("res://deathmatch/conquest/classes/ballistics.gd")
static func profile(game,id:int)->Dictionary:
 if not game.classes.alive(id) or game.classes.role(id)!="technician":return {}
 var key:int=game.battery_tanks.key_for(id)
 if key>=0:
  var row:Dictionary=game.battery_tanks.rows[key]
  if row.pilot!=id or row.kind=="transport":return {}
  var rocket:bool=row.kind=="rocket"
  var config:Dictionary=game.battery_tanks.profile(row)
  return {"origin":game.battery_tanks.muzzle(row,0),"inherited":row.velocity*.5,"speed":game.battery_tanks.SPEED if rocket else 40.,"gravity":game.battery_tanks.GRAVITY if rocket else 0.,"fuse":90. if rocket else 10.,"range":game.battery_tanks.MAX_RANGE if rocket else 400.,"direction":row.direction,"pitch_min":config.pitch_min,"pitch_max":config.pitch_max,"vehicle":key}
 var weapon:int=game.players.get(id,{}).get("weapon",-1)
 if weapon not in [0,1,2,3,4,5,9,10,11]:return {}
 var data:Dictionary=game.variant_combat.definition(id,weapon,{})
 var shot:Dictionary=game._shot_solution(id)
 if shot.get("blocked",false):return {}
 return {"origin":shot.origin,"inherited":Vector3.ZERO,"speed":float(data.get("speed",0)),"gravity":float(data.get("gravity",0)),"fuse":float(data.get("fuse",INF)),"range":float(data.get("range",game.armory.data(weapon).get("range",0))),"direction":-game._weapon_transform(id).basis.z,"pitch_min":-90.,"pitch_max":90.,"vehicle":-1}
static func solve(config:Dictionary,target:Vector3,high:bool=false)->Dictionary:
 if config.is_empty():return {}
 var start:Vector3=config.origin;var span:=target-start
 var gravity:float=config.gravity;var speed:float=config.speed
 if span.length()>config.range:return {}
 # Ballistic weapons have a physical trajectory limit, rather than a flat radius.
 if gravity>0:
  var solution:=Ballistics.solve(start,target,speed,gravity,config.inherited,high)
  if solution.is_empty() or solution.time>config.fuse:return {}
  var pitch:float=rad_to_deg(asin(clampf(solution.direction.y,-1,1)))
  if pitch<config.pitch_min or pitch>config.pitch_max:return {}
  return solution
 if span.length()>config.range or span.length()<.01:return {}
 var time:=0.
 if speed>0:
  var inherited:Vector3=config.inherited
  var a:=inherited.length_squared()-speed*speed;var b:float=-2*span.dot(inherited);var c:=span.length_squared()
  if absf(a)<.000001:
   if absf(b)<.000001:return {}
   time=-c/b
  else:
   var disc:=b*b-4*a*c
   if disc<0:return {}
   var first:=(-b-sqrt(disc))/(2*a);var second:=(-b+sqrt(disc))/(2*a)
   time=minf(first,second) if first>0 and second>0 else maxf(first,second)
  if time<=0 or time>config.fuse:return {}
 var direction:Vector3=(span/time-config.inherited).normalized() if time>0 else span.normalized()
 var pitch:float=rad_to_deg(asin(clampf(direction.y,-1,1)))
 if pitch<config.pitch_min or pitch>config.pitch_max:return {}
 return {"direction":direction,"velocity":span/time if time>0 else Vector3.ZERO,"time":time}
static func for_player(game,id:int)->Dictionary:
 var config:=profile(game,id)
 if config.is_empty():return {}
 var candidates:Array=[]
 for row in game.designations.values():
  if row.until>game.clock and row.team==game.players[id].team:candidates.append(row)
 candidates.sort_custom(func(a,b):return config.direction.dot((a.position-config.origin).normalized())>config.direction.dot((b.position-config.origin).normalized()))
 for row in candidates:
  for high in [false,true] if config.gravity>0 else [false]:
   var aimed:=config.duplicate()
   var solution:Dictionary={}
   var hull:Dictionary=game.battery_tanks.rows[config.vehicle].duplicate() if config.vehicle>=0 else {}
   # Preserve the moving-muzzle convergence used by the rocket-tank mortar aid.
   for iteration in 6 if not hull.is_empty() else 1:
    if not hull.is_empty():aimed.origin=game.battery_tanks.muzzle(hull,0)
    solution=solve(aimed,row.position,high)
    if solution.is_empty():break
    if not hull.is_empty():hull.direction=solution.direction
   if solution.is_empty():continue
   if config.gravity>0:
    if not Ballistics.clear(game.get_world_3d().direct_space_state,aimed.origin,solution,config.gravity):continue
   else:
    var hit:Dictionary=Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(aimed.origin,row.position,1),"query.designation_guide.clear.ray")
    if not hit.is_empty() and hit.position.distance_to(row.position)>1.5:continue
   solution.merge({"origin":aimed.origin,"target":row.position,"gravity":config.gravity});return solution
 return {}
static func points(solution:Dictionary)->PackedVector3Array:
 var result:=PackedVector3Array()
 if solution.is_empty():return result
 var previous:Vector3=solution.origin
 for i in 25:
  var t:float=solution.time*(i+1)/25.
  var point:Vector3=solution.target if solution.time==0 else solution.origin+solution.velocity*t-Vector3.UP*solution.gravity*t*t*.5
  result.append_array(PackedVector3Array([previous,point]));previous=point
 var aim:Vector3=solution.origin+solution.direction*8
 var side:Vector3=solution.direction.cross(Vector3.UP).normalized()*.12
 result.append_array(PackedVector3Array([aim-side,aim+side,aim-Vector3.UP*.12,aim+Vector3.UP*.12]))
 return result
