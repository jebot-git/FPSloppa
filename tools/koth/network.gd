extends SceneTree
var game
var failures: Array=[]
var checks: Array=[]
var gong_count:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func wait_for(test: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+25000
 while Time.get_ticks_msec()<deadline:
  if test.call():return true
  if game.active and game.multiplayer.is_server():
   if not game.is_physics_processing():game.clock+=.05
   game._send_snapshot()
  await create_timer(.05).timeout
 return false
func message(value: String) -> bool:return game.feed.any(func(row):return row.text.contains(value))
func run() -> void:
 var role:=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.round_clock.round_ended.connect(func():gong_count+=1)
 if role=="server":
  game.selected_map="koth_solstice";game.dedicated=true;game.match_mode.configure({"sv_gametype":"koth"});game.start_host("KOTH rotation",28776,100,10,false,"koth")
  check(await wait_for(func():return message("KOTH_INITIAL_OK")),"Initial client receives three hill sites")
  game.set_physics_process(false);game.match_mode.hill_remaining=.2;game._send_snapshot()
  check(await wait_for(func():return message("KOTH_BOUNDARY_OK")),"Client sees the countdown immediately before relocation")
  game.match_mode.tick(.3);game._send_snapshot()
  check(await wait_for(func():return message("KOTH_MOVED_OK")),"Client receives next hill and reset countdown")
  print("KOTH_LATE_READY")
  check(await wait_for(func():return message("KOTH_LATE_OK")),"Late joiner receives the active second hill")
  game._end_round();game._end_round();game._send_snapshot()
  check(await wait_for(func():return message("KOTH_GONG_viewer") and message("KOTH_GONG_late")),"Round-end gong reaches both clients exactly once")
  game._announcement.rpc("KOTH_NETWORK_DONE");await create_timer(.5).timeout
 else:
  game.start_join(role,"127.0.0.1",28776,true)
  check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins KOTH server")
  check(await wait_for(func():return game.match_mode.hills.size()==3),"Snapshot contains all three authored sites")
  if role=="viewer":
   game._chat_request.rpc_id(1,"KOTH_INITIAL_OK")
   check(await wait_for(func():return game.match_mode.hill_remaining<.3),"Countdown replicates before the boundary")
   await create_timer(1.1).timeout;game._chat_request.rpc_id(1,"KOTH_BOUNDARY_OK")
   check(await wait_for(func():return game.match_mode.hill_index==1 and game.match_mode.hill_remaining>29),"Hill movement and new countdown replicate together")
   check(game.match_mode.hill==game.match_mode.hills[1],"Replicated hill matches the active site")
   await create_timer(1.1).timeout;game._chat_request.rpc_id(1,"KOTH_MOVED_OK")
  else:
   check(await wait_for(func():return game.match_mode.hill_index==1 and game.match_mode.hill==game.match_mode.hills[1]),"Late join starts at current hill instead of first hill")
   game._chat_request.rpc_id(1,"KOTH_LATE_OK")
  check(await wait_for(func():return game.intermission>0 and gong_count>0),"Round-end gong arrives with intermission")
  await create_timer(1.1).timeout;check(gong_count==1,"Repeated end request and snapshots do not replay gong")
  game._chat_request.rpc_id(1,"KOTH_GONG_"+role)
  check(await wait_for(func():return message("KOTH_NETWORK_DONE")),"Network scenario completes")
 FileAccess.open("res://test-results/koth-rotation/network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("KOTH_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
