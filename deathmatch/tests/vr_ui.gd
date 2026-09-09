extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(g)
	g.hud=load("res://deathmatch/interface.gd").new()
	g.add_child(g.hud)
	g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new()
	g.add_child(g.xr_rig)
	print("VR_SETUP_START")
	print("VR_SETUP_DONE ",g.xr_rig.setup(g,true))
	await process_frame
	await process_frame
	print("VR_UI_RESULT ",g.hud.get_parent() is SubViewport," ",g.xr_rig.pointers.size())
	quit()
