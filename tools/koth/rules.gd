extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var cfg=preload("res://deathmatch/server/config.gd").parse('set sv_gametype koth\nset koth_move_points 5\nset hilllimit 100\n')
 check(not cfg.has("error") and not cfg.values.has("koth_move_points"),"Legacy movement setting accepted and ignored")
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
 g.start_host("KOTH rules",0,100,30,true,"koth");g._add_player(2,"Opponent")
 g.players[1].team=0;g.players[2].team=1;g.players[1].dead=false;g.players[2].dead=false
 var hill=Vector3(0,100,0);g.match_mode.hill=hill;g.match_mode.scores=[0,0]
 g.fighters[1].position=hill;g.fighters[2].position=hill+Vector3.RIGHT*20
 g.match_mode.tick(25)
 check(g.match_mode.scores==[25,0] and g.match_mode.hill==hill,"25 seconds scores without moving hill")
 g.fighters[2].position=hill;g.match_mode.tick(3)
 check(g.match_mode.scores==[25,0] and g.match_mode.hill_owner==-2,"Contested hill pauses both teams")
 g.fighters[1].position=hill+Vector3.RIGHT*20;g.match_mode.tick(26)
 check(g.match_mode.scores==[25,26] and g.match_mode.hill==hill,"Opponent takeover scores at same fixed hill")
 var snapshot=g.match_mode.snapshot();g.match_mode.hill=Vector3.ZERO;g.match_mode.receive(snapshot)
 check(g.match_mode.hill==hill and not snapshot.has("hill_move_points"),"Snapshot preserves fixed hill without rotation state")
 g.players.erase(2);g.fighters[2].free();g.fighters.erase(2)
 g.votes.allowed_modes=["dm","koth"]
 g.votes.change_mode("dm")
 check(g.match_mode.kind=="dm" and not g.current_map.begins_with("koth_"),"Mode vote leaves KOTH-only arena for DM")
 g.votes.change_mode("koth")
 check(g.match_mode.kind=="koth" and g.current_map in g.maps_for_mode("koth"),"Mode vote enters a remodeled KOTH arena")
 g.mode_maplists["koth"]=["qsrc_dm1"]
 check(g._rotate_map("qsrc_dm1"),"Explicit server KOTH list may select other maps")
 g.free();print("KOTH_RULES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
