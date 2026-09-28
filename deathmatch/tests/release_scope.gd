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
	check(not preload("res://deathmatch/release_features.gd").TRIBES,"Tribes is deferred")
	check(not Modes.NAMES.has("st") and not "st" in Config.MODES,"Host and server mode lists exclude ST")
	check(not "tribes" in Rules.IDS and not Rules.NAMES.has("tribes"),"Loadout choices exclude Tribes")
	for source in ['set sv_gametype "st"','set sv_gametypes "dm st"','set sv_weapon_rules "tribes"','map "ctf_stonehenge"','set ctf_maplist "ctf_stonehenge"','set sv_maplist "ctf_stonehenge"']:
		check(Config.parse(source).has("error"),"Config rejects deferred content: "+source)
	for mode in Config.MODES:
		check(not Config.parse('set sv_gametype "'+mode+'"').has("error"),"Existing mode still configures: "+mode)
	check(Config.parse(FileAccess.get_file_as_string("res://server.cfg")).has("values"),"Shipped server configuration parses")
	check(Maps.choices_for_mode([],"st",["ctf_stonehenge"]).is_empty(),"Explicit rotation cannot restore ST")
	check(not Maps.available_for_mode({"id":"ctf_stonehenge","modes":["ctf"]},"ctf"),"Stonehenge is excluded even with old CTF tags")
	check(Maps.catalog().all(func(row):return row.id!="ctf_stonehenge"),"Locally retained Stonehenge is not rediscovered")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Release scope",0,20,10,true,"dm","doom")
	game.set_process(false);game.set_physics_process(false)
	check(not game.armory.select("tribes") and game.armory.effective()=="doom","Direct loadout selection refuses Tribes")
	game.match_mode.kind="st"
	check(game.match_mode.kind=="dm" and not game.match_mode.tribes.enabled(),"Direct mode change cannot activate ST")
	check(game.votes.match_choices().all(func(row):return row.mode!="st" and row.get("weapon_rules","")!="tribes" and row.map!="ctf_stonehenge"),"Match vote choices contain only release content")
	game.disconnect_game();game.free()
	print("RELEASE_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
