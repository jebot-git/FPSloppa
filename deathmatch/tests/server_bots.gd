extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
var game
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 check(Config.parse("").values.sv_bot_fill==0 and not Config.DEFAULTS.has("sv_tb_heavy_ordnance") and not Config.RANGES.has("sv_tb_heavy_ordnance"),"Bot fill remains opt-in and hull policy is no longer a server setting")
 for source in ["set sv_bot_fill -1","set sv_bot_fill 33","set sv_bot_fill 9\nset sv_maxclients 8","set sv_bot_fill 1.5"]:
  check(Config.parse(source).has("error"),"Reject invalid config: "+source.replace("\n","; "))
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Test",0,100,10,true,"tb","quake");game.set_physics_process(false);game.set_process(false)
 game.dedicated=true;game.practice=false;game.max_clients=6;game.bot_population.target=6
 check(game.match_mode.fortress.walkers.heavy_ordnance_only and not game.match_mode.fortress.walkers.pilot_regeneration,"Offline TB starts with fixed protection and no cockpit healing")
 for legacy in [0,1]:
  var parsed=Config.parse("set sv_gametype tb\nset sv_tb_heavy_ordnance "+str(legacy))
  check(not parsed.has("error") and not parsed.values.has("sv_tb_heavy_ordnance"),"Legacy hull setting is ignored: "+str(legacy))
  game.match_mode.fortress.walkers.heavy_ordnance_only=false;game.match_mode.fortress.walkers.pilot_regeneration=true
  game.match_mode.configure(parsed.values)
  check(game.match_mode.fortress.walkers.heavy_ordnance_only and not game.match_mode.fortress.walkers.pilot_regeneration,"New host restores fixed TB rules despite legacy setting: "+str(legacy))
 game.bot_population.maintain()
 check(game.players.size()==6 and game.players.has(1),"Configured total includes the human")
 check(game.bot_population.human_slots()==1,"Bots consume no human admission reservations")
 var ids=game.players.keys();game.pending_names[42]="Incoming";game.pending_spectators[42]=false
 check(game.players.keys()==ids,"Downloading human does not evict a bot early")
 check(game.bot_population.make_room(42) and game.players.size()==5,"Ready human evicts exactly one bot from full match")
 game.pending_names.erase(42);game._add_player(42,"Incoming");game.bot_population.maintain()
 check(game.players.size()==6 and game.players.has(42),"Human replaces bot without exceeding capacity")
 var humans=game.players.keys().filter(func(id):return id>0)
 game.bot_population.target=0;game.bot_population.maintain()
 check(game.players.keys()==humans,"Disabling fill removes bots and preserves humans")
 for id in [43,44,45,46]:game.pending_names[id]="Reserved"
 check(game.bot_population.human_slots()==6,"Concurrent accepted downloads reserve remaining human seats")
 game.pending_names[47]="Overflow"
 check(not game.bot_population.make_room(47),"Overbooked completion cannot displace a human")
 game.pending_names.clear();game.pending_spectators.clear();game.pending_teams.clear()
 for id in game.players.keys():game._peer_left(id)
 game.max_clients=1;game.bot_population.target=1;game.bot_population.maintain()
 var pilot:int=game.players.keys()[0];var w=game.match_mode.fortress.walkers
 w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}])
 game.players[pilot].team=0;game.fighters[pilot].position=Vector3(1000,0,0)
 await physics_frame;await physics_frame
 check(w.try_board(pilot,"test"),"Bot can occupy cockpit before replacement")
 game.pending_names[48]="New pilot"
 check(game.bot_population.make_room(48) and not w.mounted(pilot) and not game.fighters.has(pilot),"Replacing sole pilot releases cockpit and fighter through normal departure")
 game.pending_names.clear();game.bot_population.maintain()
 check(game.players.size()==1 and game.players.keys()[0]!=pilot,"Disconnected bot slot refills with a fresh ID")
 var old_bots=game.bots.get_instance_id()
 check(game._rotate_map("tb_foundry") if game.map_catalog.any(func(row):return row.id=="tb_foundry") else game._rotate_map(game.current_map),"Dedicated rotation succeeds")
 check(game.bots.get_instance_id()!=old_bots and game.players.size()==1,"Map rotation refreshes navigation and population")
 check(w.heavy_ordnance_only and not w.pilot_regeneration,"Fixed TB protection and no healing survive map rotation")
 game.match_mode.configure({"sv_gametype":"dm"});game.match_mode.configure({"sv_gametype":"tb"})
 check(w.heavy_ordnance_only and not w.pilot_regeneration,"Switching modes retains fixed TB rules")
 game.disconnect_game();game.free();await process_frame
 print("SERVER_BOTS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
