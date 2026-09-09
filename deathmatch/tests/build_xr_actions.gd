extends SceneTree
func _initialize() -> void:
	var map:=OpenXRActionMap.new()
	map.create_default_action_sets()
	var profile:=OpenXRInteractionProfile.new()
	profile.interaction_profile_path="/interaction_profiles/valve/index_controller"
	var actions: Dictionary={}
	for action in map.get_action_set(0).actions: actions[action.resource_name]=action
	var paths={"default_pose":"input/aim/pose","aim_pose":"input/aim/pose","grip_pose":"input/grip/pose","trigger":"input/trigger/value","trigger_click":"input/trigger/click","trigger_touch":"input/trigger/touch","grip":"input/squeeze/value","grip_force":"input/squeeze/force","primary":"input/thumbstick","primary_click":"input/thumbstick/click","ax_button":"input/a/click","by_button":"input/b/click","haptic":"output/haptic"}
	for hand in ["left","right"]:
		for name in paths:
			var binding:=OpenXRIPBinding.new()
			binding.action=actions[name]
			binding.binding_path="/user/hand/"+hand+"/"+paths[name]
			profile.bindings.append(binding)
	map.add_interaction_profile(profile)
	print("XR_ACTION_MAP ",ResourceSaver.save(map,"res://deathmatch/vr/actions.tres"))
	for entry in map.interaction_profiles: print(entry.interaction_profile_path)
	quit()
