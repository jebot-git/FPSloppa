extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var library=preload("res://deathmatch/avatars/library.gd").new()
	for sample in ["sample_d","sample_f","sample_g"]:
		library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		var actor:=Node3D.new();root.add_child(actor)
		var rig=preload("res://deathmatch/avatars/visual_loader.gd").create_avatar(library,sample);actor.add_child(rig)
		var bones:=0;var chains:=0;var colliders:=0;var pairs:=0
		for secondary in rig.secondary_nodes:
			chains+=secondary.spring_bones_internal.size();colliders+=secondary.colliders_internal.size()
			for spring in secondary.spring_bones_internal:bones+=spring.verlets.size();pairs+=spring.verlets.size()*spring.colliders.size()
		print("SECONDARY_COST ",JSON.stringify({"sample":sample,"bones":bones,"chains":chains,"colliders":colliders,"pairs":pairs}))
		actor.free()
	library.free();quit()
