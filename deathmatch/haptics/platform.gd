extends RefCounted
## Platforms with a native build recipe and descriptor entry, not a hardware certification.
static func supports_native(system: String=OS.get_name(),architecture: String=Engine.get_architecture_name()) -> bool:
	return system in ["Linux","Windows"] and architecture=="x86_64" or system=="Android" and architecture=="arm64"
static func default_backend(system: String=OS.get_name(),architecture: String=Engine.get_architecture_name()) -> String:
	return "ble" if supports_native(system,architecture) else "osc"
