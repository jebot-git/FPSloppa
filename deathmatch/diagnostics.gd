extends RefCounted
# Runs inside an exported executable, without relying on editor-only --script.
static func check_assets(game: Node) -> int:
	var failures: Array=[]
	for manifest in ["res://deathmatch/maps/manifest.json","res://deathmatch/avatars/models/manifest.json"]:
		var rows=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if not rows is Array: failures.append(manifest); continue
		for row in rows:
			if FileAccess.get_sha256(row.path)!=row.get("sha256",row.get("hash","")): failures.append("raw bytes "+row.path)
	var library=load("res://deathmatch/avatars/library.gd").new()
	game.add_child(library)
	var avatars=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	if avatars is Array:
		for row in avatars:
			var avatar=library.create_avatar(row.hash)
			if not avatar: failures.append("decode "+row.path); continue
			game.add_child(avatar)
			await game.get_tree().process_frame
			var count:=0
			for node in avatar.find_children("*","Node",true,false):
				if node.get_script() and node.get_script().resource_path.ends_with("vrm_secondary.gd"):
					count+=node.spring_bones_internal.size()
			print("ASSET_AVATAR ",row.title," spring_chains=",count)
			if count==0: failures.append("spring animation "+row.path)
			avatar.queue_free()
			await game.get_tree().process_frame
	print("ASSET_CHECK_RESULT ",failures)
	return 0 if failures.is_empty() else 1
