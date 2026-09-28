extends RefCounted
## Enabled only on experimental/st-raindance; the release branch keeps this off.
const TRIBES := true
static func map_allowed(id: String) -> bool:
	return TRIBES or id not in ["ctf_stonehenge", "ctf_raindance"]
