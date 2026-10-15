extends RefCounted
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Structures=preload("res://tools/streamed_heightfield/structures.gd")
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=9
 var resident=null
class World extends Node3D:
 var layout:Dictionary={}
 var wall_bodies:Dictionary={}
 var structures
 var lighting=null
static func box(parent:Node3D,at:Vector3,size:Vector3)->StaticBody3D:
 var body:=StaticBody3D.new();body.position=at
 var node:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;node.shape=shape;body.add_child(node);parent.add_child(body);return body
static func make(parent:Node,graphics:bool=true)->Dictionary:
 var game:=Game.new();game.name="Game";parent.add_child(game)
 var world:=World.new();world.name="World";game.add_child(world)
 var layout:=Architecture.new();layout.kind=0;layout.level=0;layout.builder=Structures.Builder.new()
 layout.building(Vector3.ZERO,Vector2(13,16),3,Color(.6,.6,.5),"house")
 layout.building(Vector3(26,0,0),Vector2(13,16),3,Color(.5,.6,.5),"house")
 world.layout={"boxes":layout.boxes,"buildings":layout.buildings}
 var origin:Vector3=Landscape.CENTERS[0]
 box(world,origin+Vector3(13,-.6,0),Vector3(70,1,60))
 for index in layout.boxes.size():
  var row:Dictionary=layout.boxes[index];world.wall_bodies[index]=box(world,origin+row.center,row.size)
 var ramp:=box(world,origin+Vector3(4,2,0),Vector3(2,.2,5));ramp.name="StairRamp_fixture"
 if graphics:
  var mesh:ArrayMesh=layout.builder.finish();world.structures=Structures.new();world.structures.meshes=[[mesh,mesh,mesh]]
  world.structures.placements=[{"kind":0,"position":origin}];world.add_child(world.structures);world.structures.setup()
 var service:=Destruction.new();service.name="Destruction";game.add_child(service);service.setup(game,world,graphics,true)
 return {"game":game,"world":world,"service":service,"origin":origin,"ramp":ramp}
static func support_ids(service,building:int,floor_index:int)->PackedInt32Array:
 var ids:=PackedInt32Array()
 for column in service.integrity.buildings[building].stories[floor_index]:
  for id in column.cells:
   if not id in ids:ids.append(id)
 return ids
