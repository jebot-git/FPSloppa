extends "res://deathmatch/haptics/osc.gd"
## Shares the bounded logical-vest scheduler; replaces OSC transport with native BLE.
const EXTENSION="res://addons/bhaptics_native/bhaptics.gdextension"
var bridge: RefCounted
var intensity:=.25
var opened:=false
func is_open() -> bool:return opened and bridge!=null
func open(_host: String,_port: int) -> Error:
	close();error=""
	if bridge and bridge.is_running():
		error="Previous Bluetooth session is closing. Toggle Enable again in a moment.";return ERR_BUSY
	bridge=null
	if not preload("res://deathmatch/haptics/platform.gd").supports_native():
		error="Direct Bluetooth needs a supported desktop x86_64 or Android ARM64 build.";return ERR_UNAVAILABLE
	if OS.get_name()=="Android" and not Engine.has_singleton("FpsloppaBhapticsAndroid"):
		error="Android Bluetooth component is missing. Rebuild its AAR and export with Gradle.";return ERR_UNAVAILABLE
	if not ClassDB.class_exists("FpsloppaBhapticsBle") and FileAccess.file_exists(EXTENSION):
		GDExtensionManager.load_extension(EXTENSION)
	if not ClassDB.class_exists("FpsloppaBhapticsBle"):
		error="Native Bluetooth plugin is not built. See BHAPTICS.md.";return ERR_UNAVAILABLE
	bridge=ClassDB.instantiate("FpsloppaBhapticsBle")
	if not bridge.has_method("submit_levels"):
		error="Native Bluetooth plugin is outdated. Rebuild it using BHAPTICS.md.";bridge=null;return ERR_UNAVAILABLE
	opened=true;next_send=0;return OK
func _send(states: PackedByteArray) -> void:
	if is_open():bridge.submit_frame(states,intensity)
func _send_levels(levels: PackedByteArray) -> void:
	if is_open():bridge.submit_levels(levels,intensity)
func stop() -> void:
	expires.fill(0.0);cues.clear();next_send=0
	if bridge:bridge.stop()
func close() -> void:
	stop();opened=false
	# Keep the instance until its worker exits; UI changes must not wait for BLE teardown.
	if bridge:bridge.close()
func scan() -> void:
	stop()
	if is_open() and prepare_android():bridge.scan()
func prepare_android() -> bool:
	if OS.get_name()=="Android":
		var helper=Engine.get_singleton("FpsloppaBhapticsAndroid")
		if not helper.prepare():error=helper.status_text();return false
	error="";return true
func connect_device(id: String) -> bool:
	stop();return bridge.connect_device(id) if is_open() and prepare_android() else false
func devices() -> Array:
	if not bridge:return []
	var result: Variant=JSON.parse_string(bridge.devices_json())
	return result if result is Array else []
func status_text() -> String:
	return error if not error.is_empty() else bridge.status_text() if bridge else "Native Bluetooth closed."
