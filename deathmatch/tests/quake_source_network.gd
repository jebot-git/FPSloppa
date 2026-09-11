extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
 var args:=OS.get_cmdline_user_args();role=args[0];var path: String=args[1];var key:=path.get_file().get_basename()
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);await process_frame
 if role=="server":
  game.dedicated=true
  var hash:=FileAccess.get_sha256(path)
  game.map_catalog.append({"id":key,"title":key,"path":path,"scene":"user://"+hash+"-network.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()})
  game.selected_map=key;game.start_host("Quake source test",27877,20,10,false)
  check(await wait_for(func():return game.players.size()==2,75),"Two clients download and join compiled map")
  if game.players.size()==2:
   check(game.spawn_points.size()>=2,"Multiplayer spawns available")
   for id in game.players:check(game.players[id].owned==[2],"Joining player starts with pistol only")
   await pause(3)
   check(game.fighters.values().all(func(a):return a.position.is_finite()),"Network player movement stays finite")
  game._announcement.rpc("TEST_DONE");await pause(1)
 else:
  game.start_join(role,"127.0.0.1",27877)
  check(await wait_for(func():return game.active,75),"Map download and handshake complete")
  check(game.current_map==key or game.current_map=="custom_"+game.map_sha,"Host map active on client")
  check(game.map_sha==FileAccess.get_sha256(path),"Downloaded BSP hash matches host")
  check(await wait_for(func():return game.feed.any(func(e):return e.text=="TEST_DONE"),15),"Snapshots and reliable announcements arrive")
 print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
 game.disconnect_game("Test completed");await pause(.1);quit(0 if failures.is_empty() else 1)
