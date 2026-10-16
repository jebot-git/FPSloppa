extends "res://tools/streamed_heightfield/stream.gd"
var native_world=preload("res://deathmatch/native/world.gd").create()
var visibility_coords:Array=[]
var visibility_bounds:Array=[]
var visibility_slots:=PackedInt32Array()
func select_tiles(camera:Camera3D)->void:
 if not native_world:super.select_tiles(camera);return
 var p:=camera.global_position
 var cell:=Vector2i(floori((p.x+extent/2)/tile_side),floori((p.z+extent/2)/tile_side))
 if cell==last_cell:return
 last_cell=cell
 var plan:Dictionary=native_world.terrain_plan(p,resident.keys(),running.keys(),tile_side,extent,grid,analytic_enabled)
 desired.clear();queue.clear();selection_candidates=plan.candidates
 for key in plan.desired:desired[key]=true
 for key in plan.queue:queue.append(key)
 for key in plan.evict:evict(key)
 if not plan.evict.is_empty():
  page_image.generate_mipmaps();pages.update(page_image)
func evict(key:Vector2i)->void:
 super.evict(key);visibility_coords.clear()
func update_visibility(camera:Camera3D)->void:
 if not native_world:super.update_visibility(camera);return
 if camera.global_position==last_position and camera.global_rotation==last_rotation:return
 last_position=camera.global_position;last_rotation=camera.global_rotation
 # The atlas slot table changes only on residency updates, not head motion.
 if visibility_coords.size()!=resident.size():
  visibility_coords=resident.keys();visibility_bounds.clear();visibility_slots.clear()
  for key in visibility_coords:
   var origin:=Vector3(key.x*tile_side-extent/2,0,key.y*tile_side-extent/2)
   visibility_bounds.append(tile_bounds.get(key,AABB(origin+Vector3(0,min_height,0),Vector3(tile_side,max_height-min_height,tile_side))))
   visibility_slots.append(resident[key])
 var selected:Dictionary=native_world.terrain_select(visibility_coords,visibility_bounds,visibility_slots,camera.global_position,camera.get_frustum(),culling_enabled,force_fine,tile_side,extent,CAPACITY)
 visible_tiles=0;terrain_triangles=0
 for i in 4:
  counts[i]=selected.counts[i];visible_tiles+=counts[i]
  terrain_triangles+=counts[i]*meshes[i].surface_get_array_index_len(0)/3
  if raster_enabled and counts[i]>0:groups[i].multimesh.buffer=selected.buffers[i]
  groups[i].multimesh.visible_instance_count=counts[i];groups[i].visible=raster_enabled and counts[i]>0
func reset_cache()->void:
 super.reset_cache();visibility_coords.clear()
