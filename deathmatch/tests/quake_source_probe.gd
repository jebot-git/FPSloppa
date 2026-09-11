extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args();var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var path: String=input.path;var key: String=input.name;var hash:=FileAccess.get_sha256(path)
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-probe.scn","sha256":hash}];game._load_map(key)
 await physics_frame;await physics_frame
 for sample in input.water:
  if sample.rise>=.05:continue
  var a: Array=sample.position;var feet:=Vector3(a[0],a[1],a[2]);var shape:=CapsuleShape3D.new();shape.height=1.65;shape.radius=.30
  var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform.origin=feet+Vector3.UP*.83;q.motion=Vector3.UP;q.collision_mask=1;q.margin=.001
  var fractions: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(q)
  print("HEADROOM_PROBE ",JSON.stringify({"map":key,"feet":a,"measured_swim_rise":sample.rise,"clear_upward_metres":fractions[0],"geometry_blocks_upward_swimming":fractions[0]<.05}))
 game.free();quit()
