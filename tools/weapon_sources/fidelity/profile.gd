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
	var report={"samples":samples,"scope":"Native renderer weapon factory CPU time; cold and two warm passes. Not an XR frame-time measurement."}
	FileAccess.open("res://test-results/weapon-fidelity/construction.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FIDELITY_CONSTRUCTION_COMPLETE");quit()
