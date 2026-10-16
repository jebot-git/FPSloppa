extends SceneTree
## Offline conversion only. The shipped server reads JSON/binary data, never Godot resources.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var output:="res://native_server/cooked"
var blobs:FileAccess
var game
var shape_cache:Dictionary={}
var shapes:Array=[]
func _initialize():run.call_deferred()
func vector(v:Vector3)->Array:return [v.x,v.y,v.z]
func blob(bytes:PackedByteArray)->Dictionary:
 var at:=blobs.get_position();blobs.store_buffer(bytes);return {"offset":at,"bytes":bytes.size()}
func value(v:Variant)->Variant:
 if v is Vector3:return vector(v)
 if v is Vector4:return [v.x,v.y,v.z,v.w]
 if v is Color:return [v.r,v.g,v.b,v.a]
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is AABB:return {"minimum":vector(v.position),"maximum":vector(v.end)}
 if v is Transform3D:return [vector(v.basis.x),vector(v.basis.y),vector(v.basis.z),vector(v.origin)]
 if v is Dictionary:
  var out:Dictionary={}
  for k in v:out[str(k)]=value(v[k])
  return out
 if v is Array or v is PackedInt32Array or v is PackedFloat32Array or v is PackedVector3Array or v is PackedVector4Array:
  var out:Array=[]
  for item in v:out.append(value(item))
  return out
 return v
func bins(rows:Dictionary)->Array:
 var out:Array=[]
 for key in rows:out.append({"cell":[key.x,key.y],"rows":value(rows[key])})
 return out
func shape_data(shape:Shape3D)->int:
 var key:=shape.get_instance_id()
 if shape_cache.has(key):return shape_cache[key]
 var row:Dictionary={"type":shape.get_class()}
 if shape is BoxShape3D:row.size=vector(shape.size)
 elif shape is CylinderShape3D or shape is CapsuleShape3D:row.radius=shape.radius;row.height=shape.height
 elif shape is SphereShape3D:row.radius=shape.radius
 elif shape is HeightMapShape3D:row.width=shape.map_width;row.depth=shape.map_depth;row.data=blob(shape.map_data.to_byte_array())
 elif shape is ConcavePolygonShape3D:row.data=blob(shape.get_faces().to_byte_array())
 elif shape is ConvexPolygonShape3D:row.data=blob(shape.points.to_byte_array())
 else:assert(false,"Unsupported authoritative shape: "+str(shape.get_class()))
 var index:=shapes.size();shape_cache[key]=index;shapes.append(row);return index
func run():
 var args:=OS.get_cmdline_user_args();var at:=args.find("--output")
 if at>=0 and at+1<args.size():output=args[at+1]
 DirAccess.make_dir_recursive_absolute(output);DirAccess.make_dir_recursive_absolute(output+"/avatars")
 blobs=FileAccess.open(output+"/geometry.bin",FileAccess.WRITE);assert(blobs)
 game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 assert(game._load_map("voxel_jungle"));var map=game.battle_map
 var wall_ids:Dictionary={};var building_ids:Dictionary={}
 for id in map.wall_bodies:
  if is_instance_valid(map.wall_bodies[id]):wall_ids[map.wall_bodies[id].get_instance_id()]=id
 var destruction=game.destruction
 for id in destruction.building_bodies:
  for reference in destruction.building_bodies[id]:
   var body=reference.get_ref()
   if is_instance_valid(body):building_ids[body.get_instance_id()]=id
 var bodies:Array=[]
 for node in map.find_children("*","StaticBody3D",true,false):
  if node.collision_layer==0:continue
  var pieces:Array=[]
  for child in node.get_children():
   if child is CollisionShape3D and not child.disabled and child.shape:
    pieces.append({"shape":shape_data(child.shape),"transform":value(node.global_transform*child.transform)})
  if not pieces.is_empty():bodies.append({"pieces":pieces,"wall":wall_ids.get(node.get_instance_id(),-1),"building":building_ids.get(node.get_instance_id(),-1)})
 print("CQ_WORLD_COOK collision bodies=",bodies.size()," shapes=",shapes.size())
 var nav=await preload("res://tools/voxel_battle/jungle_navigation.gd").build(map)
 var nav_file:=FileAccess.open(output+"/navigation.bin",FileAccess.WRITE);nav_file.store_buffer("CQN1".to_ascii_buffer())
 var regions:Array=[];var links:Array=[]
 for child in nav.get_children():
  if child is NavigationRegion3D:regions.append(child)
  elif child is NavigationLink3D:links.append([vector(child.start_position),vector(child.end_position)])
 nav_file.store_32(regions.size())
 var polygon_count:=0
 for region in regions:
  var mesh:NavigationMesh=region.navigation_mesh;var vertices:=mesh.get_vertices();nav_file.store_32(vertices.size());nav_file.store_buffer(vertices.to_byte_array());nav_file.store_32(mesh.get_polygon_count())
  for index in mesh.get_polygon_count():
   var polygon:=mesh.get_polygon(index);nav_file.store_32(polygon.size());nav_file.store_buffer(polygon.to_byte_array());polygon_count+=1
 nav_file.close();nav.free();blobs.close()
 var core_terrain:=preload("res://deathmatch/native/cq_metadata.gd").terrain()
 core_terrain.main_bins=bins(core_terrain.main_bins);core_terrain.access_bins=bins(core_terrain.access_bins)
 var world_terrain:Dictionary={"extent":Landscape.EXTENT,"tile":Landscape.TILE,"roads":bins(Landscape.road_bins),"access":bins(Landscape.access_bins),"earthworks":bins(Landscape.earthwork_bins),"rivers":bins(Landscape.Hydrology.bins),"centers":value(Landscape.CENTERS),"radii":value(Landscape.RADII),"rocks":value(Landscape.ROCK_FORMATIONS),"cover":value(Landscape.COVER)}
 var vehicles:Array=[]
 for row in game.battery_tanks.rows.values():vehicles.append({"kind":["rocket","light","heavy","transport","bike"].find(row.kind),"position":vector(row.position),"yaw":row.yaw,"team":row.team})
 var spawns:Array=[]
 for team in 2:spawns.append(value(game.match_mode.spawns(team)))
 var rubble:Array=[]
 for building in destruction.integrity.buildings:
  var rows:Array=preload("res://tools/voxel_battle/collapse_assets.gd").rubble_rows(building,game.match_mode.objectives.sites)
  for row in rows:row.center+=Landscape.CENTERS[building.kind]
  rubble.append(value(rows))
 var avatars:Array=[]
 for filename in DirAccess.get_files_at("res://deathmatch/avatars/models/base"):
  if not filename.ends_with(".utavatar"):continue
  var source:="res://deathmatch/avatars/models/base/"+filename
  var parsed:=preload("res://deathmatch/avatars/ut_format.gd").read(source);assert(not parsed.has("error"))
  var hash_value:=FileAccess.get_sha256(source);var bytes:=FileAccess.get_file_as_bytes(source)
  FileAccess.open(output+"/avatars/"+hash_value+".utavatar",FileAccess.WRITE).store_buffer(bytes)
  avatars.append({"hash":hash_value,"size":bytes.size(),"filename":filename,"reach":parsed.manifest.get("ik_profile",{})})
 var bins_source:Dictionary={};var source_paths:Array=["res://tools/voxel_battle/landscape.gd","res://tools/voxel_battle/architecture.gd","res://tools/voxel_battle/outer_architecture.gd","res://tools/voxel_battle/hydrology.gd","res://tools/voxel_battle/jungle_navigation.gd","res://tools/voxel_battle/structural_integrity.gd","res://tools/voxel_battle/collapse_assets.gd","res://deathmatch/weapons/cq/manifest.json"]
 for path in game.map_sources():source_paths.append(path)
 for path in source_paths:bins_source[path]=FileAccess.get_sha256(path)
 var data:Dictionary={"version":1,"protocol":"fpsloppa-cq-native-1","map":"voxel_jungle","title":"Jungle Frontier","map_sha":game.map_sha,"extent":Landscape.EXTENT,"tile":Landscape.TILE,"shapes":shapes,"bodies":bodies,"spawns":spawns,"zones":value(game.match_mode.objectives.sites),"lamps":game.battle_map.lighting.metadata.get("lamps",[]),"vehicles":vehicles,"core_terrain":value(core_terrain),"world_terrain":world_terrain,"roads":value(Landscape.main_roads),"nav_links":links,"destruction":{"cells":value(destruction.cells),"walls":value(destruction.walls),"buildings":value(destruction.integrity.buildings),"rubble":rubble},"avatars":avatars,"sources":bins_source}
 FileAccess.open(output+"/world.json",FileAccess.WRITE).store_string(JSON.stringify(data))
 var receipt:Dictionary={}
 for name in ["world.json","geometry.bin","navigation.bin"]:receipt[name]={"sha256":FileAccess.get_sha256(output+"/"+name),"size":FileAccess.get_file_as_bytes(output+"/"+name).size()}
 FileAccess.open(output+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
 print("CQ_WORLD_COOK_COMPLETE ",JSON.stringify({"output":output,"bodies":bodies.size(),"polygons":polygon_count,"avatars":avatars.size()}))
 game.queue_free();await process_frame;quit()
