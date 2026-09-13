extends RefCounted
const C=preload("res://tools/lighting_experiment/candidates1011/common.gd")
static func apply(level: Node,map: String,variant: String,contrast: bool=true) -> Dictionary:
 var report: Dictionary={"materials":0,"direction_bytes":0,"detail_bytes":0,"probe_bytes":0}
 if variant in ["baseline","restored"]:return report
 var shader_name: String="reflection" if variant=="reflection" else "directional" if variant in ["directional","strong","flat"] else "combined"
 var shader: Shader=load("res://tools/lighting_experiment/candidates1011/"+shader_name+".gdshader")
 var direction: Texture2D
 if shader_name!="reflection":
  direction=ResourceLoader.load(C.OUT+"direction/"+map+".res","",ResourceLoader.CACHE_MODE_IGNORE)
  report.direction_bytes=direction.get_image().get_data_size()
 var probe: Cubemap
 if shader_name!="directional":
  probe=ResourceLoader.load(C.OUT+"probes/"+map+("-contrast" if contrast else "-classic")+".res","",ResourceLoader.CACHE_MODE_IGNORE)
  report.probe_bytes=probe.get_layer_data(0).get_data_size()*6
 var details: Dictionary={}
 for mat in C.materials(level):
  var name: String=mat.get_meta("bsp_texture_name","")
  if not name in C.SELECTED[map]:continue
  if not details.has(name):
   var image:=Image.load_from_file(C.OUT+"sources/"+map+"-"+name+"-detail.png")
   assert(image.generate_mipmaps(true)==OK)
   details[name]=ImageTexture.create_from_image(image);report.detail_bytes+=image.get_data_size()
  mat.shader=shader;mat.set_shader_parameter("candidate_detail",details[name])
  mat.set_shader_parameter("normal_strength",0.0 if variant=="flat" else .75 if variant=="strong" else .35)
  mat.set_shader_parameter("reflection_strength",.30 if name.begins_with("metal") or name.begins_with("ind_") else .18)
  if direction:mat.set_shader_parameter("candidate_direction",direction)
  if probe:
   mat.set_shader_parameter("candidate_probe",probe);mat.set_shader_parameter("candidate_probe_position",C.PROBES[map])
  report.materials+=1
 return report
