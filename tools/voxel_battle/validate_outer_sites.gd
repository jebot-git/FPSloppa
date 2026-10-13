extends SceneTree
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var checks:=0
var errors:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:errors.append(label);push_error(label)
func collider(parent:Node,p:Vector3,size:Vector3) -> void:
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.position=p;parent.add_child(shape)
func run() -> void:
 Landscape.prepare_roads();Engine.physics_ticks_per_second=600;Engine.time_scale=10
 var layout:=Architecture.new();var meshes:=layout.generate()
 var world:=Node3D.new();root.add_child(world)
 var body:=StaticBody3D.new();world.add_child(body)
 for i in range(5,11):collider(body,Landscape.CENTERS[i]+Vector3(0,-.5,0),Vector3(Landscape.RADII[i]*2,1,Landscape.RADII[i]*2))
 for row in layout.boxes:
  if row.kind>=5:collider(body,Landscape.CENTERS[row.kind]+row.center,row.size)
 var actor:=Fighter.new();actor.setup(100,"Outer site doorway probe",Color.WHITE);world.add_child(actor);actor.quake_movement=true;actor.update_height(1.7,true)
 await physics_frame;await physics_frame
 var records:Array=[]
 for kind in range(5,11):
  var triangles:Array=[]
  for lod in 3:
   var mesh:ArrayMesh=meshes[kind][lod];var arrays:=mesh.surface_get_arrays(0);triangles.append(arrays[Mesh.ARRAY_INDEX].size()/3)
   var valid:=mesh.get_surface_count()==1
   for point in arrays[Mesh.ARRAY_VERTEX]:valid=valid and point.is_finite() and absf(point.x)<=Landscape.RADII[kind] and absf(point.z)<=Landscape.RADII[kind]
   check(valid,"Finite single-surface mesh stays inside pad: "+Landscape.TYPES[kind]+" LOD "+str(lod))
  check(triangles[2]<triangles[1] and triangles[1]<triangles[0],"Every landmark reduces geometry at successive LODs: "+Landscape.TYPES[kind])
  var rooms:=0
  for building in layout.buildings:
   if building.kind!=kind:continue
   rooms+=1;var base:Vector3=Landscape.CENTERS[kind]
   for entry in building.entries:
    actor.position=base+entry;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view();actor.reset_jetpack()
    var direction:float=-1 if entry.z>building.center.z else 1
    for frame in 60:
     await physics_frame;actor.simulate(Vector2(0,direction),0,true,1.0/60,false)
    var local:Vector3=actor.position-base-building.center
    check(absf(local.z)<building.size.y*.5-.6,"170 cm actor crosses "+building.role+" entrance")
    check(absf(local.y-.1)<.2,"Supported floor inside "+building.role)
   if building.floors>1:
    actor.position=base+building.center+Vector3(building.size.x/2-1.5,.4,-building.size.y/2+.5);actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view()
    for frame in 110:
     await physics_frame;actor.simulate(Vector2(0,1),0,true,1.0/60,false)
    check(absf(actor.position.y-base.y-3.3)<.25,"170 cm actor climbs "+building.role+" stairs")
  check(rooms>0,"Entered building metadata at "+Landscape.TYPES[kind])
  records.append({"name":Landscape.TYPES[kind],"triangles":triangles,"buildings":rooms})
 var obstacles:Array=[]
 for row in layout.render_boxes:
  if row.kind>=5:obstacles.append(AABB(Landscape.CENTERS[row.kind]+row.center-row.size*.5,row.size))
 var samples:=0
 for road in Landscape.main_roads:
  var side:Vector3=(road.b-road.a).cross(Vector3.UP).normalized()
  for step in ceili(road.delta.length()/2)+1:
   var p:Vector3=road.a.lerp(road.b,minf(1,float(step)*2/road.delta.length()));p.y=Landscape.surface(p.x,p.z).x
   var size:Vector3=side.abs()*(road.width*2+.6)+Vector3(1.8,1.3,1.8)
   var bounds:=AABB(p+Vector3(0,.35,0)-Vector3(size.x/2,0,size.z/2),size)
   var clear:=true
   for obstacle in obstacles:
    if bounds.intersects(obstacle):clear=false;break
   check(clear,"All structure LODs clear human-height road corridor "+str(p));samples+=1
 for lane in Landscape.access_roads:
  if lane.kind<5:continue
  for step in 12:
   var p:Vector3=lane.a.lerp(lane.b,float(step)/11);var clear:=true
   var bounds:=AABB(p+Vector3(-.35,.35,-.35),Vector3(.7,1.3,.7))
   for row in layout.boxes:
    if row.kind>=5 and bounds.intersects(AABB(Landscape.CENTERS[row.kind]+row.center-row.size*.5,row.size)):clear=false;break
   check(clear,"Building access lane stays clear at "+str(p))
 # The canyon truss must allow the full human corridor, not just visual bounds.
 actor.position=Landscape.CENTERS[6]+Vector3(0,.25,-32);actor.velocity=Vector3.ZERO;actor.reset_view()
 for frame in 720:
  await physics_frame;actor.simulate(Vector2(0,1),0,true,1.0/60,false)
  if actor.position.z>Landscape.CENTERS[6].z+32:break
 check(actor.position.z>Landscape.CENTERS[6].z+20,"170 cm actor traverses complete crossing deck")
 var report:={"checks":checks,"errors":errors,"sites":records,"road_samples":samples,"physics_scope":"Six flat pad ground slabs plus the production near-LOD collision descriptions, actual Fighter.simulate doorway/stair/bridge traversal; full terrain heightfield tested separately."}
 DirAccess.make_dir_recursive_absolute("res://test-results/outer-sites")
 FileAccess.open("res://test-results/outer-sites/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));world.free();quit(0 if errors.is_empty() else 1)
