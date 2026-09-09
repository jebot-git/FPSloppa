extends SceneTree
# Idempotently update our curated map; regenerating Godot defaults loses custom
# eye/tracker actions and can reintroduce unsupported SteamVR revision-3 roles.
func _initialize() -> void:
	var map: OpenXRActionMap=load("res://deathmatch/vr/actions.tres")
	var set: OpenXRActionSet=map.get_action_set(0)
	var actions: Dictionary={}
	for action in set.actions: actions[action.resource_name]=action
	for name in ["tracker_pose","thumbrest_touch"]:
		if not actions.has(name):
			var action:=OpenXRAction.new()
			action.resource_name=name;action.localized_name=name.capitalize()
			action.action_type=OpenXRAction.OPENXR_ACTION_POSE if name=="tracker_pose" else OpenXRAction.OPENXR_ACTION_BOOL
			set.add_action(action);actions[name]=action
	var hands:=PackedStringArray(["/user/hand/left","/user/hand/right"])
	for name in ["default_pose","haptic","thumbrest_touch"]: actions[name].toplevel_paths=hands
	var roles:=PackedStringArray()
	for role in preload("res://deathmatch/vr/tracking.gd").VIVE.values(): roles.append("/user/vive_tracker_htcx/role/"+role)
	actions.tracker_pose.toplevel_paths=roles
	var vive:=map.find_interaction_profile("/interaction_profiles/htc/vive_tracker_htcx")
	for binding in vive.bindings: binding.action=actions.tracker_pose
	var profiles={
		"/interaction_profiles/valve/index_controller":{"ax_touch":"input/a/touch","by_touch":"input/b/touch","primary_touch":"input/thumbstick/touch","secondary_touch":"input/trackpad/touch"},
		"/interaction_profiles/oculus/touch_controller":{"thumbrest_touch":"input/thumbrest/touch"}}
	for path in profiles:
		var profile:=map.find_interaction_profile(path)
		for side in ["left","right"]:
			for name in profiles[path]:
				var input_path: String="/user/hand/"+side+"/"+profiles[path][name]
				if profile.bindings.any(func(b):return b.binding_path==input_path and b.action==actions[name]): continue
				var binding:=OpenXRIPBinding.new()
				binding.action=actions[name];binding.binding_path=input_path
				profile.bindings.append(binding)
	var err:=ResourceSaver.save(map,"res://deathmatch/vr/actions.tres")
	print("XR_ACTION_MAP ",err)
	quit(0 if err==OK else 1)
