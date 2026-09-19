extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const OUT="res://test-results/import-light-bake/"

func _initialize():run.call_deferred()

func run() -> void:
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"bake.json"))
	var results: Array=[]
	var failures: Array=[]
	for row in input.maps:
		for variant in ["original","native","rebaked"]:
			var path: String=OUT+row.name+"-"+variant+".bsp"
			var start:=Time.get_ticks_usec()
			var level:=Loader.read(path)
			if not level:
				failures.append(path+": import failed")
				continue
			var result: Dictionary={"map":row.name,"variant":variant,"seconds":(Time.get_ticks_usec()-start)/1000000.0}
			for field in ["faces","invalid_faces","overflow_faces","unlit_faces","rgb"]:
				result[field]=level.get_meta("baked_light_"+field,0)
			if variant!="original" and (result.faces<=0 or result.invalid_faces!=0 or result.overflow_faces!=0):
				failures.append(path+": invalid or missing atlas")
			results.append(result)
			print("IMPORT_BAKE_PROBE ",JSON.stringify(result))
			level.free()
			await process_frame
	FileAccess.open(OUT+"import.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":results,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
