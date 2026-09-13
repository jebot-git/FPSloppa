extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/titanball/markers-r3.json"))
	for suffix in ["","-bc7","-astc4"]:
		var path: String="res://maps/cache/tb_ashfall-lightmap1"+suffix+".scn"
		var packed: PackedScene=load(path);assert(packed!=null)
		var node=packed.instantiate()
		for old in node.find_children("*","Node3D",true,false):
			if "attributes" in old and old.attributes.get("classname","") in ["info_tb_resupply","info_tb_vantage"]:old.free()
		for i in data.markers.size():
			var fields: Dictionary={}
			for key in data.markers[i]:fields[key]=str(data.markers[i][key])
			var marker=load("res://deathmatch/maps/point.tscn").instantiate();marker.name="TBTacticalMarker"+str(i);marker.attributes=fields
			var values: PackedStringArray=fields.origin.split(" ",false)
			marker.position=Vector3(-float(values[1]),float(values[2]),-float(values[0]))/32.
			node.add_child(marker);marker.owner=node
		node.set_meta("bsp_source_sha256",data.sha256)
		var updated:=PackedScene.new();assert(updated.pack(node)==OK);assert(ResourceSaver.save(updated,path)==OK);node.free()
		print("TB_CACHE_MARKERS_UPDATED ",path)
	quit()
