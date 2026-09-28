extends RefCounted
## Test policy, measured in game seconds and independent of time scale.
const LIMIT:=600.0
var first_capture_seconds:=-1.0
var previous_scores: Array=[0,0]
func observe(seconds: float,scores: Array) -> void:
	if first_capture_seconds<0 and (scores[0]>previous_scores[0] or scores[1]>previous_scores[1]):first_capture_seconds=seconds
	previous_scores=scores.duplicate()
func expired(seconds: float) -> bool:
	return seconds>=LIMIT-.00001 and (first_capture_seconds<0 or first_capture_seconds>LIMIT+.00001)
