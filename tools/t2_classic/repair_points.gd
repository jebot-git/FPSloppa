extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var space: PhysicsDirectSpaceState3D
var shape:=CapsuleShape3D.new()
func _initialize():run.call_deferred()
func v(a):return Vector3(a[0],a[1],a[2])
func array(p: Vector3):return [p.x,p.y,p.z]
func clear(point: Vector3)->bool:
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=1;q.transform.origin=point+Vector3.UP*.90
 return space.intersect_shape(q).is_empty()
func support(point: Vector3)->bool:
 var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.1,point-Vector3.UP*.3,1))
 return not hit.is_empty() and hit.normal.y>.55
func run():
 var key: String=OS.get_cmdline_user_args()[0]
 var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/T2Classic/"+key+"/probes.json"))
 var level:=Maps.read("res://maps/"+key+".bsp");assert(level!=null)
 root.add_child(level);await physics_frame;await physics_frame
 space=level.get_world_3d().direct_space_state;shape.radius=.38;shape.height=1.75
 var repairs: Array=[];var unresolved: Array=[]
 for category in ["spawns","flags","stations"]:
  for index in probes[category].size():
   var row: Dictionary=probes[category][index];var point: Vector3=v(row.position)
   if category=="stations" and row.kind=="vehicle":continue
   if clear(point) and support(point):continue
   var best:=Vector3.INF;var cost:=INF
   for radius in [0.,.5,1.,1.5,2.,3.,4.,6.,8.,12.,16.]:
    if category=="flags" and radius>1.:break
    for angle in 16:
     var offset: Vector3=Vector3(cos(angle*TAU/16),0,sin(angle*TAU/16))*radius
     var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+offset+Vector3.UP*(32 if category=="spawns" else 2),point+offset-Vector3.UP*(32 if category=="spawns" else 4),1))
     if hit.is_empty() or hit.normal.y<.60:continue
     var candidate: Vector3=hit.position+Vector3.UP*.09
     if clear(candidate) and candidate.distance_squared_to(point)<cost:best=candidate;cost=candidate.distance_squared_to(point)
    if best!=Vector3.INF:break
   if best==Vector3.INF and category=="spawns":
    for other in probes.spawns:
     if other.team!=row.team or not clear(v(other.position)) or not support(v(other.position)):continue
     for radius in [2.,4.,8.,12.]:
      for angle in 16:
       var near: Vector3=v(other.position)+Vector3(cos(angle*TAU/16),0,sin(angle*TAU/16))*radius
       var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(near+Vector3.UP*8,near-Vector3.UP*8,1))
       if hit.is_empty() or hit.normal.y<.60:continue
       var candidate: Vector3=hit.position+Vector3.UP*.09
       var separated:=true
       for spawn in probes.spawns:
        if candidate.distance_to(v(spawn.position))<1.5:separated=false
       for fix in repairs:
        if candidate.distance_to(v(fix.to))<1.5:separated=false
       if separated and clear(candidate) and candidate.distance_squared_to(point)<cost:best=candidate;cost=candidate.distance_squared_to(point)
   if best==Vector3.INF:unresolved.append([category,index,row])
   else:repairs.append({"category":category,"index":index,"from":row.position,"to":array(best)})
 var result:={"id":key,"repairs":repairs,"unresolved":unresolved}
 FileAccess.open("res://test-results/t2-classic/"+key+"/repairs.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("CLASSIC_SURVEY ",JSON.stringify(result));level.free();quit(0 if unresolved.is_empty() else 1)
