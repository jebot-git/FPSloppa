extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 var bake=preload("res://deathmatch/maps/baked_light.gd").new();bake.open("res://maps/qsrc_dm6.bsp")
 check(bake.enabled and bake.quake_response,"DM6 selects authored Quake response")
 var level:=Node3D.new();root.add_child(level)
 for special in [false,true]:
  var uvs:=bake.face_uvs(PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]),Vector2(16,16),-1,-1,special)
  var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]);arrays[Mesh.ARRAY_TEX_UV2]=uvs
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(0,bake.material(StandardMaterial3D.new()))
  var node:=MeshInstance3D.new();node.mesh=mesh;level.add_child(node)
 bake.finish(level)
 for i in level.get_child_count():
  var node=level.get_child(i);var mat: ShaderMaterial=node.mesh.surface_get_material(0)
  var atlas: Image=mat.get_shader_parameter("bake_texture").get_image()
  var uv: Vector2=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2][0]
  var color:=atlas.get_pixelv(Vector2i(uv*atlas.get_width()))
  check(color.r<.001 if i==0 else absf(color.r-.5)<.01,"Atlas packing preserves "+("black unlit wall" if i==0 else "full-bright special surface"))
 level.free()
 if DisplayServer.get_name()=="headless":
  print("QUAKE_LIGHT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1);return
 root.size=Vector2i(800,200);root.content_scale_size=root.size
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=10;world.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.light_energy=10;world.add_child(sun)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.make_current()
 var source:=Image.create(1,1,false,Image.FORMAT_RGB8);source.fill(Color.WHITE);var white:=ImageTexture.create_from_image(source)
 var samples: Array=[0,32,64,128,255]
 for i in samples.size():
  var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(1.6,2);quad.position.x=(i-2)*1.6
  var mat:=ShaderMaterial.new();mat.shader=preload("res://deathmatch/maps/quake_light.gdshader")
  for key in ["base_texture","base_nearest","base_linear"]:mat.set_shader_parameter(key,white)
  var light:=Image.create(1,1,false,Image.FORMAT_RGB8);light.fill(Color8(samples[i],samples[i],samples[i]));mat.set_shader_parameter("bake_texture",ImageTexture.create_from_image(light))
  quad.material_override=mat;world.add_child(quad)
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 var pixels:=root.get_texture().get_image()
 pixels.save_png("res://test-results/quake-light-response.png")
 for i in samples.size():
  var actual:=roundi(pixels.get_pixel(80+i*160,100).r*255)
  var expected:=mini(255,2*int(samples[i]))
  check(absi(actual-expected)<=3,"Rendered light sample %d gives %d (expected %d) despite ambient/sun fill"%[samples[i],actual,expected])
 world.free();print("QUAKE_LIGHT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
