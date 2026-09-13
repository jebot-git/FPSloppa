extends SceneTree
const C=preload("res://tools/lighting_experiment/candidates1011/common.gd")
const AXES=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
const UPS=[Vector3.DOWN,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN]
func _initialize():run.call_deferred()
func run() -> void:
 assert(DisplayServer.get_name()!="headless")
 DirAccess.make_dir_recursive_absolute(C.OUT+"probes")
 var setup:=C.setup(self,Vector2i(256,256));var world: Node3D=setup[0];var camera: Camera3D=setup[1]
 camera.fov=90
 var records: Array=[]
 for map in C.PROBES:
  C.Atlas.apply(world,map);var env: Environment=world.get_node("Environment").environment
  # Linear tone mapping avoids baking Filmic twice. LDR capture still clips HDR.
  env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.0
  var level:=C.scene(map);world.add_child(level);C.still(level,true)
  var contents:=C.Contents.new();assert(contents.open("res://maps/"+map+".bsp") and contents.at(C.PROBES[map])==-1)
  for contrast in [false,true]:
   var mode: String="contrast" if contrast else "classic";C.still(level,contrast)
   camera.position=C.PROBES[map];var faces: Array[Image]=[]
   for i in 6:
    camera.look_at(camera.position+AXES[i],UPS[i])
    for frame in 15:await process_frame
    await RenderingServer.frame_post_draw
    var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGB8);image.save_png(C.OUT+"probes/"+map+"-"+mode+"-"+str(i)+".png")
    image.flip_y() # Verified against native samplerCube with off-axis direction fixtures.
    assert(image.generate_mipmaps()==OK);faces.append(image)
   var cube:=Cubemap.new();assert(cube.create_from_images(faces)==OK)
   assert(ResourceSaver.save(cube,C.OUT+"probes/"+map+"-"+mode+".res",ResourceSaver.FLAG_COMPRESS)==OK)
   records.append({"map":map,"mode":mode,"probe":str(C.PROBES[map]),"face_size":256,"mip_count":faces[0].get_mipmap_count(),"faces":6,"encoded_bytes":faces[0].get_data_size()*6,"capture":"offline LDR RGB8, linear tonemap, current sky, no fog; source material mode matches the test","prefilter":"ordinary mip chain; broad fixed LOD, not GGX convolution"})
  level.free();for i in 3:await process_frame
 FileAccess.open(C.OUT+"probes.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
 world.free();print("STATIC_PROBES_PASS");quit()
