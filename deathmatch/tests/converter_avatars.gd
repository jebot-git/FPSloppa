extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var library:=Library.new();root.add_child(library)
 var world:=Node3D.new();root.add_child(world)
 var failures:=0;var tested:=0
 for path in OS.get_cmdline_user_args():
  var hash:=library.register_file(path,false)
  var avatar:=library.create_avatar(hash) if not hash.is_empty() else null
  if not avatar:failures+=1;print("CONVERTER_GAME_IMPORT FAIL ",library.last_error);continue
  world.add_child(avatar);avatar.preview_mode=2
  await process_frame
  if not avatar.skeleton or avatar.skeleton.get_bone_count()<15:failures+=1
  else:
   for i in avatar.skeleton.get_bone_count():
    if not avatar.skeleton.get_bone_global_pose(i).is_finite():failures+=1
  if not avatar.motion.has_animation("walk") or not avatar.solver is SkeletonModifier3D:failures+=1
  print("CONVERTER_GAME_IMPORT ",path.get_file()," bones=",avatar.skeleton.get_bone_count())
  avatar.free();tested+=1
 library.free();world.free();print("CONVERTER_GAME_IMPORT_DONE tested=",tested," failures=",failures)
 quit(1 if failures or tested==0 else 0)
