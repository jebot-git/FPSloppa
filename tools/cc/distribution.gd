extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
 var base=g.map_catalog.filter(func(row):return row.get("distribution","")=="base")
 var quake=[]
 for i in range(1,8):quake.append("qsrc_dm"+str(i))
 g.map_catalog=base
 for mode in ["dm","ig","ft","tdm","if"]:check(g.maps_for_mode(mode)==quake,mode+" offers exactly seven bundled Quake maps")
 check(g.maps_for_mode("cc").size()==4 and g.maps_for_mode("cc").all(func(id):return id.begins_with("cc_")),"CC offers only four remodels")
 check(g.maps_for_mode("ctf").size()==6 and g.maps_for_mode("ctf").all(func(id):return id.begins_with("ctf_")),"CTF offers all six studies")
 check(not g.map_catalog.any(func(row):return str(row.id).begins_with("lqdm")),"Original LibreQuake assets are absent from base catalog")
 var ui=load("res://deathmatch/interface.gd").new();g.add_child(ui);ui.setup(g)
 for mode in ["dm","ig","ft","tdm","cc","ctf"]:
  ui.host_mode.choose(mode);ui.refresh_maps()
  check(ui.map_choice.items.size()==(4 if mode=="cc" else 6 if mode=="ctf" else 7),mode+" host dropdown follows base selection")
 var user_row=g.map_catalog.filter(func(r):return r.id=="qsrc_dm2")[0].duplicate(true);user_row.id="user_map";user_row.custom=true
 g.map_catalog.append(user_row)
 for mode in ["dm","ig","ft","tdm","cc","koth"]:check("user_map" in g.maps_for_mode(mode),mode+" retains imported map availability")
 g.mode_maplists={"cc":["qsrc_dm4","user_map","cc_basement"],"koth":["user_map","qsrc_dm3"],"dm":["user_map","qsrc_dm7"]}
 for mode in ["cc","koth","dm"]:check(g.maps_for_mode(mode)==g.mode_maplists[mode],mode+" preserves custom server maplist and order")
 g.votes.allowed_modes=["dm","cc","koth"]
 var choices=g.votes.match_choices()
 check(choices.any(func(r):return r.mode=="cc" and r.map=="qsrc_dm4"),"Vote permits configured cross-mode base map")
 check(choices.any(func(r):return r.mode=="koth" and r.map=="user_map"),"Vote permits configured imported KOTH map")
 var lobby=g.lobby.choices();check(lobby.any(func(r):return r.mode=="cc" and r.map=="qsrc_dm4"),"Lobby honors personal CC list")
 g.mode_maplists.clear();g.selected_map="user_map";g.start_host("Imported CC",0,100,30,true,"cc")
 check(g.active and g.current_map=="user_map","Imported map hosts CC without forced replacement")
 while not g.bots.ready_to_walk:await physics_frame
 g.votes.allowed_modes=["dm","cc"];g.votes.change_mode("dm")
 check(g.current_map=="user_map","Mode vote retains a compatible imported map")
 while not g.bots.ready_to_walk:await physics_frame
 await physics_frame;await physics_frame
 g.free();print("BASE_DISTRIBUTION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
