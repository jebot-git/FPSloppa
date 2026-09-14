extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
 role=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);await process_frame
 if role=="server":
  game.dedicated=true;game.selected_map="qsrc_dm2";game.start_host("Mover test",27879,20,10,false)
  check(await wait_for(func():return game.players.size()==2,30),"Two clients join DM2")
  var logic=game.get_node("Map/MapRuntime").triggers
  for node in logic.rows:
   var row: Dictionary=logic.rows[node]
   if row.kind=="func_button" and row.data.get("target","") in ["t18","t11"]:
    if row.hp>0:logic.damage(node,0,1)
    else:logic.activate(node,0)
  await pause(1.0)
  game._announcement.rpc("CHECK_MOVERS")
  await pause(2)
  game._announcement.rpc("TEST_DONE");await pause(1)
 else:
  game.start_join(role,"127.0.0.1",27879)
  check(await wait_for(func():return game.active,30),"Client joins restored DM2")
  check(await wait_for(func():return game.feed.any(func(e):return e.text=="CHECK_MOVERS"),15),"Activation reaches client")
  var logic=game.get_node("Map/MapRuntime").triggers
  for name in ["t18","t11"]:
   for node in logic.targets[name]:
    var gate: Dictionary=game.gates[logic.rows[node].gate]
    check(gate.open and node.position.distance_to(gate.base_position)>.05,"Replicated moving door "+name)
  var trains: Array=game.gates.filter(func(g):return g.get("train",false))
  var positions: Array=trains.map(func(g):return g.node.position)
  await pause(.3)
  check(trains.size()==3 and range(trains.size()).all(func(i):return trains[i].node.position.distance_to(positions[i])>.01),"All three trains replicate movement")
  check(await wait_for(func():return game.feed.any(func(e):return e.text=="TEST_DONE"),10),"Server completes")
 print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
 game.disconnect_game("Test completed");await pause(.1);quit(0 if failures.is_empty() else 1)
