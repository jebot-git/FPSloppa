extends "res://deathmatch/bot_ai/navigation.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func path(start: Vector3,goal: Vector3,allow_jump: bool=true) -> PackedVector3Array:
	var scope_started:=Trace.begin()
	var result=super.path(start,goal,allow_jump)
	Trace.end("nav_path_queries",scope_started)
	return result
func ray(a: Vector3,b: Vector3) -> Dictionary:
	var scope_started:=Trace.begin()
	var result=super.ray(a,b)
	Trace.end("nav_rays",scope_started)
	return result
func active_link(position: Vector3,destination: Vector3) -> Dictionary:
	var scope_started:=Trace.begin()
	var result=super.active_link(position,destination)
	Trace.end("nav_active_links",scope_started)
	return result
func update_jump_links() -> void:
	var scope_started:=Trace.begin()
	super.update_jump_links()
	Trace.end("nav_jump_link_updates",scope_started)
