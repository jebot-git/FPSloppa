extends SceneTree
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Integrity=preload("res://tools/voxel_battle/structural_integrity.gd")
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
const Assets=preload("res://tools/voxel_battle/collapse_assets.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=1
 var resident=null
class World extends Node3D:
 var layout
 var wall_bodies:Dictionary={}
 var structures=null
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=Game.new();root.add_child(game);var world:=World.new();game.add_child(world)
 world.layout=Architecture.new();var meshes:Array=world.layout.generate()
 var service:=Destruction.new();game.add_child(service);service.setup(game,world,false,true);service.set_process(false)
 var resource:Resource=load("res://experimental-assets/destruction/wall_topology.res");var topology:Dictionary=resource.get_meta("buildings")
 check(service.integrity.buildings.size()==36,"All 36 authored buildings have collapse state")
 for id in service.integrity.buildings.size():
  var building:Dictionary=service.integrity.buildings[id]
  check(building.stories.all(func(columns):return not columns.is_empty()),"Bearing lanes cover every storey of "+building.role)
  check(service.integrity.status(id,{}).failed_floor<0,"Intact "+building.role+" is stable")
  check(not topology[id][0].is_empty() and not topology[id][1].is_empty(),"Both rendered LODs have collapse masks for "+building.role)
  var animation:ArrayMesh=resource.get_meta("animations")[id]
  check(animation!=null and animation.surface_get_array_index_len(0)==topology[id][0].size()*3,"Compact collapse mesh matches owned triangle count for "+building.role)
  var clear:=true
  for row in service.rubble[id].rows:
   var bounds:=AABB(row.center-row.size*.5,row.size)
   for site in Assets.Objectives.new().sites:
    var point:Vector3=site.position-Assets.Landscape.CENTERS[building.kind]
    var nearest:=Vector2(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.z,bounds.position.z,bounds.end.z))
    if nearest.distance_to(Vector2(point.x,point.z))<Assets.CAPTURE_CLEARANCE:clear=false
  check(clear and not service.rubble[id].rows.is_empty(),"Rubble leaves capture cylinder plus player-width margin clear for "+building.role)
  if building.role not in ["observatory","canopy watchtower"]:continue
  var arrays:Array=meshes[building.kind][0].surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  var high:=0;var missed:=0
  for i in range(0,indices.size(),3):
   var owned:bool=true
   for j in 3:
    var p:Vector3=vertices[indices[i+j]]-building.center
    if absf(p.x)>9.05 or absf(p.z)>(11.05 if building.role=="canopy watchtower" else 9.05) or p.y<10.:owned=false
   if owned:
    high+=1
    if not i in topology[id][0]:missed+=1
  check(high>0 and missed==0,"Collapse mask removes the full authored rooftop addition of "+building.role)
 # The unregistered tents cannot lose walls while retaining unsupported roofs.
 var tent:Dictionary={}
 for cell in service.cells:
  if cell.kind==7 and cell.center.z>10:tent=cell;break
 check(not tent.is_empty() and service.candidates(tent.position,120,5,false).is_empty(),"Unregistered tent shells remain intact until they have authored support ownership")
 var claimed_posts:=0
 for fixture in Integrity.Fixtures.rows(world.layout.buildings):
  if fixture.type in ["entry","hanging"]:continue
  var p:Vector3=fixture.local+Vector3.UP*Integrity.Fixtures.ground(fixture)
  var height:float=4.8 if fixture.type=="lamppost" else 6.5
  var bounds:=AABB(p-Vector3(1.5,height+.2,1.5),Vector3(3,height+.6,3))
  for id in service.integrity.buildings.size():
   var building:Dictionary=service.integrity.buildings[id]
   if fixture.kind!=building.kind or not bounds.intersects(building.bounds):continue
   claimed_posts+=1
   var arrays:Array=meshes[building.kind][0].surface_get_arrays(0);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var missed:=0;var owned:=0
   for i in range(0,indices.size(),3):
    if vertices[indices[i]].y<=building.center.y+.2:continue
    if bounds.has_point(vertices[indices[i]]) and bounds.has_point(vertices[indices[i+1]]) and bounds.has_point(vertices[indices[i+2]]):
     owned+=1
     if not i in topology[id][0]:missed+=1
   check(owned>0 and missed==0,"Whole offset lamp post/arm/head belongs to collapse of "+building.role)
   break
 check(claimed_posts>0,"Catalog exercises building-overlapping lamp posts")
 print("CQ_COLLAPSE_CATALOG ",JSON.stringify({"checks":checks,"failures":failures,"buildings":service.integrity.buildings.size(),"eligible_cells":service.integrity.cell_building.size()}))
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
