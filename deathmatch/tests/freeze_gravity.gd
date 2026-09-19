extends "res://deathmatch/tests/special_modes.gd"
## Exercise actual capsule collisions through the authority's blocked-player path.
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Gravity",0,20,10,true,"ft");g.bots.free();g.bots=null
	g.set_physics_process(false);g.set_process(false)
	for kind in ["ft","if"]:
		prepare(kind)
		var actor=g.fighters[-1]
		actor.position=Fixture.point()+Vector3.UP*6;actor.velocity=Vector3(8,7,2)
		g._damage(-1,1,10000,"RAILGUN")
		var deaths: int=g.players[-1].deaths;var kills: int=g.players[1].kills
		g.players[-1].move=Vector2.ONE;g.players[-1].jump=true;g.players[-1].swim=Vector3.UP
		actor.jump_queued=true;actor.apply_blast(Vector3(10,15,10))
		await physics_frame;g._server_tick(1.0/60)
		check(actor.position.y<Fixture.ORIGIN.y+6 and actor.velocity.y<0,kind+": airborne freeze immediately falls despite jump/blast")
		for frame in 100:
			await physics_frame;g._server_tick(1.0/60)
		check(actor.is_on_floor() and absf(actor.position.y-Fixture.ORIGIN.y)<.03,kind+": frozen capsule lands on solid ground")
		check(Vector2(actor.position.x,actor.position.z).distance_to(Vector2(Fixture.ORIGIN.x,Fixture.ORIGIN.z))<.01,kind+": movement and swim input cannot steer statue")
		check(g.match_mode.special.frozen.has(-1) and g.players[-1].deaths==deaths and g.players[1].kills==kills,kind+": landing preserves frozen state and scores")
		var landed: Vector3=actor.position
		g._blast(landed+Vector3.UP*.3,1,100,3)
		check(actor.velocity.length()<.01 and actor.blast_velocity==Vector2.ZERO,kind+": explosions cannot launch a landed statue")
		g.fighters[-3].position=landed+Vector3.RIGHT
		g.match_mode.tick(3.0)
		check(not g.match_mode.special.frozen.has(-1) and g.players[-1].hp==100 and actor.position.distance_to(landed)<.001,kind+": teammate thaws landed player in place")
		g.players[-1].invulnerable=0;g._damage(-1,1,10000,"RAILGUN")
		deaths=g.players[-1].deaths;kills=g.players[1].kills
		actor.position=Vector3(1000,g.fall_limit-1,1000)
		await physics_frame;g._server_tick(1.0/60)
		check(actor.position.y>g.fall_limit and g.match_mode.special.frozen.has(-1) and g.players[-1].hp==0,kind+": void relocates statue to a reachable spawn still frozen")
		check(g.players[-1].deaths==deaths and g.players[1].kills==kills,kind+": void recovery does not award another death or frag")
	print("FREEZE_GRAVITY_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
