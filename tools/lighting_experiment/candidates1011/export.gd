extends SceneTree
const OUT="res://test-results/candidates1011/"
const Loader=preload("res://test-results/candidates1011/importer/loader.gd")
const CHOSEN={"tf_vesper":["stn_gw02_gry1","med_dbrick6","metal_brnz_01"],"tf_pressureworks":["metal_iron1_07","ind_w02_blk1","med_cobstn1_2"]}
func _initialize():run.call_deferred()
func mats(level: Node) -> Array:
 var found: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:found[mat]=true
 return found.keys()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"sources");var records: Array=[]
 for map in CHOSEN:
  var source: Node=load("res://maps/cache/"+map+"-lightmap1.scn").instantiate()
  for mat in mats(source):
   var name: String=mat.get_meta("bsp_texture_name","")
   if not name in CHOSEN[map]:continue
   var image: Image=mat.get_shader_parameter("base_texture").get_image()
   image.save_png(OUT+"sources/"+map+"-"+name+".png")
   records.append({"map":map,"texture":name,"width":image.get_width(),"height":image.get_height()})
  var direction:=Loader.read(OUT+"direction/"+map+".bsp");assert(direction!=null)
  var dm:=mats(direction);var sm:=mats(source)
  assert(dm[0].get_shader_parameter("bake_texture").get_size()==sm[0].get_shader_parameter("bake_texture").get_size())
  var di: Image=dm[0].get_shader_parameter("bake_texture").get_image();di.set_pixel(0,0,Color(.5,.5,1,0))
  assert(ResourceSaver.save(ImageTexture.create_from_image(di),OUT+"direction/"+map+".res",ResourceSaver.FLAG_COMPRESS)==OK)
  # Direction texels and irradiance must use exactly the same UV2 layout.
  var a:=source.find_children("*","MeshInstance3D",true,false);var b:=direction.find_children("*","MeshInstance3D",true,false)
  assert(a.size()==b.size())
  for j in a.size():
   if not a[j].mesh:continue
   for k in a[j].mesh.get_surface_count():
    var aa: Array=a[j].mesh.surface_get_arrays(k);var bb: Array=b[j].mesh.surface_get_arrays(k)
    assert(aa[Mesh.ARRAY_TEX_UV2]==bb[Mesh.ARRAY_TEX_UV2])
  source.free();direction.free();print("DIRECTION_ATLAS_ALIGNED ",map);await process_frame
 FileAccess.open(OUT+"sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "));quit()
