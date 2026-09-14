extends RefCounted
## Standing height is measured in tracking space, independent of virtual movement.
var baseline:=0.0
var crouched:=false
var prone:=false
func reset() -> void:baseline=0.0;crouched=false;prone=false
func sample(height: float,allowed: bool,allow_prone: bool=false) -> float:
	if not allowed or not is_finite(height) or height<preload("res://deathmatch/vr/poses.gd").MIN_HEAD_HEIGHT or height>3.2:crouched=false;prone=false;return 1.65
	if not allow_prone:prone=false
	elif not prone and height<.55:prone=true
	elif prone and height>.68:prone=false
	if prone:crouched=true;return clampf(height+.10,.65,.79)
	if baseline<=0:baseline=height
	# Never adapt down into a held crouch. Recenter deliberately resets calibration.
	if not crouched and height<baseline-.30:crouched=true
	elif crouched and height>baseline-.20:crouched=false
	return clampf(height+.10,.80,1.65) if crouched else 1.65
