extends SceneTree
const C=preload("res://tools/lighting_experiment/candidates1011/common.gd")
const Variants=preload("res://tools/lighting_experiment/candidates1011/variants.gd")
func _initialize():run.call_deferred()
func run() -> void:
 var setup:=C.setup(self,Vector2i(1280,800));var world: Node3D=setup[0];var camera: Camera3D=setup[1]
 var records: Array=[]
 for map in C.PROBES:
  C.Atlas.apply(world,map);camera.position=C.PROBES[map]
  camera.look_at(Vector3(-8,12,-28) if map=="tf_vesper" else Vector3(0,5.6,-9.4))
  for variant in ["baseline","reflection","directional","combined"]:
   var level:=C.scene(map);world.add_child(level);C.still(level,true);Variants.apply(level,map,variant,true)
   for i in 30:await process_frame
   var counts: Array=[]
   for i in 30:await process_frame;counts.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
   records.append({"map":map,"variant":variant,"global_draw_calls":C.stats(counts)})
   level.free();for i in 3:await process_frame
 world.free();FileAccess.open(C.OUT+"draws.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "));print("CANDIDATE_DRAW_AUDIT_PASS");quit()
