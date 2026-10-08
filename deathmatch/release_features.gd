extends RefCounted
## ST ships with dedicated maps and its equipment in 0.20v.
const TRIBES := true
static var retired: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/retired.json"))
static func map_allowed(id: String) -> bool:
	if id in retired:return false
	return TRIBES or not id.begins_with("ctf_t2_") and id not in ["ctf_stonehenge", "ctf_raindance", "ctf_katabatic"]
