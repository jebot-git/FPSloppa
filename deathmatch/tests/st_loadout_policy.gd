extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const Shop=preload("res://deathmatch/tribes/buy_wheel.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	var st_maps: Array=g.map_catalog.filter(func(row):return "st" in row.get("modes",[])).map(func(row):return row.id)
	check(st_maps.size()>=3,"Bundled ST maps are classified")
	for mode in g.match_mode.NAMES:
		if mode=="st":continue
		g.match_mode.kind=mode;g.armory.select("tribes")
		check(Maps.choices_for_mode(g.map_catalog,mode,["qsrc_dm1"]+st_maps)==["qsrc_dm1"],"Configured ST maps excluded from "+mode)
		check(Maps.inherited_maplist(g.map_catalog,mode,st_maps).is_empty(),"Inherited ST maps excluded from "+mode)
		for id in st_maps:check(not g._load_map(id),"Direct ST map load rejected in "+mode+": "+id)
		g.mode_maplists[mode]=["qsrc_dm1"]+st_maps
		check(not g.maps_for_mode(mode).any(func(id):return id in st_maps),"Map choices exclude ST in "+mode)
	g.mode_maplists.clear();g.match_mode.kind="dm";g.selected_map="ctf_stonehenge"
	g.start_host("ST loadout policy",0,100,30,true,"tdm","tribes")
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	check(g.active and g.current_map not in st_maps,"Hosting arena mode replaces incompatible selected ST map")
	var r=g.match_mode.tribes;var s: Dictionary=g.players[1]
	for mode in ["dm","tdm","ctf","koth","ft"]:
		g.match_mode.kind=mode;g.armory.select("tribes");s.dead=false;s.spectator=false;s.team=0
		check(Rules.selectable(mode) and g.armory.effective()=="tribes" and r.enabled() and not r.mode_enabled(),"ST loadout remains selectable in "+mode)
		r.energy=[0,0,0];g.clock+=1
		check(r.select_equipment(1,"heavy",r.Arsenal.defaults("heavy"),"ammo"),"Arena loadout queues in "+mode)
		for i in 3:r.spawn(1)
		check(s.tribes_class=="heavy" and s.tribes_pack=="ammo" and s.tribes_ammo[2]>0 and not s.tribes_fallback and s.tribes_paid==0,"Arena respawns keep equipped kit without ST funds in "+mode)
		r.tick(60);check(r.energy==[0,0,0] and r.credit==0,"ST economy inactive in "+mode)
		check(r.stations()==null and not r.can_refit(1) and not r.can_open_inventory(1) and not r.deployables.active() and not r.vehicles.active() and not r.commander.member(1),"ST base systems inactive in "+mode)
		g.clock+=1;check(not r.select_equipment(1,"light",[0,2,3],"turret") and not r.select_equipment(1,"light",[0,2,3],"energy",true),"Arena rejects ST deployable packs and refits in "+mode)
		var shop:=Shop.new();shop.open(s);var rows:=shop.rows(r,1)
		check(not rows.any(func(row):return row.id in [206,207]) and rows.all(func(row):return not row.buy and row.currency.is_empty()),"Arena loadout menu hides ST systems and prices in "+mode)
		check(not "TEAM ENERGY" in preload("res://deathmatch/ui/player_status.gd").read(g,1).ability,"Arena HUD omits ST reserve in "+mode)
	# Mode requirements still force the full ST loadout.
	g.match_mode.kind="st";g.armory.select("doom")
	check(g.armory.effective()=="tribes" and r.mode_enabled() and g.maps_for_mode("st")==st_maps,"ST retains its dedicated maps and mandatory loadout")
	g.disconnect_game();g.free()
	print("ST_LOADOUT_POLICY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
