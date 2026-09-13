extends SceneTree
const C=preload("res://tools/lighting_experiment/candidates1011/common.gd")
const AXES=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
const UPS=[Vector3.DOWN,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN]
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func tex(c: Color) -> ImageTexture:
 var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(c);return ImageTexture.create_from_image(image)
func pixel() -> Color:
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image().get_pixel(128,128)
func run() -> void:
 root.size=Vector2i(256,256);root.content_scale_size=root.size
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;world.add_child(env)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,4);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.make_current()
 var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(4,4);world.add_child(mesh)
 var images: Array[Image]=[]
 for face in 6:
  var image:=Image.create(128,128,false,Image.FORMAT_RGB8);var right: Vector3=AXES[face].cross(UPS[face])
  for y in 128:
   for x in 128:
    var ray: Vector3=(AXES[face]+right*((x+.5)/64-1)-UPS[face]*((y+.5)/64-1)).normalized()
    image.set_pixel(x,y,Color(ray.x*.5+.5,ray.y*.5+.5,ray.z*.5+.5))
  image.flip_y() # Godot TextureLayered cubemap storage uses the opposite row origin.
  images.append(image)
 var cube:=Cubemap.new();assert(cube.create_from_images(images)==OK)
 var shader:=Shader.new();shader.code="shader_type spatial; render_mode unshaded, fog_disabled; uniform samplerCube cube : source_color, filter_linear; uniform vec3 axis; void fragment(){ ALBEDO=texture(cube,axis).rgb; }"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("cube",cube);mesh.material_override=material
 var orientation: Array=[]
 for axis in AXES+[Vector3(1,.4,.7).normalized(),Vector3(-.3,1,.6).normalized(),Vector3(.8,-.6,-1).normalized()]:
  material.set_shader_parameter("axis",axis)
  var actual: Color=await pixel();var expected:=Color(axis.x*.5+.5,axis.y*.5+.5,axis.z*.5+.5)
  var error:=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
  check(error<.015,"Cubemap orientation "+str(axis));orientation.append({"axis":str(axis),"max_error":error})
 var normal:=ShaderMaterial.new();normal.shader=load("res://tools/lighting_experiment/candidates1011/directional.gdshader")
 normal.set_shader_parameter("base_texture",tex(Color.WHITE));normal.set_shader_parameter("base_nearest",normal.get_shader_parameter("base_texture"));normal.set_shader_parameter("base_linear",normal.get_shader_parameter("base_texture"))
 normal.set_shader_parameter("bake_texture",tex(Color(.1,.1,.1)));normal.set_shader_parameter("contrast_lighting",true);normal.set_shader_parameter("normal_strength",1.0)
 normal.set_shader_parameter("candidate_detail",tex(Color(.8,.5,.9,1)));mesh.material_override=normal
 normal.set_shader_parameter("candidate_direction",tex(Color8(205,128,230,255)));var plus: Color=await pixel()
 normal.set_shader_parameter("candidate_direction",tex(Color8(51,128,230,255)));var minus: Color=await pixel()
 check(plus.r>minus.r+.04,"+S normal responds to +S light, not -S light")
 normal.set_shader_parameter("candidate_detail",tex(Color(.5,.8,.9,1)))
 normal.set_shader_parameter("candidate_direction",tex(Color8(128,205,230,255)));var tplus: Color=await pixel()
 normal.set_shader_parameter("candidate_direction",tex(Color8(128,51,230,255)));var tminus: Color=await pixel()
 check(tplus.r>tminus.r+.04,"-T normal/light signs agree")
 normal.set_shader_parameter("candidate_direction",tex(Color8(205,128,230,0)));var ambient_a: Color=await pixel()
 normal.set_shader_parameter("normal_strength",0.0);var ambient_b: Color=await pixel()
 check(ambient_a.is_equal_approx(ambient_b),"Zero direct light preserves ambient shading")
 FileAccess.open(C.OUT+"fixtures.json",FileAccess.WRITE).store_string(JSON.stringify({"cubemap_orientation":orientation,"s_response":[plus.r,minus.r],"t_response":[tplus.r,tminus.r],"ambient_unchanged":ambient_a.is_equal_approx(ambient_b),"failures":failures},"  "))
 world.free();print("CANDIDATES1011_FIXTURES_RESULT ",failures);quit(0 if failures.is_empty() else 1)
