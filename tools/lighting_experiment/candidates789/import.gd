extends SceneTree
const Loader=preload("res://test-results/candidates789/importer/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Packing=preload("res://tools/lighting_experiment/candidates789/packing.gd")
const OUT="res://test-results/candidates789/"
var report: Array=[]
func _initialize():run.call_deferred()
func save(level: Node,path: String) -> void:
 var packed:=PackedScene.new();assert(packed.pack(level)==OK);assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"cache")
 for map in ["tf_pressureworks","tf_vesper","qsrc_dm2","ctf_deepvault"]:
  for density in [false,true]:
   if density and not map.begins_with("tf_"):continue
   var path: String=(OUT+"density/" if density else "res://maps/")+map+".bsp"
   var level:=Loader.read(path);assert(level!=null)
   Filtering.new().apply(level,2,true,1)
   assert(level.get_meta("baked_light_invalid_faces")==0 and level.get_meta("baked_light_overflow_faces")==0)
   var label: String=map+("-density" if density else "-baseline")
   save(level,OUT+"cache/"+label+".scn")
   var stats:=Packing.pack(level)
   save(level,OUT+"cache/"+label+"-packed.scn")
   stats.map=map;stats.density=density;report.append(stats);level.free()
   FileAccess.open(OUT+"packing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
   print("CANDIDATE_IMPORT ",JSON.stringify(stats))
   await process_frame
 quit()
