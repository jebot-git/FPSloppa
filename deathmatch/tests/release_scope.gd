extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const Maps=preload("res://deathmatch/maps/loader.gd")
const Modes=preload("res://deathmatch/modes/match.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 check(preload("res://deathmatch/release_features.gd").TRIBES,"Tribes is released")
 check(Modes.NAMES.has("st") and "st" in Config.MODES,"Host and server lists include ST")
 check("tribes" in Rules.IDS and Rules.NAMES.has("tribes"),"Loadout includes Tribes")
 for mode in Config.MODES:
  check(not Config.parse('set sv_gametype "'+mode+'"').has("error"),"Mode configures: "+mode)
 check(Config.parse(FileAccess.get_file_as_string("res://server.cfg")).has("values"),"Shipped server configuration parses")
 var catalog: Array=Maps.catalog()
 for id in ["ctf_stonehenge","ctf_raindance","ctf_katabatic"]:
  check(catalog.any(func(row):return row.id==id and row.get("distribution","")=="base"),"Bundled ST catalog: "+id)
  check(not Config.parse('set sv_gametype "st"\nmap "'+id+'"').has("error"),"ST config accepts "+id)
  check(Maps.available_for_mode({"id":id,"modes":["st"]},"st"),"ST selection accepts "+id)
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Release scope",0,20,10,true,"dm","doom")
 game.set_process(false);game.set_physics_process(false)
 game.match_mode.kind="st"
 check(game.match_mode.kind=="st" and game.match_mode.tribes.enabled(),"Direct mode selection activates ST")
 check(game.armory.effective()=="tribes","ST enforces its own loadout")
 game.disconnect_game();game.free()
 print("RELEASE_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
