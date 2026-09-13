extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Assets=preload("res://deathmatch/maps/surface_assets.gd")
const Motion=preload("res://deathmatch/maps/surface_motion.gd")
class Game extends Node:
 var current_map:=""
 var presentation: Dictionary={}
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var game:=Game.new();root.add_child(game)
 var maps: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 var report: Array=[]
 for row in maps:
  if row.get("distribution","base")!="base":continue
  var level: Node=load("res://test-results/map-presentation/cache/"+row.id+".scn").instantiate()
  Filtering.new().apply(level,2,true,0)
  game.current_map=row.id
  var motion:=Motion.new();game.add_child(motion);motion.configure(game,level);motion.set_process(false)
  for liquid in motion.liquids:check(liquid.material.get_shader_parameter("liquid_warp")==true,row.id+": liquid marked for warp")
  motion.advance(.21)
  for animated in motion.animated:
   check(animated.material.get_shader_parameter("base_texture")==animated.frames[1].base,row.id+": second frame active")
  motion.apply({"surface_animation":false})
  for animated in motion.animated:check(animated.material.get_shader_parameter("base_texture")==animated.base,row.id+": disabling restores frame")
  for liquid in motion.liquids:check(not liquid.material.get_shader_parameter("liquid_warp"),row.id+": warp disabled")
  report.append({"id":row.id,"liquid_materials":motion.liquids.size(),"animated_materials":motion.animated.size()})
  motion.free();level.free()
 # A real third-party BSP without opt-in lightmaps exercises StandardMaterial.
 var path:="res://test-results/lighting-coverage/external-original.bsp"
 var level:=Loader.read(path);check(level!=null,"unbaked external imports")
 Filtering.new().apply(level,2,true)
 game.current_map="external-original"
 var motion:=Motion.new();game.add_child(motion);motion.configure(game,level);motion.set_process(false)
 check(motion.shaded.is_empty(),"external BSP retains unbaked shading")
 motion.advance(.21)
 for liquid in motion.drifting:
  check(liquid.material.uv1_offset!=liquid.offset and liquid.material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"external liquids drift while remaining opaque")
 motion.apply({"surface_animation":false})
 for liquid in motion.drifting:check(liquid.material.uv1_offset==liquid.offset,"external liquid restores original UV offset")
 check(level.get_meta("map_tinted_vertices",0)==0,"external artwork not weathered")
 report.append({"id":"external-original","sha256":FileAccess.get_sha256(path),"liquid_materials":motion.liquids.size(),"unbaked_drifting_materials":motion.drifting.size()})
 motion.free();level.free()
 level=Loader.read("res://test-results/map-presentation/unbaked-dm1.bsp")
 Filtering.new().apply(level,2,true)
 motion=Motion.new();game.add_child(motion);motion.configure(game,level);motion.set_process(false)
 check(motion.drifting.size()==2 and motion.animated.size()==1,"unbaked control imports both liquid and frame animation")
 motion.advance(.21)
 for liquid in motion.drifting:check(liquid.material.uv1_offset!=liquid.offset and liquid.material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"unbaked drift remains opaque")
 for animated in motion.animated:check(animated.material.albedo_texture==animated.frames[1].base,"unbaked frame changes")
 motion.apply({"surface_animation":false})
 for liquid in motion.drifting:check(liquid.material.uv1_offset==liquid.offset,"unbaked drift reset")
 for animated in motion.animated:check(animated.material.albedo_texture==animated.base,"unbaked frame reset")
 report.append({"id":"unbaked-dm1-control","liquid_materials":motion.drifting.size(),"animated_materials":motion.animated.size()})
 motion.free();level.free();game.free()
 var result:={"maps":report,"failures":failures}
 FileAccess.open("res://test-results/map-presentation/integration.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("PRESENTATION_INTEGRATION_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
