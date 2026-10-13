extends "res://deathmatch/avatars/rig.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
func _process(delta:float) -> void:
	var stamp:=Meter.begin("avatar_update");super._process(delta)
	Meter.leaf("tracked_head_neck_arms_ik",roundi(arm_update_ms*1000))
	Meter.end("avatar_update",stamp)
