extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
var game
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func wait_for(test: Callable,seconds: float=12.0) -> bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await create_timer(.025).timeout
 return false
func run():
 var role:=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 if role=="server":
  var settings=Config.parse('set sv_maplist "lqdm1 lqdm2 lqdm4"')
  check(settings.values.maps==["lqdm1","lqdm2","lqdm4"],"Ordered map list parses")
  check(Config.parse('map lqdm7').values.maps==["lqdm7"],"Single map config remains supported")
  check(Config.parse('set sv_maplist "'+"lqdm1 ".repeat(33)+'"').has("error"),"Excessive rotation list rejected")
  var config_path:="user://rotation_test_server.cfg"
  var file:=FileAccess.open(config_path,FileAccess.WRITE)
  file.store_string('set sv_gametype "ctf"\nset sv_gametypes "ctf koth"\nset net_port "28901"\nmap lqdm7\nset sv_maplist "lqdm1 lqdm2"\nset ctf_maplist "lqdm1 lqdm2"\nset koth_maplist "lqdm1"\n');file.close()
  game._start_dedicated(PackedStringArray(["--config",config_path]))
  DirAccess.remove_absolute(config_path)
  check(game.active and game.current_map=="lqdm1" and game.map_rotation==["lqdm1","lqdm2"],"Dedicated startup reads rotation and starts its first entry")
  check(await wait_for(func():return game.players.size()==2),"Two clients joined before rotation")
  await create_timer(.3).timeout
  var teams: Dictionary={}
  for id in game.players:teams[id]=game.players[id].team
  for cycle in range(1,3):
   game.players[game.players.keys()[0]].kills=7
   if cycle==1:
    var voter: int=game.players.keys().filter(func(id):return not game.players[id].spectator)[0]
    check(game.votes.start(voter,"map","lqdm2"),"Active player passes map vote; spectator excluded from electorate")
   else:game._end_round();game.intermission=.1
   check(await wait_for(func():return game.map_epoch==cycle and game.players.size()==2 and not game.map_loading),"Clients complete map transition %d"%cycle)
   check(game.match_mode.kind=="ctf" and game.match_mode.scores==[0,0] and game.players.keys().all(func(id):return game.players[id].team==teams[id]),"CTF mode and assigned teams survive rotation; scores reset")
   check(game.current_map==("lqdm2" if cycle==1 else "lqdm1"),"Rotation advances and wraps")
   check(game.players.values().all(func(s):return s.kills==0 and s.hp==(0 if s.spectator else 100) and s.owned==[2]),"New map resets score and inventory")
   await create_timer(.7).timeout
  game.votes.cooldown=0
  var voter: int=game.players.keys().filter(func(id):return not game.players[id].spectator)[0]
  check(game.votes.start(voter,"mode","koth"),"Allowed game-mode vote passes")
  check(await wait_for(func():return game.map_epoch==3 and game.players.size()==2 and not game.map_loading),"Mode vote restarts current arena and reconnects peers")
  check(game.current_map=="lqdm1" and game.match_mode.kind=="koth" and game.match_mode.scores==[0,0],"Mode vote changes rules with fresh objectives")
  await create_timer(1).timeout
 else:
  game.start_join(role,"127.0.0.1",28901,role=="second")
  check(await wait_for(func():return game.active and game.players.has(game.multiplayer.get_unique_id())),"Client admitted")
  var my_id:int=game.multiplayer.get_unique_id()
  check(await wait_for(func():return game.match_mode.kind=="ctf"),"Client receives server game type")
  var team:int=game.local_state().team
  if role=="second":game.map_catalog=game.map_catalog.filter(func(row):return row.id!="lqdm2")
  for cycle in range(1,3):
   check(await wait_for(func():return game.map_epoch==cycle and game.active and game.players.has(my_id)),"Client rejoins new map without disconnect %d"%cycle)
   check(game.local_state().team==team,"Team assignment survives rotation")
   check(game.local_state().spectator==(role=="second"),"Spectator/player role survives map download and rotation")
   check(game.multiplayer.get_unique_id()==my_id and game.current_map==("lqdm2" if cycle==1 else "lqdm1"),"Connection ID retained and map matches")
   if role=="second" and cycle==1:check(game.map_network.message.contains("downloaded"),"Missing rotation map downloads and verifies before rejoining")
   var remaining:float=game.round_left
   game._snapshot([],PackedByteArray(),1,0,"stale",1,1,[],[],cycle-1)
   check(game.round_left==remaining,"Old-map snapshots cannot overwrite new round")
  check(await wait_for(func():return game.map_epoch==3 and game.active and game.match_mode.kind=="koth"),"Client follows voted mode change")
  check(game.current_map=="lqdm1" and game.local_state().spectator==(role=="second"),"Mode vote preserves spectator role and current map")
  await create_timer(.5).timeout
 print("MAP_ROTATION_RESULT ",role," ",JSON.stringify(failures))
 game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
