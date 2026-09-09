extends SkeletonModifier3D
# Use the glove artist's poses: these skeletons do not use humanoid finger axes.
# Only finger rotations change; calibrated wrist transforms and bone lengths stay intact.
var curls:=PackedFloat32Array([0,0,0,0,0])
var displayed:=PackedFloat32Array([0,0,0,0,0])
var rotations: Array=[]
func setup(model: Node,side: String) -> void:
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	skeleton.add_child(self)
	var tree: AnimationTree=model.get_node("AnimationTree")
	tree.active=false
	var opened: Animation=load("res://addons/godot-xr-tools/hands/animations/"+side+"/Straight.res")
	var closed: Animation=load("res://addons/godot-xr-tools/hands/animations/"+side+"/Grip.res")
	for track in range(opened.get_track_count()):
		if opened.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
		var path:=opened.track_get_path(track)
		var bone_name:=str(path.get_subname(0))
		var finger:=["Thumb","Index","Middle","Ring","Little"].find(bone_name.get_slice("_",0))
		var bone:=skeleton.find_bone(bone_name)
		var end_track:=closed.find_track(path,Animation.TYPE_ROTATION_3D)
		if finger<0 or bone<0 or end_track<0: continue
		rotations.append([bone,finger,opened.rotation_track_interpolate(track,0),closed.rotation_track_interpolate(end_track,0)])

func _process_modification_with_delta(delta: float) -> void:
	var skeleton:=get_skeleton()
	if not skeleton: return
	for finger in range(5): displayed[finger]=lerpf(displayed[finger],curls[finger],1-exp(-20*delta))
	for entry in rotations:
		skeleton.set_bone_pose_rotation(entry[0],entry[2].slerp(entry[3],displayed[entry[1]]))
