extends RefCounted
const OUT="res://test-results/candidates789/"
func find(level: Node,name: String) -> ShaderMaterial:
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_meta("bsp_texture_name","")==name:return mat
 return null
func run(tree: SceneTree) -> Array:
 DirAccess.make_dir_recursive_absolute(OUT+"materials")
 var world:=Node3D.new();tree.root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5;camera.make_current()
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.025,.025);world.add_child(environment)
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(4.5,4.5);mesh.mesh=quad;world.add_child(mesh)
 var image:=Image.create(2,2,false,Image.FORMAT_RGB8);image.fill(Color(.035,.035,.035));var bake:=ImageTexture.create_from_image(image)
 var rows: Array=[]
 for spec in [["tf_pressureworks","tlight12"],["tf_vesper","stn_gr01_blu1"],["qsrc_dm2","*lava1"],["qsrc_dm2","rune2_1"]]:
  for variant in ["baseline","authored","packed_glow"]:
   var level: Node=ResourceLoader.load(OUT+"cache/"+spec[0]+"-"+variant+".scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   var source:=find(level,spec[1]);assert(source!=null)
   var mat:=source.duplicate() as ShaderMaterial
   var shader:=Shader.new();shader.code=source.shader.code.replace("void fragment()", "uniform float test_repeat = 1.0;\nvoid fragment()").replace("vec2 surface_uv = UV + map_uv_offset;", "vec2 surface_uv = UV * test_repeat + map_uv_offset;")
   mat.shader=shader;mat.set_shader_parameter("bake_texture",bake);mat.set_shader_parameter("liquid_warp",false);mat.set_shader_parameter("surface_variation",false);mat.set_shader_parameter("contrast_lighting",false);mesh.material_override=mat
   for repeat in [1,16]:
    mat.set_shader_parameter("test_repeat",float(repeat))
    for i in 15:await tree.process_frame
    await RenderingServer.frame_post_draw
    var name: String=spec[0]+"-"+spec[1].replace("*","")+"-"+str(repeat)+"-"+variant
    tree.root.get_texture().get_image().save_png(OUT+"materials/"+name+".png")
    rows.append({"map":spec[0],"texture":spec[1],"variant":variant,"repeat":repeat,"image":name+".png"})
   level.free()
 world.free();for i in 3:await tree.process_frame
 FileAccess.open(OUT+"materials/render.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 return rows
