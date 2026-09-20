extends "res://deathmatch/tests/network_runner.gd"
const Protocol=preload("res://deathmatch/server/discovery_protocol.gd")
const Config=preload("res://deathmatch/server/config.gd")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var master: String=args[args.find("--browser-master")+1]
	var control: String=args[args.find("--browser-control")+1]
	root.size=Vector2i(854,640);root.content_scale_size=root.size
	check(not Config.parse("").has("error") and Config.parse("").values.sv_query_port==0,"Old configs leave discovery disabled")
	var local_master:=Config.parse("set sv_master_test 1")
	check(not local_master.has("error") and local_master.values.sv_public==1 and local_master.values.sv_query_port==7779 and local_master.values.sv_master_url=="http://127.0.0.1:8080","Dedicated test-master option enables local registration and queries")
	check(Config.parse("set sv_master_test 1\nset sv_master_url https://example.com").has("error"),"Local test master cannot silently replace an external master")
	for bad in ["set sv_public 1", "set sv_query_port 7777", "set sv_query_port 10", "set sv_master_url http://example.com", "set sv_master_url https://user:secret@example.com"]:
		check(Config.parse(bad).has("error"),"Reject invalid discovery config: "+bad)
	check(Protocol.valid_url("https://master.example/list") and Protocol.valid_url(master),"HTTPS and numeric loopback development endpoints are accepted")
	check(Protocol.decode("not JSON".to_utf8_buffer()).is_empty() and Protocol.decode("x".repeat(1201).to_utf8_buffer()).is_empty(),"Malformed and oversized query packets are ignored")
	check(Protocol.public_text("界".repeat(80)).to_utf8_buffer().size()<=80 and Protocol.public_text("a\nb")=="a b","Public status text stays bounded with Unicode and removes control characters")
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if not game.hud:
		game.hud=preload("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	var browser=game.hud.server_browser
	browser.master.text=master;browser.open()
	check(await wait_for(func():return browser.directory.rows.values().any(func(row):return row.get("online",false)),15),"Master listing and live UDP challenge/status discovery succeed")
	if browser.directory.rows.is_empty():
		print("BROWSER_RESULT ",JSON.stringify(failures));game.queue_free();await process_frame;quit(1);return
	var key: String=browser.directory.rows.keys()[0]
	var original: Dictionary=browser.directory.rows[key].duplicate()
	browser.selected=key;browser.render();await process_frame;await process_frame
	check(original.get("humans")==0 and original.get("bots")==2 and original.get("open_slots")==2,"Bot-filled dedicated server advertises free human seats")
	check(not browser.join_button.disabled and not browser.spectate_button.disabled,"Join and Spectate are available for a bot-filled server")
	check(browser.size.x<=854 and browser.size.y<=640,"Browser fits the 854×640 VR canvas")
	check(browser.list.get_parent().size.y>=100 and browser.message.get_global_rect().end.y<600,"Server list retains usable space and footer stays inside canvas")
	browser.directory.toggle_favorite(key)
	var saved=preload("res://deathmatch/ui/server_directory.gd").new();root.add_child(saved)
	check(saved.favorites.has(key) and saved.master_url==master,"Favorite endpoint and master URL survive reloading preferences")
	saved.queue_free()
	browser.directory.rows[key].protocol="incompatible"
	browser.render();check(browser.visible_rows().is_empty(),"Compatible filter hides mismatched protocol")
	browser.compatible.button_pressed=false;browser.selected=key;browser.render()
	check(browser.join_button.disabled and browser.details.text.contains("Version mismatch"),"Mismatched servers cannot be joined")
	browser.directory.rows[key]=original.duplicate();browser.selected=key
	browser.directory.rows[key].open_slots=0;browser.render()
	check(browser.join_button.disabled and browser.spectate_button.disabled,"Live full-server status disables both admission actions")
	browser.directory.rows[key]=original.duplicate();browser.selected=key;browser.render()
	browser.mode.choose("ctf");check(browser.visible_rows().is_empty(),"Mode filter hides unrelated modes");browser.mode.choose("all")
	browser.search.text="NoSuchArena";browser.render();check(browser.visible_rows().is_empty(),"Search filters server rows");browser.search.text=""
	browser.selected=key;browser.render()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(control+"-browser.png")
	browser.join_selected(true)
	check(await wait_for(func():return game.active and game.local_state().get("spectator",false),20),"Browser Spectate completes the normal ENet/map handshake")
	check(not browser.visible and browser.directory.probes.is_empty(),"Joining closes browser and cancels discovery work")
	game.disconnect_game("Browser test reconnect")
	# Python stops the master here; favorites and gameplay must continue working.
	FileAccess.open(control+"-stop-master",FileAccess.WRITE).store_string("stop")
	check(await wait_for(func():return FileAccess.file_exists(control+"-master-stopped"),10),"Master outage fixture ready")
	browser.directory.next_refresh=0;browser.open()
	check(await wait_for(func():return not browser.directory.fetching and browser.message.text.contains("unavailable"),10),"Master outage is reported without blocking the browser")
	check(await wait_for(func():return browser.directory.rows.get(key,{}).get("online",false),8),"Favorites still query directly during master outage")
	browser.selected=key;browser.render();browser.join_selected(false)
	check(await wait_for(func():return game.active and not game.local_state().get("spectator",true),20),"Browser Join works while the master is offline")
	game.disconnect_game("Browser integration complete")
	print("BROWSER_RESULT ",JSON.stringify(failures))
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
