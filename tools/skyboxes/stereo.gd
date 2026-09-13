extends SceneTree
const Catalog=preload("res://deathmatch/maps/skies/catalog.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func capture(camera: Camera3D,position: Vector3,yaw: float) -> Image:
 camera.position=position;camera.rotation=Vector3(.2,yaw,0)
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(512,512);root.content_scale_size=root.size
 var world:=WorldEnvironment.new();world.environment=Environment.new();root.add_child(world)
 world.environment.background_mode=Environment.BG_SKY
 var camera:=Camera3D.new();root.add_child(camera);camera.make_current()
 var records: Array=[];var seen: Array=[]
 for map in Catalog.MAPS:
  var name: String=Catalog.MAPS[map][0]
  if name in seen:continue
  seen.append(name);world.environment.sky=Catalog.create(map)
  var left: Image=await capture(camera,Vector3(-.032,1.7,0),0)
  var right: Image=await capture(camera,Vector3(.032,1.7,0),0)
  var moved: Image=await capture(camera,Vector3(3,2.1,4),0)
  var rotated: Image=await capture(camera,Vector3(3,2.1,4),.6)
  var stereo_equal:=left.get_data()==right.get_data()
  var translation_equal:=left.get_data()==moved.get_data()
  var rotation_changes:=left.get_data()!=rotated.get_data()
  if not stereo_equal or not translation_equal or not rotation_changes:failures.append(name)
  left.save_png("res://test-results/skyboxes/render/"+name+"-left.png")
  right.save_png("res://test-results/skyboxes/render/"+name+"-right.png")
  records.append({"sky":name,"same_64mm_stereo_background":stereo_equal,"no_room_scale_parallax":translation_equal,"head_rotation_changes_view":rotation_changes})
 world.free();camera.free()
 FileAccess.open("res://test-results/skyboxes/stereo.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"method":"Same projection at left/right 64 mm IPD, room-scale translation, and head rotation; native renderer, not an OpenXR device test.","records":records,"failures":failures},"  "))
 print("SKY_STEREO_RESULT ",failures);quit(0 if failures.is_empty() else 1)
