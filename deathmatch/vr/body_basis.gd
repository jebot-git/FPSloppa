extends RefCounted
## Body poses use a -Z-facing frame. Native XR joints use Humanoid bone axes.
const BONES={"hips":"Hips","chest":"Chest","left_foot":"LeftFoot","right_foot":"RightFoot","left_knee":"LeftLowerLeg","right_knee":"RightLowerLeg","left_elbow":"LeftLowerArm","right_elbow":"RightLowerArm"}
static var native_rest: Dictionary={}
static func native_to_facing(key: String, orientation: Basis) -> Basis:
	if native_rest.is_empty():
		var profile:=SkeletonProfileHumanoid.new()
		for i in range(profile.get_bone_size()):
			var bone_name: StringName=profile.get_bone_name(i)
			var parent: StringName=profile.get_bone_parent(i)
			native_rest[bone_name]=native_rest.get(parent,Basis.IDENTITY)*profile.get_reference_pose(i).basis
	return orientation*native_rest[BONES[key]].inverse()*Basis(Vector3.UP,PI)
