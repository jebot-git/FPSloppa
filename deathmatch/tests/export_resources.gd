extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failures: Array=[]
	for manifest in ["res://deathmatch/maps/manifest.json","res://deathmatch/avatars/models/manifest.json"]:
		var rows=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if not rows is Array: failures.append(manifest); continue
		for row in rows:
			if row.get("distribution","base")!="base":continue
			var expected: String=row.get("sha256",row.get("hash",""))
			if FileAccess.get_sha256(row.path)!=expected: failures.append(row.path)
			if row.has("scene"):
				var map=load(row.scene).instantiate()
				root.add_child(map)
				map.queue_free()
	var library=load("res://deathmatch/avatars/library.gd").new()
	root.add_child(library)
	var world:=Node3D.new()
	root.add_child(world)
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	if rows is Array:
		for row in rows:
			var avatar=library.create_avatar(row.hash)
			if not avatar: failures.append("avatar decode "+row.path)
			else:
				world.add_child(avatar)
				await process_frame
				var springs:=0
				for node in avatar.find_children("*","Node",true,false):
					if node.get_script() and node.get_script().resource_path.ends_with("vrm_secondary.gd"):
						springs+=node.spring_chain_count()
				# Bald/base avatars legitimately contain no spring chains.
				var file:=FileAccess.open(row.path,FileAccess.READ);file.seek(12)
				var length:=file.get_32();file.get_32()
				var gltf: Dictionary=JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
				var extensions: Dictionary=gltf.get("extensions",{})
				var declared: Array=extensions.get("VRM",{}).get("secondaryAnimation",{}).get("boneGroups",[])
				declared+=extensions.get("VRMC_springBone",{}).get("springs",[])
				if not declared.is_empty() and springs==0: failures.append("spring bones not initialized "+row.path)
				avatar.queue_free()
				await process_frame
	for id in range(preload("res://deathmatch/weapons.gd").DATA.size()):
		var weapon=load("res://deathmatch/art.gd").weapon(id)
		if not weapon: failures.append("weapon "+str(id))
		else: weapon.free()
	for id in 12:
		var weapon=load("res://deathmatch/art.gd").weapon(id,2,"cs16")
		if not weapon:failures.append("cs16 weapon "+str(id))
		else:weapon.free()
	await process_frame
	print("EXPORT_RESOURCES_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
