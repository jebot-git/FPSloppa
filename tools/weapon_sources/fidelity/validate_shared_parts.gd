extends SceneTree
const OUT="res://test-results/weapon-shared-reduction/"
func _initialize():run.call_deferred()
func run():
	var checked:=0;var altered:=0
	for row in JSON.parse_string(FileAccess.get_file_as_string(OUT+"runtime-counts.json")):
		var before=load(OUT+row.key+"-before.scn").instantiate()
		var after=load("res://deathmatch/weapons/fidelity/"+row.key+".scn").instantiate()
		var budgets:={}
		for part in row.parts:budgets[part.name]=part.budget
		var nodes=before.find_children("*","",true,false);nodes.push_front(before)
		for original in nodes:
			var changed=after.get_node(before.get_path_to(original))
			assert(changed.get_class()==original.get_class())
			if original is Node3D:assert(changed.transform.is_equal_approx(original.transform))
			for meta in original.get_meta_list():assert(var_to_bytes(changed.get_meta(meta))==var_to_bytes(original.get_meta(meta)))
			if not original is MeshInstance3D:continue
			assert(changed.mesh.get_surface_count()==original.mesh.get_surface_count())
			var count:=0
			for i in original.mesh.get_surface_count():
				var om=original.mesh.surface_get_material(i);var nm=changed.mesh.surface_get_material(i)
				for prop in om.get_property_list():
					if not prop.usage & PROPERTY_USAGE_STORAGE or prop.name in ["resource_path","resource_scene_unique_id"]:continue
					var a=om.get(prop.name);var b=nm.get(prop.name)
					assert(a.resource_path==b.resource_path if a is Resource and b is Resource else var_to_bytes(a)==var_to_bytes(b),str(prop.name))
				if not budgets.has(str(original.name)):
					assert(var_to_bytes(original.mesh.surface_get_arrays(i))==var_to_bytes(changed.mesh.surface_get_arrays(i)),str(original.name))
				count+=changed.mesh.surface_get_array_index_len(i)/3
			if budgets.has(str(original.name)):
				assert(count<=budgets[str(original.name)]+2);altered+=1
			if str(original.name)=="SculptedShoulderStock":assert(count<=1000)
			checked+=1
		before.free();after.free()
	var report={"passed":true,"mesh_parts_checked":checked,"reduced_parts":altered,"unchanged_part_arrays_materials_transforms_and_metadata_preserved":true}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHARED_PARTS_VALIDATION ",JSON.stringify(report));quit()
