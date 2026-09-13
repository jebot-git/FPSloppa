extends "res://deathmatch/tests/network_runner.gd"
class Observation extends Node:
	var seen: Dictionary={}
	var game
	var sync:=false
	var elapsed:=0.0
	func _process(delta: float) -> void:
		if not sync or not game or not game.active or not multiplayer.is_server():return
		elapsed+=delta
		if elapsed>=.05:elapsed=0;game._send_snapshot()
	@rpc("any_peer","call_remote","reliable")
	func report(stage_name: String) -> void:
		if multiplayer.is_server():seen[stage_name]=true
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0];var rule: String=args[1];var port:=int(args[2])
	var mode:="tf" if rule=="quake" else "as"
	var map_id:="tf_ironspan" if rule=="quake" else "as_frigate"
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var observation:=Observation.new();observation.name="WeaponProbe";root.add_child(observation)
	Fixture.setup(game)
	if role=="server":
		game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map=map_id;game.match_mode.configure({"sv_gametype":mode});game.armory.select(rule)
		game.start_host("Weapon test",port,100,6,false,mode)
		check(game.active,"Dedicated "+rule+" "+mode+" starts")
		if not game.active:finish_test(rule);return
		check(await wait_for(func():return game.players.size()==1,25),"Remote client joins real mode map")
		if game.players.is_empty():finish_test(rule);return
		game.set_physics_process(false);game.set_process(false)
		observation.game=game;observation.sync=true
		var id: int=game.players.keys()[0];var s: Dictionary=game.players[id];var actor=game.fighters[id]
		s.team=game.match_mode.assault.attacking if mode=="as" else 0;s.dead=false;s.invulnerable=0;s.hp=2000;s.armor=0;s.cooldown=0;s.owned=range(11);s.ammo=[200,100,100,300];s.tf_class="soldier"
		actor.position=Fixture.point();s.yaw=0;s.pitch=0
		game._send_snapshot()
		check(await wait_for(func():return observation.seen.has("rules")),"Peer acknowledges matching rules, pickups and loadout")
		var weapon:=5 if rule=="quake" else 3;s.weapon=weapon
		var pid: int=game.variant_combat.launch(id,weapon,Fixture.point(0,-3)+Vector3.UP,Vector3.FORWARD,{"alternate":rule=="ut99"})
		game._send_snapshot()
		check(await wait_for(func():return observation.seen.has("projectile")),"Peer receives projectile definition and velocity")
		game._projectile_end.rpc(pid,game.projectiles[pid].position,weapon)
		s.weapon=weapon;s.cooldown=0;s.fire=false;s.alt_fire=false;game._send_snapshot();game._announcement.rpc("INPUT_READY")
		check(await wait_for(func():return s.last_seq>=1000 and (s.get("alt_fire",false) if rule=="ut99" else s.fire)),"Alternate/primary input reaches dedicated authority")
		check(game.variant_combat.fire(id,rule=="ut99"),"Dedicated authority accepts remote firing solution")
		print("VARIANT_AUTH_AMMO ",s.ammo)
		game._send_snapshot()
		check(await wait_for(func():return observation.seen.has("fired")),"Remote ammo and firing result agree")
		for p in game.projectiles.keys():game._projectile_end.rpc(p,game.projectiles[p].position,game.projectiles[p].weapon)
		if mode=="as":
			var assault=game.match_mode.assault;var tf=game.match_mode.fortress
			s.weapon=3;s.cooldown=0;s.vr_device=false;s.xr={};s.pitch=0;s.yaw=0;s.input_blocked=false
			actor.position=assault.objectives[0].position+Vector3(0,0,3)
			for i in 6:s.cooldown=0;game.variant_combat.fire(id)
			check(assault.stage==1 and not tf.buildings.has(100100),"UT shock rifle destroys Frigate compressor through normal structure damage")
			game._send_snapshot();check(await wait_for(func():return observation.seen.has("objective")),"Objective destruction and unlocked door replicate")
			actor.position=assault.objectives[1].position;s.use_at=0;s.vr_device=true;game._use_for(id)
			check(assault.switching,"UT attacker activates final AS console")
			assault.next_leg();check(assault.stage==0 and tf.buildings.get(100100,{}).get("hp",0)==240,"UT AS role swap restores objective")
		else:
			var tf=game.match_mode.fortress
			var key:=999;tf.buildings[key]={"owner":0,"team":1,"position":Fixture.point(0,-3),"kind":"sentry","hp":150,"ready":0,"next":0,"expires":game.clock+100}
			s.weapon=7;s.cooldown=0;s.pitch=-.12;s.yaw=0;s.input_blocked=false;s.vr_device=false;s.xr={};actor.position=Fixture.point()
			for i in 9:s.cooldown=0;game.variant_combat.fire(id);game._update_projectiles(.1)
			check(not tf.buildings.has(key),"Quake super nails destroy enemy TF sentry")
			actor.position=game.match_mode.bases[1];game.match_mode.tick(.1)
			check(game.match_mode.flags[1].carrier==id,"Quake TF player can carry enemy flag")
			actor.position=game.match_mode.bases[0];game.match_mode.tick(.1)
			check(game.match_mode.scores[0]==1,"Quake TF capture scores normally")
		game._announcement.rpc("VARIANT_DONE");await pause(.5)
	else:
		game.start_join("Variant client","127.0.0.1",port)
		check(await wait_for(func():return game.active and game.current_map==map_id,25),"Client downloads/loads real mode map")
		if not game.active:finish_test(rule);return
		game.set_physics_process(false);game.set_process(false)
		check(game.armory.kind==rule and game.match_mode.kind==mode,"Ruleset arrives before map and loadout")
		check(game.pickups.all(func(p):return p.kind!="weapon" or game.armory.valid(p.item)),"Every map weapon has valid variant slot")
		observation.report.rpc_id(1,"rules")
		check(await wait_for(func():return not game.projectiles.is_empty()),"Client receives traveling projectile")
		if not game.projectiles.is_empty():
			var p: Dictionary=game.projectiles.values()[0]
			check(p.definition.kind==("nail" if rule=="quake" else "shock_orb") and p.velocity.length()>10,"Replicated alternate projectile has correct kind and speed")
		observation.report.rpc_id(1,"projectile")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="INPUT_READY")),"Client receives synchronized input stage")
		check(await wait_for(func():return game.local_state().ammo==[200,100,100,300]),"Client acknowledges controlled pre-shot ammunition")
		var ammo: Array=[199,100,100,300] if rule=="quake" else [200,100,100,299]
		game._input_command.rpc_id(1,{"seq":1000,"map_epoch":game.map_epoch,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":rule=="quake","alt_fire":rule=="ut99","weapon":5 if rule=="quake" else 3,"slow":false,"respawn":false})
		check(await wait_for(func():return game.local_state().ammo==ammo),"Authoritative ammo change reaches remote client")
		observation.report.rpc_id(1,"fired")
		if mode=="as":
			check(await wait_for(func():return game.match_mode.assault.stage==1 and not game.match_mode.fortress.buildings.has(100100)),"Client observes shock-destroyed compressor")
			observation.report.rpc_id(1,"objective")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="VARIANT_DONE")),"Session finishes without replication failure")
	finish_test(rule)
func finish_test(rule: String) -> void:
	print("VARIANT_NETWORK_RESULT ",JSON.stringify({"rule":rule,"role":role,"failures":failures,"passed":failures.is_empty()}))
	game.disconnect_game("Test completed");await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
