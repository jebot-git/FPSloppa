extends SceneTree
var game
var failures: Array = []
var role := ""
var hash := ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func wait_for(condition: Callable, seconds: float = 45) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	hash = args[2]
	game = load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("ISOLATED_CACHE ",OS.get_user_data_dir())
	if role=="server":
		game.dedicated=true
		game.start_host("Server",27878,20,10,false)
		check(await wait_for(func(): return game.players.size()==2),"two clients joined")
		if game.players.size()==2:
			var id: int = game.players.keys()[0]
			game.avatars.accept_offer(id,"a".repeat(64),25_000_001)
			check(not game.avatars.expected.has("a".repeat(64)),"server rejects oversized advertisement")
		check(await wait_for(func(): return game.avatars.library.entries.has(hash)),"server validated client upload")
		check(await wait_for(func(): return game.feed.any(func(row): return "ASSET_OK" in row.text)),"second client verified download")
		check(await wait_for(func(): return game.feed.any(func(row): return "REJOIN_OK" in row.text)),"late join cache and avatar selection")
		game._announcement.rpc("AVATAR_DONE")
		await create_timer(1).timeout
	else:
		if role=="uploader":
			var imported: String = game.avatars.library.register_file(args[1])
			check(imported==hash,"custom VRM imported locally")
			game.avatars.library.selected=hash
		else: check(not game.avatars.library.entries.has(hash),"receiver starts without custom asset")
		game.start_join(role,"127.0.0.1",27878)
		check(await wait_for(func(): return game.active),"joined")
		if role=="receiver":
			check(await wait_for(func(): return game.avatars.library.entries.has(hash)),"server asset download completed")
			if game.avatars.library.entries.has(hash):
				check(FileAccess.get_sha256(game.avatars.library.entries[hash].path)==hash,"download SHA256 matches uploader")
				var avatar = game.avatars.library.create_avatar(hash)
				check(avatar!=null,"downloaded VRM is renderable and rigged")
				if avatar: avatar.free()
			game.chat_send("ASSET_OK")
			await create_timer(1).timeout
			game.disconnect_game("Avatar rejoin test")
			await create_timer(.5).timeout
			game.start_join(role,"127.0.0.1",27878)
			check(await wait_for(func(): return game.active and game.avatars.choices.values().any(func(row): return row.hash==hash)),"late join receives custom model identity")
			check(game.avatars.incoming.is_empty(),"cached avatar avoids repeat transfer")
			game.chat_send("REJOIN_OK")
		check(await wait_for(func(): return game.feed.any(func(row): return "AVATAR_DONE" in row.text)),"network scenario complete")
	print("AVATAR_NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
	game.disconnect_game("Test complete")
	await create_timer(.1).timeout
	quit(0 if failures.is_empty() else 1)
