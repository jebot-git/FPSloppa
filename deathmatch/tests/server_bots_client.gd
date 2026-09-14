extends SceneTree
func _initialize():run.call_deferred()
func run():
 var args=OS.get_cmdline_user_args();var role:String=args[0]
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_join(role,"127.0.0.1",28942)
 var deadline=Time.get_ticks_msec()+60000;var joined=false;var previous:Dictionary={};var moved=false
 while Time.get_ticks_msec()<deadline:
  if role=="extra" and game.last_event.to_lower().contains("server full"):
   print("BOT_CLIENT_REJECTED");game.free();quit();return
  if game.active and not joined:
   if role=="extra":quit(1);return
   joined=true;print("BOT_CLIENT_JOINED ",role)
  if joined:
   for id in game.fighters:
    if id>=0:continue
    if not previous.has(id):previous[id]=game.fighters[id].position
    elif game.fighters[id].position.distance_to(previous[id])>1 and not moved:
     moved=true;print("BOT_CLIENT_MOVEMENT")
   if FileAccess.file_exists("res://test-results/server-bots/stop-"+role):
    print("BOT_CLIENT_ROSTER ",game.players.size());game.disconnect_game();game.free();quit();return
  await create_timer(.05).timeout
 game.free();quit(1)
