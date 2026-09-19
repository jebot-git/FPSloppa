extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize() -> void:run.call_deferred()
func save(level: Node,path: String) -> void:
 var scene:=PackedScene.new();assert(scene.pack(level)==OK);assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
func run() -> void:
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/koth/recipes.json"));var receipts: Array=[]
 for row in rows:
  var id: String=row.id
  var args:=OS.get_cmdline_user_args()
  if not args.is_empty() and not id in args:continue
  var path: String=("res://test-results/koth-rotation/"+id+"/" if args.has("--staged") else "res://maps/")+id+".bsp"
  assert(Loader.validate(path).is_empty())
  var level=Loader.read(path);assert(level!=null)
  preload("res://deathmatch/maps/filtering.gd").new().apply(level,2,true)
  assert(level.get_meta("baked_light_invalid_faces",0)==0 and level.get_meta("baked_light_overflow_faces",0)==0)
  var raw: String="res://maps/cache/"+id+"-lightmap1.scn"
  save(level,raw);assert(DirAccess.copy_absolute(raw,"res://maps/cache/"+id+".scn")==OK)
  var receipt: Dictionary={"id":id,"sha256":FileAccess.get_sha256(path),"invalid_faces":level.get_meta("baked_light_invalid_faces",0),"overflow_faces":level.get_meta("baked_light_overflow_faces",0),"codecs":[]}
  root.add_child(level)
  for node in level.find_children("*","PhysicsBody3D",true,false):
   if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","") in ["func_door","func_door_secret"]:node.collision_layer=0
  var mesh=preload("res://deathmatch/bots.gd").new_mesh(id);var data:=NavigationMeshSourceGeometryData3D.new()
  NavigationServer3D.parse_source_geometry_data(mesh,data,level);NavigationServer3D.bake_from_source_geometry_data(mesh,data)
  assert(mesh.get_polygon_count()>0);mesh.set_meta("bsp_source_sha256",receipt.sha256)
  assert(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res")==OK)
  receipt.polygons=mesh.get_polygon_count();level.free()
  for codec in ["bc7","astc4"]:
   level=ResourceLoader.load(raw,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   receipt.codecs.append(preload("res://tools/lighting_experiment/compress_static.gd").new().apply(level,codec))
   var destination: String=Loader.compressed_scene_path(raw,codec);save(level,destination);level.free()
   assert(Loader.cache_matches(ResourceLoader.load(destination,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE),receipt.sha256,codec))
  receipts.append(receipt);print("KOTH_BAKED ",id," polygons=",mesh.get_polygon_count())
 FileAccess.open("res://test-results/koth-rotation/bake"+("-staged" if OS.get_cmdline_user_args().has("--staged") else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(receipts,"  "))
 quit()
