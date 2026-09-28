extends RefCounted
## Deferred experiments stay in source but cannot be enabled in this release.
const TRIBES := false
static func map_allowed(id: String) -> bool:
	return TRIBES or id != "ctf_stonehenge"
