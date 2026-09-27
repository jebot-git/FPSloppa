extends SceneTree
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
const Config=preload("res://deathmatch/server/config.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	check(Maps.entries().size()==5,"All five DE layouts registered")
	check(Config.parse('set sv_gametype "de"\nset de_maplist "qsrc_dm1"').has("error"),"DE rejects unsupported rotation maps")
	for id in Maps.IDS:
		var cfg: Dictionary=Config.parse('set sv_gametype "de"\nmap '+id)
		check(cfg.values.map==id and cfg.values.sv_weapon_rules=="cs16" and cfg.values.maps.size()==5,"Configuration honors selected map and five-map rotation: "+id)
		var hash: String=FileAccess.get_sha256("res://maps/"+id+".bsp")
		check(Maps.supported(id,hash) and Maps.supported("renamed_copy",hash) and not Maps.supported(id,"invalid"),"Objective registry validates compiled hash: "+id)
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=id;g.start_host("Map objectives",0,20,10,true,"de")
		g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
		await physics_frame;await physics_frame
		var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0)
		check(g.current_map==id and de.supported() and de.starts[0].size()==8 and de.starts[1].size()==8,"Runtime loads map and both eight-player bases: "+id)
		var objectives=load("res://deathmatch/ui/defusal_world.gd").new();g.get_node("Map").add_child(objectives);objectives.setup(de);objectives.update()
		var fixed_labels: Array=[]
		for label in objectives.find_children("*","Label3D",true,false):
			if label!=objectives.hint and not objectives.bomb.is_ancestor_of(label):fixed_labels.append(label)
		check(fixed_labels.is_empty(),"No floating plant-point text on "+id)
		check(g.get_node("Map").find_children("*","Label3D",true,false).all(func(label):return objectives.is_ancestor_of(label)),"Compiled map adds no floating site text: "+id)
		for site in 2:
			check(de.site_at(de.sites[site])==site,"Correct mapped site "+id+" "+str(site))
			de.clear_bomb();de.carrier=1;de.held=true;de.armed_until=g.clock+5;de.arm_index=4
			g.players[1].yaw=0.0;g.players[1].pitch=0.0;g.fighters[1].position=de.sites[site]+Vector3(0,0,.8)
			var place: Dictionary=de.placement(1)
			check(not place.is_empty() and place.site==site,"Site center supports real surface mounting "+id+" "+str(site))
			check(de.plant(1,site),"Authority plants bomb at "+id+" "+str(site))
			var data: Dictionary=de.snapshot();check(de.valid_snapshot(data),"Map objective snapshot validates "+id+" "+str(site))
		check(de.site_at(de.starts[0][0])==-1 and de.site_at(de.starts[1][0])==-1,"Spawn areas cannot plant: "+id)
		if id=="de_nuke_rebuilt":
			check(de.site_at(de.sites[0]-Vector3.UP*2)==-1,"Nuke intermediate height cannot plant in stacked sites")
		objectives.free()
		g.disconnect_game();g.free();await process_frame
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/classic-de/maps.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_MAP_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
