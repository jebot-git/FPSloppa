extends RefCounted
## ST ships with all three dedicated maps and its equipment in 0.20v.
const TRIBES := true
static func map_allowed(id: String) -> bool:
	return TRIBES or id not in ["ctf_stonehenge", "ctf_raindance", "ctf_katabatic"]
