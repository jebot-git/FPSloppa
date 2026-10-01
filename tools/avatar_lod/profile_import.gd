extends SceneTree
func _initialize():run.call_deferred()
func run():
	var library=preload("res://deathmatch/avatars/library.gd").new()
	var report:=[]
	for sample in ["sample_d","sample_f","sample_g","sakurada_fumiriya"]:
		library.scenes.clear();library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		var row:={"sample":sample,"times":[]}
		for repeat in 2:
			var started:=Time.get_ticks_usec()
			var rig=library.create_avatar(sample)
			var loaded:=Time.get_ticks_usec();assert(rig)
			var actor:=Node3D.new();root.add_child(actor);actor.add_child(rig);rig.preview_mode=0
			var ready:=Time.get_ticks_usec()
			row.times.append({"load_ms":(loaded-started)/1000.0,"ready_ms":(ready-loaded)/1000.0})
			if repeat==0:
				var vertices:=0;var tris:=0;var surfaces:=0;var morph_bytes:=0;var native_joints:=0;var pairs:=0
				for mesh in rig.visual_meshes:
					if not mesh.visible:continue
					for i in mesh.mesh.get_surface_count():
						vertices+=mesh.mesh.surface_get_array_len(i);tris+=mesh.mesh.surface_get_array_index_len(i)/3;surfaces+=1
						for arrays in mesh.mesh.surface_get_blend_shape_arrays(i):morph_bytes+=var_to_bytes(arrays).size()
				for secondary in rig.secondary_nodes:
					for i in secondary.native_simulator.setting_count:
						var joints: int=secondary.native_simulator.get_joint_count(i);native_joints+=joints;pairs+=joints*secondary.native_simulator.get_collision_count(i)
				row.merge({"bones":rig.skeleton.get_bone_count(),"remote_vertices":vertices,"remote_triangles":tris,"remote_surfaces":surfaces,"remote_morph_bytes":morph_bytes,"spring_joints":native_joints,"potential_collision_pairs":pairs})
			actor.free()
		print("VRM_IMPORT_PROFILE ",JSON.stringify(row));report.append(row)
	FileAccess.open("res://test-results/vrm-optimization/import-"+("baseline" if OS.get_cmdline_user_args().has("--unmerged-avatar-surfaces") else "compiled")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	library.free();quit()
