extends SceneTree
## Deterministic route driver, with production movement, pickups, weapons and AS rules.
var game
var failed: Array=[]
func _initialize():call_deferred("run")
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y,z,-x)/32.0+Vector3.UP*.05
func run() -> void:
	var args:=OS.get_cmdline_user_args();var path: String=args[0];var out: String=args[1]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-playthrough.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
	game.start_host("Red route bot",0,20,7,true,"as")
	if not game.active:quit(1);return
	for attempt in 1200:
		if game.bots.ready_to_walk:break
		await create_timer(.05).timeout
	game.practice=false;game.dedicated=true
	for id in game.players:
		game.players[id].spectator=not id in [1,-1]
		if id in [1,-1]:game.players[id].team=0 if id==1 else 1
		game._spawn(id)
	game.players[-1].name="Blue route bot"
	if args.has("--vrm"):
		for id in [1,-1]:
			var sample:= "sample_d" if id==1 else "sample_f"
			var model_hash:=FileAccess.get_sha256(game.avatars.library.Paths.folder("vrm")+sample+".vrm")
			if not game.avatars.library.entries.has(model_hash):push_error("Missing VRM "+sample);quit(3);return
			game.avatars.choices[id]={"hash":model_hash,"size":game.avatars.library.entries[model_hash].size}
			game.players[id].name=("Red " if id==1 else "Blue ")+sample

	var route: Array=[q(-2400,0),q(-1800,0),q(-1744,128),q(-1592,128),q(-1592,-128),q(-1448,-128),q(-1448,128),q(-1304,128),q(-1304,-128),q(-1152,-128),q(-1120,0),q(-480,0),q(-464,224),q(128,224),q(128,0),q(856,0),q(856,-120),q(1072,-120,144),q(1200,0,144),q(1376,0,0),q(1496,0),q(1496,-120),q(1696,-120,144),q(1872,-32,144),q(1920,128,144),q(2000,128,0),q(1984,-64,0)]
	var index:=0;var last_leg:=0;var serial:=-1;var stalled:=0.0;var last:=Vector3.INF
	var timeline: Array=[]
	if not game.demos.start_record(out+".fpsdemo"):print(game.demos.message);quit(2);return
	for frame in 18000:
		await physics_frame
		var rules=game.match_mode.assault
		if rules.finished:
			for tail in 180:await physics_frame;game._physics_process(1.0/60)
			break
		var id:=1 if rules.attacking==0 else -1
		var actor=game.fighters[id];var s: Dictionary=game.players[id]
		for other in [1,-1]:game.players[other].move=Vector2.ZERO;game.players[other].fire=false;game.players[other].last_input=game.clock
		if last_leg!=rules.leg:
			last_leg=rules.leg;index=0;serial=-1;timeline.append({"event":"role_swap","time":game.clock-game.demos.started})
		if serial!=s.serial:
			serial=s.serial
			if s.deaths>0:
				var nearest:=INF
				for n in route.size():
					var d: float=actor.position.distance_to(route[n])
					if d<nearest:nearest=d;index=n
		if not s.dead and game.intermission<=0:
			while index<route.size() and Vector2(route[index].x-actor.position.x,route[index].z-actor.position.z).length()<.25 and absf(route[index].y-actor.position.y)<.65:
				print("PLAYTHROUGH ",rules.leg," waypoint ",index," hp ",s.hp," weapon ",s.weapon)
				index+=1
			var travel: Vector3=(route[index]-actor.position) if index<route.size() else Vector3.ZERO
			var aim: Vector3=travel.normalized();var threat:=false
			for gun_key in game.match_mode.fortress.buildings:
				var gun: Dictionary=game.match_mode.fortress.buildings[gun_key]
				if gun.team==s.team:continue
				var direction: Vector3=gun.position+Vector3.UP-game._shot_origin(id)
				if direction.length()>17:continue
				if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game._shot_origin(id),gun.position+Vector3.UP,1)).is_empty():continue
				aim=direction.normalized();threat=true
				if frame%60==0:print("ENGAGE ",gun_key," hp ",gun.hp," weapon ",s.weapon," ammo ",s.ammo," trace ",game._trace(game._shot_origin(id),gun.position+Vector3.UP,id))
				break
			if aim.length()>.01:s.yaw=atan2(-aim.x,-aim.z);s.pitch=asin(clampf(aim.y,-1,1)) if threat else 0.0
			s.move=Vector2.ZERO if threat else Vector2((Basis(Vector3.UP,-s.yaw)*travel).x,(Basis(Vector3.UP,-s.yaw)*travel).z).normalized()
			s.slow=true;s.fire=threat;s.last_input=game.clock
			if threat:
				for weapon in [5,3,2,7,6,4]:
					if weapon in s.owned and game.match_mode.fortress.can_fire(id,weapon):s.weapon=weapon;break
			stalled=stalled+1.0/60 if not threat and actor.position.distance_to(last)<.001 else 0.0
			if stalled>8:failed.append("Route stalled at leg %d waypoint %d position %s"%[rules.leg,index,actor.position]);break
			last=actor.position
		game._physics_process(1.0/60)
	game.demos.stop_record()
	if not game.match_mode.assault.finished:failed.append("Paired AS match did not finish")
	var result: Dictionary={"failures":failed,"map_sha256":hash,"duration":game.clock-game.demos.started,"first_attack_time":game.match_mode.assault.first_time,"scores":game.match_mode.scores,"timeline":timeline,"players":[]}
	for id in [1,-1]:
		var s: Dictionary=game.players[id];result.players.append({"id":id,"deaths":s.deaths,"shots":s.shots,"hp":s.hp,"owned":s.owned})
	FileAccess.open(out+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PLAYTHROUGH_RESULT ",JSON.stringify(result));game.free();quit(0 if failed.is_empty() else 1)
