extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var key:=OS.get_cmdline_user_args()[0]
 var path:="res://maps/"+key+".bsp"
 var loader=preload("res://deathmatch/maps/loader.gd")
 var error: String=loader.validate(path)
 if not error.is_empty():push_error(error);quit(1);return
 var level=loader.read(path)
 if level==null:quit(1);return
 var scene:=PackedScene.new()
 assert(scene.pack(level)==OK)
 assert(ResourceSaver.save(scene,"res://maps/cache/"+key+".scn")==OK)
 assert(ResourceSaver.save(scene,"res://maps/cache/"+key+"-lightmap1.scn")==OK)
 root.add_child(level)
 var mesh=preload("res://deathmatch/bots.gd").new_mesh()
 var data:=NavigationMeshSourceGeometryData3D.new()
 NavigationServer3D.parse_source_geometry_data(mesh,data,level)
 NavigationServer3D.bake_from_source_geometry_data(mesh,data)
 assert(mesh.get_polygon_count()>0)
 assert(ResourceSaver.save(mesh,"res://maps/navigation/"+key+".res")==OK)
 var f:=FileAccess.open("res://maps/CTFStudies/"+key+"/navigation-sha256.txt",FileAccess.WRITE)
 f.store_line(FileAccess.get_sha256(path));f.close()
 print("CTF_BAKED ",key," polygons=",mesh.get_polygon_count())
 level.free();quit()
