extends SceneTree
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run():
	for map in Maps.IDS:
		seed(7129)
		var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
		g.max_clients=16;g.selected_map=map;g.start_host("CS16 tactics regression",0,20,60,true,"de")
		g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true
		for id in [-1,-2,-3]:g._peer_left(id)
		for i in 12:g._add_player(-1000-i,"Bot "+str(i));g.players[-1000-i].team=i%2
		var de=g.match_mode.defusal;de.reset();de.tick(0)
		while not g.bots.ready_to_walk or not g.bots.navigation.ready():await physics_frame
		var ai=g.bots
		for id in g.players:
			if id<0:ai.brains[id]=ai.new_brain(id)
		var data: Dictionary=de.tactics.profile(de)
		check(not data.is_empty(),map+": profile bound to installed BSP")
		if data.is_empty():g.disconnect_game();g.free();continue
		for site in 2:
			for lane in data.attacks[site]:
				var previous: Vector3=de.starts[0][0]
				for raw in lane.points:
					var point:=Maps.vector(raw)
					var nearest:=NavigationServer3D.map_get_closest_point(ai.region.get_navigation_map(),point)
					check(nearest.distance_to(point)<.8,map+": waypoint grounded "+lane.name+str(raw)+" actual="+str(nearest))
					var path: PackedVector3Array=ai.navigation.path(previous,point)
					check(is_finite(ai.navigation.cost(previous,point,path)),map+": lane connected "+lane.name+str(raw))
					previous=point
			for hold in data.holds[site]:
				var point:=Maps.vector(hold.position)
				check(ai.navigation.landing_clear(point),map+": hold capsule clear "+hold.name)
				var nearest:=NavigationServer3D.map_get_closest_point(ai.region.get_navigation_map(),point)
				check(nearest.distance_to(point)<.6,map+": hold grounded "+hold.name+" actual="+str(nearest))
		# A split must survive repeated planning; reaching a checkpoint advances it.
		de.phase="live";de.phase_end=g.clock+120;de.carrier=-1000
		var lane_ids: Dictionary={}
		for id in ai.brains:
			if de.role(id)!=0:continue
			var rows: Array=[];de.bot_goals(ai,id,rows)
			lane_ids[ai.brains[id].de_route_lane]=true
			var step: int=ai.brains[id].de_route_step
			g.fighters[id].position=rows[0].position;rows.clear();de.bot_goals(ai,id,rows)
			check(ai.brains[id].de_route_step>step,map+": checkpoint advances "+str(id))
		check(lane_ids.size()==data.attacks[de.round_id%2].size(),map+": attack uses each lane")
		# Public bomb location assigns one runner; dead runner is replaced.
		de.carrier=0;de.bomb_position=de.sites[0]
		var recovery: Array=[]
		for id in ai.brains:
			if de.role(id)!=0:continue
			var rows: Array=[];de.bot_goals(ai,id,rows)
			if rows[0].key=="de:recover":recovery.append(id)
		check(recovery.size()==1,map+": one bomb recovery runner")
		if recovery.size()==1:
			de.carrier=recovery[0];var rows: Array=[];de.bot_goals(ai,de.carrier,rows)
			check(rows[0].position==de.sites[de.round_id%2],map+": recovery does not restart opening")
		de.planted=true;de.carrier=0;de.planted_site=1;de.bomb_position=de.sites[1]+Vector3.UP*.15;de.fuse_end=g.clock+45
		var workers: Array=[]
		for id in ai.brains:
			if de.role(id)!=1:continue
			var rows: Array=[];de.bot_goals(ai,id,rows)
			if rows[0].key=="de:defuse":workers.append(id)
		check(workers.size()==1,map+": exactly one planned defuser")
		if workers.size()==1:
			g.players[workers[0]].dead=true
			var successor: int=de.tactics.worker(de,ai)
			check(successor!=0 and successor!=workers[0],map+": dead defuser replaced immediately")
			de.defuser=successor
			check(de.tactics.worker(de,ai)==successor,map+": active defuser keeps lock")
		# A wall-height bomb still assigns a reachable floor and prefers a kit
		# when two living CTs have identical travel distance.
		var defenders: Array=[]
		for id in ai.brains:
			if de.role(id)==1:defenders.append(id)
		de.defuser=0;de.tactics.assignment_until=0
		for id in defenders:
			g.players[id].dead=false;g.players[id].spectator=id not in defenders.slice(0,2)
			g.fighters[id].position=de.sites[1];de.account(id).kit=id==defenders[1]
		de.bomb_position=de.sites[1]+Vector3.UP*2.4
		check(de.tactics.bomb_floor(de).distance_to(de.sites[1])<.3,map+": raised bomb has floor destination")
		check(de.tactics.worker(de,ai)==defenders[1],map+": equal travel prefers kit")
		g.players[1].spectator=false;g.players[1].dead=false;g.players[1].team=1-de.attacking
		de.defuser=1
		check(de.tactics.worker(de,ai)==1,map+": human defuser keeps priority")
		var sha: String=g.map_sha;g.map_sha="unrecognized"
		check(de.tactics.profile(de).is_empty(),map+": changed geometry rejects profile")
		g.map_sha=sha
		g.disconnect_game();g.free();await process_frame
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16-study/tactics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_TACTICS_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
