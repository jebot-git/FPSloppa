extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/candidates789/"
func _initialize():run.call_deferred()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"sources")
 var report: Array=[]
 for map in ["tf_pressureworks","tf_vesper","qsrc_dm2","ctf_deepvault"]:
  var level: Node=load("res://maps/cache/"+map+"-lightmap1.scn").instantiate()
  var filter:=Filtering.new();filter.apply(level,2,true,1)
  var textures: Array=[]
  for mat in filter.materials:
   if not mat is ShaderMaterial or mat.shader!=Filtering.BAKED:continue
   var name:=str(mat.get_meta("bsp_texture_name",""));var base: Texture2D=mat.get_shader_parameter("base_texture");var glow: Texture2D=mat.get_shader_parameter("glow_texture")
   textures.append({"name":name,"size":[base.get_width(),base.get_height()],"glow":glow!=null})
   if glow or name in ["tlight12","stn_gr01_red1","stn_gr01_blu1","metal_iron1_01"]:
    var stem: String=map+"-"+name.replace("*","")
    base.get_image().save_png(OUT+"sources/"+stem+"-base.png")
    if glow:glow.get_image().save_png(OUT+"sources/"+stem+"-glow.png")
  report.append({"map":map,"textures":textures});level.free()
 FileAccess.open(OUT+"sources.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit()
