extends SceneTree
var g
func vector(s: String)->Vector3:
	var a=s.trim_prefix('(').trim_suffix(')').split(',');return Vector3(float(a[0]),float(a[1]),float(a[2]))
func _initialize():run.call_deferred()
func run():
	g=load('res://deathmatch/arena.tscn').instantiate();root.add_child(g);g.selected_map='ctf_katabatic'
	g.start_host('Katabatic route replay',0,100,60,true,'st');g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,'Replay')
	while not g.bots.navigation.ready():await physics_frame
	var st=g.bots.tribes;var actor=g.fighters[-1];var s:Dictionary=g.players[-1]
	var cases=JSON.parse_string(FileAccess.get_file_as_string('res://deathmatch/tests/fixtures/st_katabatic_obstacles.json'))
	# Fresh spawn routes exercise both refitting and departure on both teams.
	for team in [0,1]:
		var stations=g.match_mode.tribes.stations().rows.filter(func(r):return r.team==team and r.kind=='inventory' and r.power_group=='base')
		for index in g.ctf_spawns[team].size():
			var start:Vector3=g.ctf_spawns[team][index]
			stations.sort_custom(func(a,b):return a.position.distance_squared_to(start)<b.position.distance_squared_to(start))
			for departure in [false,true]:
				var target:Vector3=g.match_mode.bases[1-team] if departure else stations[0].position
				cases.append({'id':'spawn-%d-%d-%s'%[team,index,departure],'team':team,'class':'light','pack':'energy','position':str(start),'velocity':str(Vector3.ZERO),'energy':60.,'goal':'departure' if departure else 'refit','target':target,'step':0})
	var results=[]
	for row in cases:
		s.team=row.team;s.dead=false;s.yaw=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.tribes.apply_equipment(-1,row['class'],[0,2,3],row.pack)
		actor.position=vector(row.position);actor.velocity=vector(row.velocity);actor.jump_held=false;actor.tribes_state.energy=row.energy
		var b:Dictionary=g.bots.new_brain(-1);g.bots.brains[-1]=b
		b.goal=row.target if row.has('target') else g.match_mode.tribes.stations().rows[int(row.goal.get_slice(':',2))].position;b.goal_kind='objective' if row.goal=='departure' else 'supply';b.goal_key=row.goal
		b.path=PackedVector3Array()
		if row.has('path'):
			for p in row.path.trim_prefix('[').trim_suffix(']').split('), ('):b.path.append(vector(p.trim_prefix('(').trim_suffix(')')))
		else:b.path=st.routes.path(actor.position,b.goal)
		b.step=row.step;b.route_at=g.clock+10
		await physics_frame;await physics_frame
		var arrived=false;var seconds=0.
		for frame in 3600:
			g.clock+=1./60;seconds+=1./60;s.last_input=g.clock
			if g.clock>=b.route_at:b.path=st.routes.path(actor.position,b.goal);b.step=0;b.route_at=g.clock+10
			st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1./60,s.jump)
			if actor.position.distance_to(b.goal)<1.8 or row.goal=='departure' and actor.position.distance_to(vector(row.position))>80:arrived=true;break
			if frame%300==0 and '--detail' in OS.get_cmdline_user_args():print('DETAIL ',row.id,' ',seconds,' ',actor.position,' next ',b.path[b.step] if b.step<b.path.size() else b.goal,' phase ',b.get('travel_phase',''))
		results.append({'id':row.id,'arrived':arrived,'seconds':seconds,'end':str(actor.position)})
		print('REPLAY ',JSON.stringify(results[-1]))
	print('KATABATIC_REPLAY ',JSON.stringify(results))
	g.disconnect_game();g.free();quit(0 if results.all(func(r):return r.arrived) else 1)
