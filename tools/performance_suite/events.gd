extends RefCounted
## Loaded only by disposable performance fixtures. Same event overhead in every mode.
static var enabled:=false
static var rows: Array=[]
static func record(kind: String,details: Dictionary) -> void:
	if enabled:rows.append({"type":kind,"ticks_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"details":details})
