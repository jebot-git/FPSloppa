extends SceneTree
const Exit=preload("res://deathmatch/maps/teleport_exit.gd")
var game
var failures: Array=[]
func _initialize():run.call_deferred()
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.selected_map="qsrc_dm1";game.start_host("Teleport map audit",0,100,10,true)
 game.set_process(false);game.set_physics_process(false);game.bots.free();game.bots=null
 var rows: Array=[]
 var maps: Array=["qsrc_dm1","qsrc_dm2","qsrc_dm3","qsrc_dm4","qsrc_dm5","qsrc_dm6","koth_torture","koth_alichar","cc_psychofuge","cc_ghostquarter","cc_basement","ctf_confluence","ctf_skyfracture"]
 DirAccess.make_dir_recursive_absolute("res://test-results/teleport-exits")
 for path in OS.get_cmdline_user_args():
  var id: String=path.get_file().get_basename()
  game.map_catalog.append({"id":id,"title":id,"path":path,"scene":"res://test-results/teleport-exits/"+id+".scn","sha256":FileAccess.get_sha256(path)})
  maps.append(id)
 for name in maps:
  if not game._load_map(name):failures.append("Map load: "+name);continue
  var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
  for id in game.fighters:game.fighters[id].position=Vector3(10000,10000,10000)
  await physics_frame;await physics_frame
  for key in runtime.destinations:
   var authored: Dictionary=runtime.destinations[key]
   var resolved:=Exit.resolve(runtime,authored)
   var clear:=not resolved.is_empty()
   var unchanged: bool=clear and resolved.position.is_equal_approx(authored.position) and absf(angle_difference(resolved.yaw,authored.yaw))<.001
   var forward:=0.
   if clear:
    var probe:=Exit.query(resolved.position,1.65);probe.motion=Vector3.FORWARD.rotated(Vector3.UP,resolved.yaw)*3.
    forward=game.get_world_3d().direct_space_state.cast_motion(probe)[0]*3.
   var ok: bool=clear and unchanged and forward>=1.
   if not ok:failures.append(name+":"+key)
   rows.append({"map":name,"target":key,"clear":clear,"authored_exit_preserved":unchanged,"forward_clearance_m":forward})
   print("PASS " if ok else "FAIL ",name," ",key," forward=",forward)
 DirAccess.make_dir_recursive_absolute("res://test-results/teleport-exits")
 FileAccess.open("res://test-results/teleport-exits/maps.json",FileAccess.WRITE).store_string(JSON.stringify({"destinations":rows,"failures":failures},"  "))
 game.free();print("TELEPORT_MAPS_RESULT ",JSON.stringify({"destinations":rows.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
