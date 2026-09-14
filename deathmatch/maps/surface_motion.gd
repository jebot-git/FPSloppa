extends Node
const Assets=preload("res://deathmatch/maps/surface_assets.gd")
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
const BAKED=preload("res://deathmatch/maps/baked_light.gdshader")
var game: Node
var animated: Array=[]
var liquids: Array=[]
var shaded: Array=[]
var drifting: Array=[]
var elapsed:=0.0
var frame:=-1
var enabled:=true
func configure(arena: Node,level: Node) -> void:
 game=arena
 var bank: Dictionary=level.get_meta(Assets.FRAME_TAG,{})
 var seen: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(i)
   if not mat or seen.has(mat):continue
   seen[mat]=true
   var baked: bool=mat is ShaderMaterial and mat.shader in [BAKED,preload("res://deathmatch/maps/quake_light.gdshader")]
   if not baked and not mat is BaseMaterial3D:continue
   var name:=str(mat.get_meta("bsp_texture_name",""))
   if baked:shaded.append(mat)
   if name.begins_with("*"):
    liquids.append({"material":mat,"offset":mat.uv1_offset if mat is BaseMaterial3D else Vector3.ZERO})
    if mat is BaseMaterial3D:drifting.append(liquids.back())
   var key:=Assets.sequence(name)
   if not key.is_empty() and bank.has(key):
    animated.append({"material":mat,"frames":bank[key],"base":mat.get_shader_parameter("base_texture") if baked else mat.albedo_texture,"glow":mat.get_shader_parameter("glow_texture") if baked else mat.emission_texture,"has_glow":(mat.get_shader_parameter("has_glow")==true) if baked else mat.emission_enabled})
 apply(game.presentation)
func apply(values: Dictionary) -> void:
 enabled=bool(values.get("surface_animation",true))
 for mat in shaded:mat.set_shader_parameter("surface_variation",bool(values.get("surface_variation",true)))
 for row in liquids:
  var mat: Material=row.material
  if mat is ShaderMaterial:mat.set_shader_parameter("liquid_warp",enabled)
  elif not enabled:mat.uv1_offset=row.offset
 frame=-1
 if not enabled:
  for row in animated:bind(row.material,row.base,row.glow,row.has_glow)
 Atmosphere.apply(game,str(game.current_map))
 set_process(enabled and (not drifting.is_empty() or not animated.is_empty()))
 if enabled:advance(0.0)
static func bind(mat: Material,base: Texture2D,glow: Texture2D,has_glow: bool) -> void:
 if mat is ShaderMaterial:
  for suffix in ["_texture","_nearest","_linear"]:
   mat.set_shader_parameter("base"+suffix,base);mat.set_shader_parameter("glow"+suffix,glow)
  mat.set_shader_parameter("has_glow",has_glow)
 else:
  mat.albedo_texture=base;mat.emission_texture=glow;mat.emission_enabled=has_glow
func advance(delta: float) -> void:
 if not enabled:return
 elapsed=fmod(elapsed+delta,3600.0)
 var next:=int(floor(elapsed*5.0))
 if next!=frame:
  frame=next
  for row in animated:
   var selected: Dictionary=row.frames[frame%row.frames.size()]
   bind(row.material,selected.base,selected.glow,selected.glow!=null)
 # Unbaked imported StandardMaterials share base/emission UV1. Keep their
 # original shading and transparency; use bounded drift instead of replacement.
 for row in drifting:
  row.material.uv1_offset=row.offset+Vector3(sin(elapsed*.8),cos(elapsed*.7),0)*.025
func _process(delta: float) -> void:advance(delta)
