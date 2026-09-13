extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
 var results={}
 for id in ["lqdm1","lqdm3","lqdm2","lqdm8"]:
  g._load_map(id)
  var mesh=load("res://maps/navigation/"+id+".res")
  var vertices=mesh.get_vertices();var rows=[];var keys={};var nav=g.get_world_3d().direct_space_state
  for index in mesh.get_polygon_count():
   var p=Vector3.ZERO;var poly=mesh.get_polygon(index)
   for v in poly:p+=vertices[v]
   p/=poly.size()
   var key=Vector3i(p/2)
   if keys.has(key):continue
   keys[key]=true
   var floor_hit=nav.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*2,1))
   if floor_hit.is_empty() or floor_hit.normal.y<.8:continue
   p=floor_hit.position
   var lo=INF;var hi=-INF
   for spawn in g.spawn_points:lo=minf(lo,spawn.y);hi=maxf(hi,spawn.y)
   if p.y<lo-2 or p.y>hi+1:continue
   var head=nav.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.1,p+Vector3.UP*5,1))
   if not head.is_empty() and head.position.y-p.y<3:continue
   var open=0.0;var minimum=100.0
   for i in 12:
    var target=p+Vector3(cos(TAU*i/12),0,sin(TAU*i/12))*12+Vector3.UP
    var hit=nav.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,target,1))
    var dist=12.0 if hit.is_empty() else hit.position.distance_to(p+Vector3.UP)
    open+=dist;minimum=minf(minimum,dist)
   if minimum<2.5:continue
   rows.append({"position":[p.x,p.y,p.z],"quake":[-p.z*32,-p.x*32,p.y*32],"open":open,"minimum":minimum})
  rows.sort_custom(func(a,b):return a.open>b.open)
  var selected=[]
  for row in rows:
   var p=Vector3(row.position[0],row.position[1],row.position[2])
   if selected.any(func(r):return Vector3(r.position[0],r.position[1],r.position[2]).distance_to(p)<6):continue
   selected.append(row)
   if selected.size()>=8:break
  results[id]=selected;print(id," ",selected)
 FileAccess.open("res://test-results/koth/survey.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 g.free();quit()
