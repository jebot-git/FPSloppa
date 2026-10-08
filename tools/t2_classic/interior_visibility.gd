extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.selected_map="ctf_t2_gorgon";g.start_host("Interior shader check",0,100,10,true,"st");g.set_process(false);g.set_physics_process(false)
 var level=g.get_node("Map");var failures: Array=[];var checks:=0
 for key in ["ctf_t2_gorgon","dm_q30_abattoir","de_varq_santorini"]:
  g.current_map=key
  var motion=preload("res://deathmatch/maps/surface_motion.gd").new();g.add_child(motion);motion.configure(g,level)
  for mat in motion.shaded:
   if mat.shader==preload("res://deathmatch/maps/quake_light.gdshader"):
    checks+=1
    if not is_equal_approx(float(mat.get_shader_parameter("minimum_baked_light")),.3 if key=="ctf_t2_gorgon" else 0.):failures.append(key)
  motion.free()
 var report={"checks":checks,"failures":failures};FileAccess.open("res://tools/t2_classic/interior-shader-validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INTERIOR_SHADER_RESULT ",JSON.stringify(report));g.free();quit(0 if failures.is_empty() and checks>0 else 1)
