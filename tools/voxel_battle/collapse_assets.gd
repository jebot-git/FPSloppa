extends RefCounted
## Shared offline/runtime definitions: deterministic cover and compact baked meshes.
const Builder=preload("res://tools/streamed_heightfield/structures.gd").Builder
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Objectives=preload("res://deathmatch/conquest/frontier/objectives.gd")
const CAPTURE_CLEARANCE:=Objectives.RADIUS+1.0
static func rubble_rows(building:Dictionary,sites:Array)->Array:
 var result:Array=[]
 for side in [-1,1]:
  for lane in [-1,1]:
   for edge in 2:
    var size:=Vector3(3.4,1.6 if edge==0 else 1.25,2.6)
    var p:Vector3=building.center+Vector3(side*(building.size.x*.5-1.7),.12+size.y*.5,lane*(building.size.y*(.3 if edge==0 else .12)))
    var box:=AABB(p-size*.5,size)
    var clear:=true
    for site in sites:
     var local:Vector3=site.position-Landscape.CENTERS[building.kind]
     var nearest:=Vector2(clampf(local.x,box.position.x,box.end.x),clampf(local.z,box.position.z,box.end.z))
     if nearest.distance_to(Vector2(local.x,local.z))<CAPTURE_CLEARANCE:clear=false;break
    if clear:result.append({"center":p,"size":size})
 return result
static func rubble_mesh(building:Dictionary,rows:Array)->ArrayMesh:
 var builder=Builder.new()
 # Flush exposed slab: reusing intact vertex irradiance would leave a black roof shadow.
 builder.box(Vector3(0,.105,0),Vector3(building.size.x,.01,building.size.y),Color(.23,.25,.22))
 for index in rows.size():
  var row:Dictionary=rows[index]
  var p:Vector3=row.center-building.center;var s:Vector3=row.size
  var first:int=builder.vertices.size()
  var sign:float=-1. if index%2 else 1.
  chunk(builder,p-Vector3(0,s.y*.3,0),s*Vector3(.9,.35,.85),Vector3(0,sign*.13,0),Color(.31,.33,.28))
  chunk(builder,p+Vector3(-s.x*.05,0,s.z*.1),s*Vector3(.78,.85,.42),Vector3(.16,sign*.2,-sign*.18),Color(.40,.41,.34))
  chunk(builder,p+Vector3(s.x*.2,-s.y*.05,-s.z*.12),s*Vector3(.38,.5,.6),Vector3(.45,-sign*.25,sign*.4),Color(.36,.37,.32))
  # The visual envelope always fits the tested clearance/collision footprint.
  for i in range(first,builder.vertices.size()):builder.vertices[i]=builder.vertices[i].clamp(p-s*.5,p+s*.5)
 return builder.finish()
static func chunk(builder,center:Vector3,size:Vector3,angles:Vector3,color:Color)->void:
 var first:int=builder.vertices.size();builder.box(center,size,color)
 var rotation:=Basis.from_euler(angles)
 for i in range(first,builder.vertices.size()):builder.vertices[i]=center+rotation*(builder.vertices[i]-center)
static func compact(source:ArrayMesh,triangles:PackedInt32Array,origin:Vector3)->ArrayMesh:
 if triangles.is_empty():return null
 var arrays:Array=source.surface_get_arrays(0)
 var result:Array=[];result.resize(Mesh.ARRAY_MAX)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var remap:Dictionary={};var kept:=PackedInt32Array()
 var selected:=PackedInt32Array()
 for triangle in triangles:
  for j in 3:
   var old:int=indices[triangle+j]
   if not remap.has(old):remap[old]=selected.size();selected.append(old)
   kept.append(remap[old])
 for channel in Mesh.ARRAY_INDEX:
  if arrays[channel]==null or arrays[channel].is_empty():continue
  result[channel]=arrays[channel].slice(0,0)
  var stride:int=arrays[channel].size()/points.size()
  for old in selected:result[channel].append_array(arrays[channel].slice(old*stride,(old+1)*stride))
 var local:PackedVector3Array=result[Mesh.ARRAY_VERTEX]
 for i in local.size():local[i]-=origin
 result[Mesh.ARRAY_VERTEX]=local;result[Mesh.ARRAY_INDEX]=kept
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result,[],{},source.surface_get_format(0));mesh.surface_set_material(0,source.surface_get_material(0));return mesh
