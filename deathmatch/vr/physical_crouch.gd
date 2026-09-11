extends RefCounted
## Standing height is measured in tracking space, independent of virtual movement.
var baseline:=0.0
var crouched:=false
func reset() -> void:baseline=0.0;crouched=false
func sample(height: float,allowed: bool) -> float:
	if not allowed or not is_finite(height) or height<.35 or height>3.2:crouched=false;return 1.65
	if baseline<=0:baseline=height
	# Never adapt down into a held crouch. Recenter deliberately resets calibration.
	if not crouched and height<baseline-.30:crouched=true
	elif crouched and height>baseline-.20:crouched=false
	return clampf(height+.10,.80,1.65) if crouched else 1.65
