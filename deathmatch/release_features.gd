extends RefCounted
## ST is available in main development; published release builds are unchanged.
const TRIBES := true
static func map_allowed(id: String) -> bool:
	return TRIBES or id not in ["ctf_stonehenge", "ctf_raindance", "ctf_katabatic"]
