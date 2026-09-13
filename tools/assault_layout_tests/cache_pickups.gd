extends SceneTree
## Update point entities in existing platform bakes; preserve geometry and textures.
const Entity=preload("res://deathmatch/maps/entity.gd")
func _initialize():run.call_deferred()
func run() -> void:
	var report: Array=[]
	for id in ["as_hislop","as_frigate","as_hislop_tiny","as_frigate_tiny"]:
		var source: String="res://maps/"+id+".bsp"
		var file:=FileAccess.open(source,FileAccess.READ);file.seek(4)
		var offset:=file.get_32();var length:=file.get_32();file.seek(offset)
		var reader:=preload("res://addons/bsp_importer/bsp_reader.gd").new()
		var entities: Array=reader.parse_entity_string(file.get_buffer(length).get_string_from_ascii()).filter(func(e):return pickup(e))
		reader.free()
		for suffix in ["","-lightmap1","-lightmap1-bc7","-lightmap1-astc4"]:
			var path: String="res://maps/cache/"+id+suffix+".scn"
			if not FileAccess.file_exists(path):continue
			var packed:=load(path) as PackedScene
			var level:=packed.instantiate()
			var pending: Array=[level]
			while not pending.is_empty():
				var node: Node=pending.pop_back()
				if node.get_script()==Entity and pickup(node.attributes):node.free()
				else:pending.append_array(node.get_children())
			for e in entities:
				var node:=Node3D.new();node.set_script(Entity);node.attributes=e.duplicate(true)
				var xyz:=str(e.origin).split_floats(" ",false)
				node.position=Vector3(-xyz[1],xyz[2],-xyz[0])/32.0
				node.name="Pickup"+str(level.get_child_count());level.add_child(node);node.owner=level
			level.set_meta("bsp_source_sha256",FileAccess.get_sha256(source))
			var updated:=PackedScene.new();assert(updated.pack(level)==OK)
			assert(ResourceSaver.save(updated,path)==OK)
			report.append({"path":path,"pickups":entities.size()});level.free()
			await process_frame
	print("AS_PICKUP_CACHE_RESULT ",JSON.stringify(report));quit()
func pickup(e: Dictionary) -> bool:
	var name: String=e.get("classname","")
	return e.has("fpsloppa_roof_guard") or (name.begins_with("weapon_") or name.begins_with("item_")) and not name.begins_with("item_flag")
