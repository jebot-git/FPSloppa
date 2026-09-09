extends Node
## One permission dialog at a time; voice and tracking share this queue.
signal completed(permission: String, granted: bool)
const MICROPHONE := "android.permission.RECORD_AUDIO"
const QUEST_TRACKING := ["com.oculus.permission.BODY_TRACKING","com.oculus.permission.HAND_TRACKING","com.oculus.permission.EYE_TRACKING","com.oculus.permission.FACE_TRACKING"]
const PICO_TRACKING := ["com.picovr.permission.EYE_TRACKING"]
var pending: Array[String]=[]
var current := ""
var attempted: Dictionary={}
var results: Dictionary={}

func _ready() -> void:
	get_tree().on_request_permissions_result.connect(permission_result)

func is_android() -> bool: return OS.has_feature("android")
func granted(permission: String) -> bool:
	return not is_android() or OS.get_granted_permissions().has(permission)
func request_system(permission: String) -> bool: return OS.request_permission(permission)

func tracking_permissions() -> Array:
	if OS.has_feature("quest_xr"): return QUEST_TRACKING
	if OS.has_feature("pico_xr"): return PICO_TRACKING
	return []

func request(permission: String, retry: bool=false) -> void:
	if granted(permission):
		permission_result(permission,true)
		return
	if current==permission or pending.has(permission): return
	if attempted.has(permission) and not retry:
		completed.emit(permission,bool(results.get(permission,false)))
		return
	pending.append(permission)
	_next.call_deferred()

func request_tracking(retry: bool=false) -> void:
	if not is_android(): return
	for permission in tracking_permissions(): request(permission,retry)

func _next() -> void:
	if not current.is_empty() or pending.is_empty(): return
	current=pending.pop_front()
	attempted[current]=true
	if granted(current) or request_system(current): permission_result(current,true)

func permission_result(permission: String, allowed: bool) -> void:
	results[permission]=allowed
	if current==permission:
		current=""
		_next.call_deferred()
	completed.emit(permission,allowed)

func tracking_status() -> String:
	var denied: Array[String]=[]
	for permission in tracking_permissions():
		if results.has(permission) and not results[permission]: denied.append(permission.get_slice(".",3).replace("_"," ").to_lower())
	if not denied.is_empty(): return "Tracking access denied: "+", ".join(denied)+". Use headset app permissions or RETRY ACCESS."
	if not current.is_empty(): return "Waiting for headset permission approval"
	return ""
