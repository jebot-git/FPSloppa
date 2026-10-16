extends Node
## Runs after fighters publish their current state. No scene access on workers.
var kernel=preload("res://deathmatch/native/animation.gd").create()
func _init()->void:process_priority=1;process_mode=Node.PROCESS_MODE_ALWAYS
func _process(delta:float)->void:
 if kernel:kernel.advance(delta,get_viewport().get_camera_3d())
static func attach(rig:Node3D)->void:
 if not is_instance_valid(rig):return
 if not rig.native_animation or not rig.is_inside_tree() or rig.native_batched:return
 var root:Viewport=rig.get_viewport()
 var batch=root.get_node_or_null("NativeAvatarBatch")
 if batch==null:
  batch=load("res://deathmatch/avatars/native_batch.gd").new();batch.name="NativeAvatarBatch";root.add_child(batch)
 if not batch.kernel:return
 if batch.kernel.configure(rig,rig.clips,rig.arm_profile,rig.lod_meshes):
  if rig.native_animation!=batch.kernel:rig.native_animation.detach(rig)
  rig.native_animation=batch.kernel;rig.native_bound=true;rig.native_batched=true;rig.native_batch_requested=true
