extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
 var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tools/cc/recipes.json"));var result={}
 for row in rows:
  g._load_map(row.source)
  await physics_frame;await physics_frame
  var c=Vector3(-row.center[1],row.center[2],-row.center[0])/32
  var points=[]
  var reach=256
  for offset in [Vector2(256,0),Vector2(-256,0),Vector2(0,256),Vector2(0,-256)]:
   offset=offset.normalized()*reach
   var p=c+Vector3(-offset.y,0,-offset.x)/32
   var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*10,1))
   points.append({"offset":[offset.x,offset.y],"height":round(hit.position.y*32) if not hit.is_empty() else null,"normal":str(hit.get("normal",Vector3.ZERO))})
  result[row.id]=points
 FileAccess.open("res://test-results/cc/approaches.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 g.free();quit()
