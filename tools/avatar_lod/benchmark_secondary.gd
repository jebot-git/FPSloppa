extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var library=preload("res://deathmatch/avatars/library.gd").new()
	var report: Array=[]
	for sample in ["sample_d","sample_f","sample_g"]:
		library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		for mode in ["legacy","bounds","simplified","buffer"]:
			var actor:=Node3D.new();root.add_child(actor)
			var rig=preload("res://deathmatch/avatars/visual_loader.gd").create_avatar(library,sample);actor.add_child(rig)
			rig.set_process(false);rig.solver.active=false;rig.eyes.active=false;rig.motion.pause()
			for secondary in rig.secondary_nodes:secondary.internal_modifier_node.active=false;secondary.optimize_collisions=mode in ["bounds","simplified"];secondary.simplify_animation=mode=="simplified";secondary.buffered_animation=mode=="buffer"
			var samples: Array=[]
			for frame in 200:
				for bone in rig.skeleton.get_bone_count():rig.skeleton.reset_bone_pose(bone)
				var start:=Time.get_ticks_usec()
				for secondary in rig.secondary_nodes:secondary.do_process(1.0/60)
				if frame>=40:samples.append(Time.get_ticks_usec()-start)
			var sum:=0.0
			for elapsed in samples:sum+=elapsed
			samples.sort()
			var row:={"sample":sample,"mode":mode,"mean_us":sum/samples.size(),"p95_us":samples[ceili(samples.size()*.95)-1]}
			report.append(row);print("SECONDARY_BENCHMARK ",JSON.stringify(row));actor.free()
	FileAccess.open("/tmp/animation-secondary-micro.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	library.free();quit()
