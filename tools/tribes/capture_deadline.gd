extends RefCounted
## Test policy, measured in game seconds and independent of time scale.
const LIMIT:=600.0
var first_capture_seconds:=-1.0
var last_capture_seconds:=-1.0
var last_pickup_seconds:=-1.0
var waiting_for_pickup:=false
var missed_pickup_deadline:=false
var previous_scores: Array=[0,0]
func observe(seconds: float,scores: Array) -> void:
	if scores[0]>previous_scores[0] or scores[1]>previous_scores[1]:
		if waiting_for_pickup and seconds-last_capture_seconds>LIMIT+.00001:missed_pickup_deadline=true
		if first_capture_seconds<0:first_capture_seconds=seconds
		last_capture_seconds=seconds;waiting_for_pickup=true
	previous_scores=scores.duplicate()
func pickup(seconds: float) -> void:
	last_pickup_seconds=seconds
	if not waiting_for_pickup:return
	if seconds-last_capture_seconds>LIMIT+.00001:missed_pickup_deadline=true
	else:waiting_for_pickup=false
func reason(seconds: float) -> String:
	if seconds>=LIMIT-.00001 and (first_capture_seconds<0 or first_capture_seconds>LIMIT+.00001):return "no_capture_600s"
	if missed_pickup_deadline or waiting_for_pickup and seconds-last_capture_seconds>=LIMIT-.00001:return "no_pickup_after_capture_600s"
	return ""
func expired(seconds: float) -> bool:
	return not reason(seconds).is_empty()
func snapshot() -> Dictionary:
	return {"first_capture_seconds":first_capture_seconds,"first_capture_limit_seconds":LIMIT,"last_capture_seconds":last_capture_seconds,"last_pickup_seconds":last_pickup_seconds,"waiting_for_pickup":waiting_for_pickup,"post_capture_pickup_limit_seconds":LIMIT}
