extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failures: Array=[]
	for manifest in ["res://deathmatch/maps/manifest.json","res://deathmatch/avatars/models/manifest.json"]:
		var rows=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if not rows is Array: failures.append(manifest); continue
		for row in rows:
			var expected: String=row.get("sha256",row.get("hash",""))
			if FileAccess.get_sha256(row.path)!=expected: failures.append(row.path)
			if row.has("scene"):
				var map=load(row.scene).instantiate()
				root.add_child(map)
				map.queue_free()
	var library=load("res://deathmatch/avatars/library.gd").new()
	root.add_child(library)
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	if rows is Array:
		for row in rows:
			var avatar=library.create_avatar(row.hash)
			if not avatar: failures.append("avatar decode "+row.path)
			else:
				root.add_child(avatar)
				await process_frame
				var springs:=0
				for node in avatar.find_children("*","Node",true,false):
					if node.get_script() and node.get_script().resource_path.ends_with("vrm_secondary.gd"):
						springs+=node.spring_bones_internal.size()
				if springs==0: failures.append("spring bones not initialized "+row.path)
				avatar.queue_free()
				await process_frame
	for id in range(9):
		var weapon=load("res://deathmatch/art.gd").weapon(id)
		if not weapon: failures.append("weapon "+str(id))
		else: weapon.free()
	await process_frame
	print("EXPORT_RESOURCES_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
