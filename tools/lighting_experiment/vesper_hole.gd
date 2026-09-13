extends SceneTree
var game
func _initialize():run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);
 if game.hud:game.hud.hide()
 game.map_catalog=[{"id":"tf_vesper","title":"Vesper","path":"res://maps/tf_vesper.bsp","sha256":FileAccess.get_sha256("res://maps/tf_vesper.bsp"),"scene":"res://test-results/map-presentation/runtime-cache/tf_vesper.scn"}]
 game._load_map("tf_vesper")
 for node in game.get_node("Map").find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 var camera: Camera3D=game.get_node("Overview");camera.position=Vector3(18,2.2,24);camera.look_at(Vector3(-8,12,-28));camera.make_current()
 await physics_frame;await physics_frame
 print("OLD_CAMERA_CONTENTS ",game.get_node("Map/MapRuntime").contents.at(camera.position))
 for pixel in [Vector2(880,700),Vector2(900,600),Vector2(850,570),Vector2(1100,700)]:
  var from:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
  var query:=PhysicsRayQueryParameters3D.create(from,from+direction*200,1);query.hit_back_faces=true
  var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
  print("HOLE_RAY ",pixel," floor=",from+direction*(-from.y/direction.y)," hit=",hit)
 if DisplayServer.get_name()!="headless":
  var materials: Dictionary={}
  for mesh in game.get_node("Map").find_children("*","MeshInstance3D",true,false):
   if mesh.mesh:
    for i in mesh.mesh.get_surface_count():materials[mesh.get_active_material(i)]=true
  for variant in ["ordinary","no_occlusion","two_sided","valid_camera"]:
   if variant=="valid_camera":
    camera.position=Vector3(15,2.2,24);camera.look_at(Vector3(-8,12,-28))
    print("VALID_CAMERA_CONTENTS ",game.get_node("Map/MapRuntime").contents.at(camera.position))
   if variant=="no_occlusion":root.use_occlusion_culling=false
   if variant=="two_sided":
    var shaders: Dictionary={}
    for mat in materials:
     if mat is ShaderMaterial:
      if not shaders.has(mat.shader):
       var shader:=Shader.new();shader.code=mat.shader.code.replace("specular_disabled;","specular_disabled, cull_disabled;");shaders[mat.shader]=shader
      mat.shader=shaders[mat.shader]
     elif mat is BaseMaterial3D:mat.cull_mode=BaseMaterial3D.CULL_DISABLED
   for i in 25:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/map-presentation/vesper-hole-"+variant+".png")
 game.free();quit()
