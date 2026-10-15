extends Node3D
## Opt-in authoritative wall breaches; fixed topology, no rigid bodies or runtime CSG.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Builder=preload("res://tools/streamed_heightfield/structures.gd").Builder
const MAX_BROKEN:=256
const MAX_PER_IMPACT:=6
const MAX_SHARDS:=96
const MAX_ANIMATED_PANELS_PER_FRAME:=2
const CELL_WIDTH:=2.8
var game
var map
var enabled:=false
var graphics:=false
var cells:Array=[]
var walls:Dictionary={}
var bins:Dictionary={}
var broken:Dictionary={}
var colliders:Dictionary={}
var originals:Dictionary={}
var topology:Dictionary={}
var dirty:Dictionary={}
var debris:Array=[]
var animated_this_frame:=0
var cell_shapes:Dictionary={}
var revision:=0
var received_revision:=-1
var synced:=false
var epoch:=-1
var round_id:=-1
var next_request:=0.
var rebuild_usec:=0
func setup(arena,world,draw:bool,experiment:bool=false)->void:
 game=arena;map=world;graphics=draw;enabled=experiment;epoch=game.map_epoch
 if graphics and not map.layout is Dictionary:
  var resource:Resource=load("res://experimental-assets/destruction/wall_topology.res")
  topology=resource.get_meta("topology")
  for file in resource.get_meta("sources",{}):
   if FileAccess.file_exists("res://"+file):assert(FileAccess.get_sha256("res://"+file)==resource.get_meta("sources")[file],"Destruction topology is stale; run bake_destruction_topology.gd")
 for index in map.layout.boxes.size():
  var row:Dictionary=map.layout.boxes[index]
  var axis:int=0 if row.size.z<=.3 and row.size.x>=1.2 else 2 if row.size.x<=.3 and row.size.z>=1.2 else -1
  if axis<0 or row.size.y<.6:continue
  var count:int=ceili(row.size[axis]/CELL_WIDTH)
  var wall:Dictionary=row.duplicate();wall.axis=axis;wall.cells=[];wall.index=index
  walls[index]=wall
  for part in count:
   var size:Vector3=row.size;size[axis]/=count
   var center:Vector3=row.center;center[axis]+=-row.size[axis]*.5+size[axis]*(part+.5)
   var id:int=cells.size();wall.cells.append(id)
   cells.append({"wall":index,"kind":row.kind,"center":center,"size":size,"position":center+Landscape.CENTERS[row.kind]})
   var coord:=Vector2i(floori(cells[id].position.x/16.),floori(cells[id].position.z/16.))
   if not bins.has(coord):bins[coord]=[]
   bins[coord].append(id)
 set_process(true)
func nearest_point(bounds:AABB,p:Vector3)->Vector3:return p.clamp(bounds.position,bounds.end)
func candidates(at:Vector3,damage:float,radius:float,visibility:bool=true)->PackedInt32Array:
 var result:=PackedInt32Array()
 if damage<60 or not at.is_finite() or not is_finite(radius) or radius<=0:return result
 var reach:float=clampf(radius*.18,.75,4.5)
 var near:Array=[];var nearby:Array=[]
 var coord:=Vector2i(floori(at.x/16.),floori(at.z/16.))
 for z in range(coord.y-1,coord.y+2):
  for x in range(coord.x-1,coord.x+2):nearby.append_array(bins.get(Vector2i(x,z),[]))
 for id in nearby:
  if broken.has(id):continue
  var c:Dictionary=cells[id];var box:=AABB(c.position-c.size*.5,c.size)
  var distance:float=nearest_point(box,at).distance_to(at)
  if distance>reach:continue
  near.append({"id":id,"distance":distance})
 near.sort_custom(func(a,b):return a.distance<b.distance if not is_equal_approx(a.distance,b.distance) else a.id<b.id)
 for item in near:
  if result.size()>=MAX_PER_IMPACT or broken.size()+result.size()>=MAX_BROKEN:break
  var c:Dictionary=cells[item.id]
  if visibility and map.wall_bodies.has(c.wall):
   var excluded:Array[RID]=[map.wall_bodies[c.wall].get_rid()]
   if colliders.has(c.wall):excluded.append(colliders[c.wall].get_rid())
   var ray:=PhysicsRayQueryParameters3D.create(at+(c.position-at).normalized()*.08,c.position,1,excluded)
   if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
  result.append(item.id)
 return result
func impact(at:Vector3,damage:float,radius:float)->void:
 if not enabled or not game.active or not multiplayer.is_server():return
 sync_epoch()
 var ids:=candidates(at,damage,radius)
 if ids.is_empty():return
 apply_breaks(ids,at,true);revision+=1;publish(0,at)
func apply_breaks(ids:PackedInt32Array,at:Vector3,animate:bool)->void:
 var changed:Dictionary={}
 for id in ids:
  if id<0 or id>=cells.size() or broken.has(id) or broken.size()>=MAX_BROKEN:continue
  broken[id]=true;var cell:Dictionary=cells[id];changed[cell.wall]=true;dirty[cell.kind]=true
  if graphics and animate:animate_cell(cell,at)
 for index in changed:rebuild_collision(index)
func rebuild_collision(index:int)->void:
 if not map.wall_bodies.has(index):return
 var original:StaticBody3D=map.wall_bodies[index];original.collision_layer=0
 if colliders.has(index):
  for id in walls[index].cells:
   if broken.has(id) and cell_shapes.has(id):cell_shapes[id].disabled=true
  return
 var body:=StaticBody3D.new();body.name="BreachedWall_%d"%index;add_child(body);colliders[index]=body
 for id in walls[index].cells:
  if broken.has(id):continue
  var cell:Dictionary=cells[id];var shape:=BoxShape3D.new();shape.size=cell.size
  var node:=CollisionShape3D.new();node.shape=shape;node.position=cell.position;body.add_child(node);cell_shapes[id]=node
func replace_mesh(source:ArrayMesh,kind:int,lod:int=0)->ArrayMesh:
 var arrays:Array=source.surface_get_arrays(0).duplicate(true)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var replacements:Array=[]
 for index in walls:
  var wall:Dictionary=walls[index]
  if wall.kind!=kind or not wall.cells.any(func(id):return broken.has(id)):continue
  replacements.append(wall)
 var kept:=PackedInt32Array();var samples:Dictionary={};var removed_triangles:Dictionary={}
 if not topology.is_empty():
  for wall in replacements:
   var record:Dictionary=topology.get(wall.index,{}).get(lod,{})
   if record.is_empty():continue
   samples[wall.index]=record.vertices
   for index in record.triangles:removed_triangles[index]=true
 else:
  # Synthetic test meshes use the same classifier as the offline topology bake.
  for i in range(0,indices.size(),3):
   for wall in replacements:
    var bounds:=AABB(wall.center-wall.size*.5,wall.size).grow(.002)
    if bounds.has_point(points[indices[i]]) and bounds.has_point(points[indices[i+1]]) and bounds.has_point(points[indices[i+2]]):
     if not samples.has(wall.index):samples[wall.index]=[]
     for j in 3:
      if not indices[i+j] in samples[wall.index]:samples[wall.index].append(indices[i+j])
     removed_triangles[i]=true;break
 for i in range(0,indices.size(),3):
  if not removed_triangles.has(i):kept.append_array(indices.slice(i,i+3))
 var original_count:int=points.size()
 var strides:Dictionary={}
 for channel in range(1,Mesh.ARRAY_INDEX):
  if arrays[channel]!=null and not arrays[channel].is_empty():strides[channel]=arrays[channel].size()/original_count
 for wall in replacements:
  if not samples.has(wall.index):continue # Interior walls are absent from middle LOD.
  var builder=Builder.new()
  for id in wall.cells:
   if not broken.has(id):builder.box(cells[id].center,cells[id].size,Color.WHITE)
  if builder.vertices.is_empty():continue
  var offset:int=arrays[Mesh.ARRAY_VERTEX].size()
  for v in builder.vertices:
   var nearest:int=samples[wall.index][0];var distance:=INF
   for sample in samples[wall.index]:
    var d:float=points[sample].distance_squared_to(v)
    if d<distance:distance=d;nearest=sample
   arrays[Mesh.ARRAY_VERTEX].append(v)
   # Preserve all existing bake channels (including raw custom attribute bytes).
   for channel in range(1,Mesh.ARRAY_INDEX):
    if arrays[channel]==null or arrays[channel].is_empty():continue
    var stride:int=strides[channel]
    arrays[channel].append_array(arrays[channel].slice(nearest*stride,(nearest+1)*stride))
  for vertex in builder.indices:kept.append(offset+vertex)
 arrays[Mesh.ARRAY_INDEX]=kept
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_format(0))
 mesh.surface_set_material(0,source.surface_get_material(0));return mesh
func flush_meshes()->void:
 if not graphics or not map.structures:dirty.clear();return
 var started:=Time.get_ticks_usec()
 for kind in dirty:
  if not originals.has(kind):originals[kind]=map.structures.meshes[kind].duplicate()
  for lod in 2:
   var mesh:=replace_mesh(originals[kind][lod],kind,lod)
   map.structures.meshes[kind][lod]=mesh;map.structures.groups[kind][lod].multimesh.mesh=mesh
  # The solid silhouette proxy cannot display holes. Reuse patched middle LOD.
  map.structures.meshes[kind][2]=map.structures.meshes[kind][1]
  map.structures.groups[kind][2].multimesh.mesh=map.structures.meshes[kind][2]
 map.structures.last_position=Vector3.INF;dirty.clear();rebuild_usec=Time.get_ticks_usec()-started
func animate_cell(cell:Dictionary,at:Vector3)->void:
 if game.has_method("world_view_camera"):
  var camera:Camera3D=game.world_view_camera()
  if not camera or camera.global_position.distance_squared_to(cell.position)>120.*120.:return
 # Baked shared Voronoi fragments; transform animation only, never physics bodies.
 if animated_this_frame>=MAX_ANIMATED_PANELS_PER_FRAME:return
 animated_this_frame+=1
 var shards:PackedScene=load("res://experimental-assets/destruction/wall_shards.tscn")
 if shards==null:return
 var node:Node3D=shards.instantiate();add_child(node)
 if map.get("lighting")!=null:preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(node)
 var axis:int=walls[cell.wall].axis
 node.transform=Transform3D(Basis.IDENTITY if axis==0 else Basis(Vector3.UP,PI*.5),cell.position)
 node.scale=Vector3(cell.size[axis],cell.size.y,cell.size[2 if axis==0 else 0])
 for child in node.get_children():
  if not child is MeshInstance3D:continue
  if debris.size()>=MAX_SHARDS:
   var old:Dictionary=debris.pop_front()
   if is_instance_valid(old.node):old.node.queue_free()
  child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var origin:Transform3D=child.global_transform
  var direction:Vector3=(cell.position-at).normalized()+Vector3.UP*.7
  debris.append({"node":child,"origin":origin,"velocity":direction*(2.5+float(debris.size()%3)),"age":0.,"spin":Vector3(.8,1.2,.5)})
 # Parent is freed after its finite animation; late joiners receive no old debris.
 var reference:WeakRef=weakref(node)
 get_tree().create_timer(1.2).timeout.connect(func():
  var remaining=reference.get_ref()
  if is_instance_valid(remaining):remaining.queue_free())
func clear_state()->void:
 for body in colliders.values():body.free()
 colliders.clear();cell_shapes.clear()
 for index in walls:
  if map.wall_bodies.has(index):map.wall_bodies[index].collision_layer=1
 if map.structures:
  for kind in originals:
   for lod in 3:
    map.structures.meshes[kind][lod]=originals[kind][lod];map.structures.groups[kind][lod].multimesh.mesh=originals[kind][lod]
  map.structures.last_position=Vector3.INF
 for item in debris:
  if is_instance_valid(item.node):item.node.queue_free()
 debris.clear();broken.clear();dirty.clear();originals.clear()
func publish(peer:int=0,at:Vector3=Vector3.ZERO)->void:
 if multiplayer.get_peers().is_empty():return
 var ids:=PackedInt32Array(broken.keys())
 if peer>0:receive_state.rpc_id(peer,epoch,revision,enabled,ids)
 else:receive_state.rpc(epoch,revision,enabled,ids,at,true)
@rpc("any_peer","call_remote","reliable",0)
func request_state(map_epoch:int)->void:
 if not game or not multiplayer.is_server() or map_epoch!=epoch:return
 var peer:int=multiplayer.get_remote_sender_id()
 if peer>0 and peer in multiplayer.get_peers():publish(peer)
@rpc("authority","call_remote","reliable",0)
func receive_state(map_epoch:int,version:int,experiment:bool,ids:PackedInt32Array,at:Vector3=Vector3.ZERO,animate:bool=false)->void:
 if not game or multiplayer.is_server() or map_epoch!=game.map_epoch or version<received_revision or ids.size()>MAX_BROKEN:return
 for id in ids:
  if id<0 or id>=cells.size():return
 var reset:bool=not broken.keys().all(func(id):return id in ids)
 if reset:clear_state()
 enabled=experiment;received_revision=version
 apply_breaks(ids,at,animate and synced);synced=true
func sync_epoch()->void:
 if epoch==game.map_epoch:return
 clear_state();epoch=game.map_epoch;revision=0;received_revision=-1;synced=false;round_id=-1
func _process(delta:float)->void:
 if not game or not is_instance_valid(map):return
 sync_epoch()
 if multiplayer.is_server() and game.resident and game.resident.core:
  var current:int=game.resident.metrics.get("round_epoch",0)
  if round_id>=0 and current!=round_id:clear_state();revision+=1;publish()
  round_id=current
 if not multiplayer.is_server() and game.active and not synced:
  next_request-=delta
  if next_request<=0 and multiplayer.get_peers().has(1):next_request=1.;request_state.rpc_id(1,game.map_epoch)
 flush_meshes();animated_this_frame=0
 for item in debris:
  if not is_instance_valid(item.node):continue
  item.age+=delta;var t:float=item.age
  item.node.global_transform=item.origin
  item.node.global_position+=item.velocity*t+Vector3.DOWN*3*t*t
  item.node.rotate_object_local(Vector3(1,1,.5).normalized(),t*1.8)
  item.node.scale*=maxf(0,1.-maxf(0,t-.65)/.4)
 debris=debris.filter(func(item):return is_instance_valid(item.node))
