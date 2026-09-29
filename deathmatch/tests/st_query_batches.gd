extends "res://deathmatch/tests/native_bots.gd"
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.start_host("ST query batches",0,100,60,true,"st");game.set_process(false);game.set_physics_process(false);bots=game.bots
	while not bots.navigation.ready():await physics_frame
	var nav=bots.navigation;var context:Dictionary={};var starts:Array=[game.spawn_points[0],game.spawn_points[1],Fixture.ORIGIN]
	for start in starts:
		for goal in [game.spawn_points[2],game.spawn_points[3],Fixture.ORIGIN]:
			for jump in [false,true]:
				var ref:PackedVector3Array=nav.path(start,goal,jump)
				check(nav.path(start,goal,jump,context)==ref,"Batched path matches fresh query")
				var copy:PackedVector3Array=nav.path(start,goal,jump,context)
				if not copy.is_empty():copy[0]=Vector3(999,999,999)
				check(nav.path(start,goal,jump,context)==ref,"Caller mutation cannot poison cached path")
	var previous=context.iteration
	var region=nav.region;region.enabled=false
	NavigationServer3D.map_force_update(region.get_navigation_map())
	var until:=Time.get_ticks_msec()+5000
	while NavigationServer3D.map_get_iteration_id(region.get_navigation_map())==previous and Time.get_ticks_msec()<until:await physics_frame
	check(NavigationServer3D.map_get_iteration_id(region.get_navigation_map())!=previous,"Navigation map iteration advanced")
	check(nav.path(starts[0],game.spawn_points[2],true,context)==nav.path(starts[0],game.spawn_points[2]),"Map change invalidates cached success")
	previous=NavigationServer3D.map_get_iteration_id(region.get_navigation_map())
	region.enabled=true
	NavigationServer3D.map_force_update(region.get_navigation_map())
	until=Time.get_ticks_msec()+5000
	while NavigationServer3D.map_get_iteration_id(region.get_navigation_map())==previous and Time.get_ticks_msec()<until:await physics_frame
	check(nav.path(starts[0],game.spawn_points[2],true,context)==nav.path(starts[0],game.spawn_points[2]),"Restored map invalidates cached failure")
	var combat=game.match_mode.tribes.combat;var origin:=Fixture.ORIGIN+Vector3.UP*30
	var ids:Array=[]
	for i in 6:
		var id:int=game.variant_combat.launch(-1,10,origin+Vector3(0,0,-2-i),Vector3.FORWARD);ids.append(id)
		game.projectiles[id].stuck=i%2==0
	for i in 80:game.variant_combat.launch(-1,3,origin+Vector3(i+5,0,0),Vector3.FORWARD)
	check(combat.mines.size()==6,"Index excludes non-mine projectiles")
	for radius in [0.,.1,.5]:
		for x in [0.,.2,1.]:
			var start:Vector3=origin+Vector3.RIGHT*x;var end:Vector3=start+Vector3.FORWARD*15
			var hit:Dictionary={"id":0,"hit":false,"position":end}
			combat.indexed_mines=false;var ref:Dictionary=combat.trace_mines(start,end,hit.duplicate(),radius)
			combat.indexed_mines=true;compare(ref,combat.trace_mines(start,end,hit.duplicate(),radius),"Mine trace parity")
	game.projectiles[ids[1]].stuck=true
	var start:Vector3=origin+Vector3.FORWARD*2.5;var end:Vector3=origin+Vector3.FORWARD*15
	check(combat.trace_mines(start,end,{"id":0,"hit":false,"position":end},0).get("mine")==ids[1],"Same-tick landing is traceable")
	game._projectile_end(ids[1],game.projectiles[ids[1]].position,10)
	check(not combat.mines.has(ids[1]),"Removal immediately updates index")
	# Multiple nearby mines may be removed recursively before the parent blast
	# reaches them. Iteration must remain valid, with no repeated damage/removal.
	combat.explode(ids[0],game.projectiles[ids[0]].position)
	for id in combat.mines:check(game.projectiles.has(id),"Chain leaves no stale index entries")
	for id in game.projectiles.keys():game._projectile_end(id,game.projectiles[id].position,game.projectiles[id].weapon)
	check(combat.mines.is_empty(),"All removal paths drain index")
	game.variant_combat.launch(-1,10,origin,Vector3.FORWARD);game.match_mode.tribes.reset();check(combat.mines.is_empty(),"Mode reset clears index")
	game.disconnect_game();game.free()
	print("ST_QUERY_BATCHES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
