extends SceneTree
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Integrity=preload("res://tools/voxel_battle/structural_integrity.gd")
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
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
 print("CQ_COLLAPSE_CATALOG ",JSON.stringify({"checks":checks,"failures":failures,"buildings":service.integrity.buildings.size(),"eligible_cells":service.integrity.cell_building.size()}))
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
