extends RefCounted
## Cosmetic, bounded-latency interpolation between remote IK samples.
var native_pose=preload("res://deathmatch/native/runtime.gd").pose()
var target: Dictionary={}
var shown: Dictionary={}
var rows: Array=[]
var position_bones: Dictionary={}
var elapsed:=0.0
var period:=0.0
func reset() -> void:
	if target.is_empty() and shown.is_empty():return
	target={};shown={};rows.clear();elapsed=0;period=0
func push(pose: Dictionary,seconds: float) -> void:
	target=pose.duplicate(true);rows.clear();elapsed=0;period=seconds
	for index in target:
		var next: Array=target[index];var previous: Array=shown.get(index,next)
		var changes_rotation: bool=not previous[0].is_equal_approx(next[0])
		var changes_position: bool=not previous[1].is_equal_approx(next[1])
		rows.append([index,previous[0],next[0],previous[1],next[1],changes_rotation,changes_position,position_bones.is_empty() or position_bones.has(index) or changes_position])
		if not shown.has(index):shown[index]=next.duplicate()
func apply(sk: Skeleton3D,delta: float) -> void:
	elapsed+=delta
	var weight:=clampf(elapsed/period,0,1) if period>0 else 1.0
	if native_pose:
		native_pose.blend(sk,rows,shown,weight);return
	for row in rows:
		var rotation: Quaternion=row[1].slerp(row[2],weight) if row[5] and weight<1 else row[2]
		sk.set_bone_pose_rotation(row[0],rotation);shown[row[0]][0]=rotation
		if row[7]:
			var position: Vector3=row[3].lerp(row[4],weight) if row[6] and weight<1 else row[4]
			sk.set_bone_pose_position(row[0],position);shown[row[0]][1]=position
