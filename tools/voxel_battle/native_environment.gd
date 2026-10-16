extends "res://tools/voxel_battle/environment.gd"
var native_capacities:=PackedInt32Array()
var native_world=preload("res://deathmatch/native/world.gd").create()
func load_tile(coord:Vector2i,data:Dictionary)->void:
 super.load_tile(coord,data)
 if native_world:
  var bounds:Array=[]
  for kind in 3:bounds.append(variants.mesh[kind][0].get_aabb())
  native_world.trees_load(coord,tiles[coord].rows,tiles[coord].bounds,bounds)
func evict_tile(coord:Vector2i)->void:
 super.evict_tile(coord)
 if native_world:native_world.trees_evict(coord)
func update(camera:Camera3D)->void:
 if not native_world:super.update(camera);return
 if not dirty and camera.global_position==last_position and camera.global_rotation==last_rotation:return
 var started:=Time.get_ticks_usec()
 dirty=false;last_position=camera.global_position;last_rotation=camera.global_rotation
 var selected:Dictionary=native_world.trees_select(camera.global_position,camera.get_frustum(),culling_enabled,force_near,CAPACITY,VIEW_DISTANCE,native_capacities)
 native_capacities=selected.capacities
 counts=[[0,0,0],[0,0,0],[0,0,0]]
 visible_features=0;triangles=0;draw_calls=0
 for kind in 3:
  for lod in 3:
   var group:int=kind*3+lod
   if groups[kind][lod].multimesh.instance_count!=native_capacities[group]:groups[kind][lod].multimesh.instance_count=native_capacities[group]
   counts[kind][lod]=selected.counts[group];visible_features+=counts[kind][lod]
   if counts[kind][lod]>0:groups[kind][lod].multimesh.buffer=selected.buffers[group]
   triangles+=counts[kind][lod]*meshes[kind][lod].surface_get_array_index_len(0)/3
 stream_svo_resources()
 for kind in 3:
  for lod in 3:
   groups[kind][lod].multimesh.visible_instance_count=counts[kind][lod]
   groups[kind][lod].visible=counts[kind][lod]>0 and (render_mode!="svo" or kind==2 or svo_resident.has(Vector2i(kind,lod)))
   if counts[kind][lod]>0:draw_calls+=1
 update_ms=(Time.get_ticks_usec()-started)/1000.0
