extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
func _initialize():run.call_deferred()
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var armory:=Rules.new();var samples: Array=[]
	for pass_index in 3:
		for rules in Rules.IDS:
			armory.select(rules)
			for slot in armory.table.size():
				var before:=Time.get_ticks_usec()
				var model:=Art.weapon(slot,2,rules)
				var built:=Time.get_ticks_usec()
				root.add_child(model)
				var added:=Time.get_ticks_usec()
				# Let the factory's deferred material warmup complete before retirement.
				for frame in 6:await process_frame
				var retirement:=Time.get_ticks_usec();model.free()
				samples.append({"pass":pass_index,"rules":rules,"slot":slot,"name":armory.data(slot).name,"construct_ms":(built-before)/1000.0,"add_ms":(added-built)/1000.0,"free_ms":(Time.get_ticks_usec()-retirement)/1000.0})
				await process_frame
	var stages: Array=[]
	for pair in [["quake",4],["quake",6],["ut99",5],["ut99",6]]:
		for trial in 3:
			var before:=Time.get_ticks_usec()
			var model_root:=Node3D.new()
			var asset: String=Art.WEAPON_ASSETS[Art.model_id(pair[1],pair[0])]
			var model: Node3D=Art.weapon_scenes[asset].instantiate();model_root.add_child(model)
			var instantiated:=Time.get_ticks_usec()
			Art.variant_details(model_root,model,pair[1],pair[0])
			var detailed:=Time.get_ticks_usec()
			preload("res://deathmatch/maps/filtering.gd").new().apply(model_root,2)
			var filtered:=Time.get_ticks_usec()
			stages.append({"rules":pair[0],"slot":pair[1],"trial":trial,"instantiate_ms":(instantiated-before)/1000.0,"variant_details_ms":(detailed-instantiated)/1000.0,"filter_ms":(filtered-detailed)/1000.0})
			root.add_child(model_root)
			for frame in 6:await process_frame
			model_root.free()
	var report:={"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"samples":samples,"variant_stages":stages,"scope":"Weapon factory CPU time with native renderer, first factory use then two warm passes; each model lives six process frames so deferred warmup completes. Does not measure first-visible-frame GPU pipeline compilation, avatar attachment, gameplay or XR."}
	DirAccess.make_dir_recursive_absolute("res://test-results/frametime-study")
	FileAccess.open("res://test-results/frametime-study/weapons.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WEAPON_CONSTRUCTION_PROFILE_DONE");quit()
