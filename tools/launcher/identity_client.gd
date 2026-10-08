extends SceneTree
var game
func _initialize() -> void:run.call_deferred()
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 var deadline:=Time.get_ticks_msec()+120000
 var hash: String=OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--avatar")+1]
 while Time.get_ticks_msec()<deadline:
  var mine: int=game.multiplayer.get_unique_id()
  if game.players.has(mine) and game.avatars.choices.get(mine,{}).get("hash","")==hash:
   var name: String=game.players[mine].name
   print("IDENTITY_NETWORK_RESULT ",JSON.stringify({"name":name,"plain":game.Profile.Names.plain(name),"avatar":hash,"spectator":game.players[mine].spectator}))
   quit(0);return
  await create_timer(.05).timeout
 push_error("Identity admission/avatar acknowledgement timed out");quit(1)
