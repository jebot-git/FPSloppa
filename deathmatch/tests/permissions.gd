extends SceneTree
const Permissions=preload("res://deathmatch/vr/permissions.gd")
class FakePermissions extends Permissions:
	var allowed: Array[String]=[]
	var requested: Array[String]=[]
	func is_android() -> bool: return true
	func granted(permission: String) -> bool: return allowed.has(permission)
	func request_system(permission: String) -> bool:
		requested.append(permission)
		return false
	func tracking_permissions() -> Array: return QUEST_TRACKING
	func answer(permission: String,value: bool) -> void:
		if value: allowed.append(permission)
		permission_result(permission,value)
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var access:=FakePermissions.new();root.add_child(access)
	access.request(Permissions.MICROPHONE)
	access.request_tracking()
	await process_frame
	check(access.requested==[Permissions.MICROPHONE],"Microphone and tracking dialogs serialize")
	access.answer(Permissions.MICROPHONE,false)
	await process_frame
	check(access.current==Permissions.QUEST_TRACKING[0],"Microphone denial continues tracking requests")
	for permission in Permissions.QUEST_TRACKING:
		access.answer(permission,true)
		await process_frame
	check(access.pending.is_empty() and access.current.is_empty(),"All tracking permissions complete")
	var count:=access.requested.size()
	access.request(Permissions.MICROPHONE)
	await process_frame
	check(access.requested.size()==count,"Denied permissions do not cause repeated automatic prompts")
	access.request(Permissions.MICROPHONE,true)
	await process_frame
	check(access.requested.size()==count+1,"Explicit retry requests denied microphone again")
	access.answer(Permissions.MICROPHONE,true)
	access.request_tracking()
	await process_frame
	check(access.requested.size()==count+1,"Granted tracking permissions skip dialogs")
	var tracking_permission: String=Permissions.QUEST_TRACKING[0]
	access.allowed.erase(tracking_permission)
	access.permission_result(tracking_permission,false)
	check(access.tracking_status().contains("denied"),"Tracking denial is visible in menu status")
	access.allowed.append(tracking_permission)
	access.request(tracking_permission)
	check(access.tracking_status().is_empty(),"Granting access in system settings clears stale denial")
	access.free()
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.voice.set_process(false)
	game.permissions.free()
	access=FakePermissions.new();game.add_child(access);game.permissions=access
	access.completed.connect(game.voice._permission_result)
	# Dispatch Android permission callbacks without opening a real microphone.
	game.headless=false
	game.voice.set_mode(1)
	await process_frame
	access.answer(Permissions.MICROPHONE,false)
	check(game.voice.mode==1 and game.voice.mic==null and game.voice.message.contains("denied"),"Permission denial preserves PTT and supports listening")
	game.voice.retry_access()
	await process_frame
	game.voice.set_mode(0)
	access.answer(Permissions.MICROPHONE,true)
	check(game.voice.mic==null and not game.voice.permission_wait,"Late grant cannot enable a disabled microphone")
	game.headless=true
	game.voice.set_mode(2)
	game.voice.policy(false,"Host")
	access.answer(Permissions.MICROPHONE,true)
	check(game.voice.mode==2 and game.voice.mic==null,"Host policy stops capture without discarding selected mode")
	game.voice.policy(true,"Host")
	game.voice.reset()
	check(game.voice.mode==2 and game.voice.mic==null,"Reconnect preserves mode and headless server never captures")
	game.free()
	print("PERMISSIONS_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
