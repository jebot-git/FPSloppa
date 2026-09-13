extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Assets=preload("res://deathmatch/maps/surface_assets.gd")
const Motion=preload("res://deathmatch/maps/surface_motion.gd")
const OUT="res://test-results/map-presentation/surfaces/"
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func shot(label: String) -> PackedByteArray:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var img:=root.get_texture().get_image();img.save_png(OUT+label+".png")
 return img.get_data()
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5;camera.make_current()
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(7.5,4.5);mesh.mesh=quad;world.add_child(mesh)
 var image:=Image.create(2,2,false,Image.FORMAT_RGB8);image.fill(Color(.5,.5,.5));var bake:=ImageTexture.create_from_image(image)
 var report: Array=[]
 for sample in [["koth_hyperborea","+0grk_jumppad"],["qsrc_dm1","*teleport"],["qsrc_dm2","*lava1"]]:
  var level: Node=load("res://test-results/map-presentation/cache/"+sample[0]+".scn").instantiate()
  var filter:=Filtering.new();filter.apply(level,2,true,1)
  var original: ShaderMaterial
  for mat in filter.materials:
   if mat is ShaderMaterial and mat.get_meta("bsp_texture_name","")==sample[1]:original=mat;break
  check(original!=null,sample[0]+": source material found")
  if not original:level.free();continue
  var material:=original.duplicate() as ShaderMaterial
  # Deterministic timestamps exercise the production warp expression exactly.
  var shader:=Shader.new();shader.code=Filtering.BAKED.code.replace("void fragment()", "uniform float test_time = 0.0;\nvoid fragment()").replace("TIME","test_time")
  material.shader=shader;material.set_shader_parameter("bake_texture",bake);mesh.material_override=material
  var key:=Assets.sequence(sample[1]);var frames: Array=level.get_meta(Assets.FRAME_TAG,{}).get(key,[])
  var name: String=sample[0]+"-"+sample[1].replace("*","").replace("+","")
  var baseline:=await shot(name+"-off")
  var captures: Array=[]
  for i in 3:
   if frames.is_empty():material.set_shader_parameter("liquid_warp",true);material.set_shader_parameter("test_time",float(i)*1.25)
   else:
    var selected: Dictionary=frames[i%frames.size()];Motion.bind(material,selected.base,selected.glow,selected.glow!=null)
   captures.append(await shot(name+"-"+str(i)))
  check(captures[0]!=captures[1] and captures[1]!=captures[2],name+": frames visibly animate")
  material.set_shader_parameter("liquid_warp",false)
  Motion.bind(material,original.get_shader_parameter("base_texture"),original.get_shader_parameter("glow_texture"),original.get_shader_parameter("has_glow")==true)
  var restored:=await shot(name+"-restored")
  check(baseline==restored,name+": toggle restores exact pixels")
  report.append({"map":sample[0],"texture":sample[1],"animated":captures[0]!=captures[1],"restored":baseline==restored,"source_glow":original.get_shader_parameter("has_glow")==true})
  level.free()
 FileAccess.open(OUT+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":report,"failures":failures},"  "))
 world.free();for i in 3:await process_frame
 print("SURFACE_RENDER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
