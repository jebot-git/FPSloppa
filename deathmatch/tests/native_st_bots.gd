extends "res://deathmatch/tests/native_bots.gd"
## ST energy preservation must also run between native weapon selection ticks.
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Native ST parity",0,100,60,true,"st");game.set_process(false);game.set_physics_process(false);bots=game.bots
	check(bots.native_ai!=null,"Native bot extension loaded")
	if bots.native_ai==null:quit(1);return
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200))
	while not bots.navigation.ready():await physics_frame
	for id in game.players:
		game.players[id].team=0 if id==-1 else 1;game.players[id].dead=id not in [-1,-2];game.players[id].invulnerable=0
		game.fighters[id].position=Fixture.ORIGIN+Vector3(0,0,0 if id==-1 else -8 if id==-2 else -30);game.fighters[id].velocity=Vector3.ZERO
	var cases:=0
	for armour in ["light","medium","heavy"]:
		game.match_mode.tribes.apply_equipment(-1,armour,[0,1,3],"energy")
		var actor=game.fighters[-1]
		for carrier in [false,true]:
			game.match_mode.flags[1].carrier=-1 if carrier else 0
			for energy in [8.0,25.0,60.0]:
				for weapon in [0,1,3]:
					cases+=1;game.clock=20+cases;actor.tribes_state.energy=energy
					game.players[-1].weapon=weapon;game.players[-1].yaw=0;game.players[-1].pitch=0;game.players[-1].hp=90
					var brain: Dictionary=bots.new_brain(-1);brain.role="capper";brain.goal=Fixture.ORIGIN+Vector3(0,0,-150);brain.goal_kind="capture";brain.goal_key="st:capture" if carrier else "st:flag";brain.capture_preparing=not carrier
					brain.enemy=-2;brain.visible=[-2];brain.last_seen_at=game.clock;brain.seen_at=game.clock-1;brain.seen_position=bots.target_position(-2);brain.weapon_at=INF;brain.action_at=INF;brain.disc_jump_at=INF;brain.reaction=0
					var original: Dictionary=game.players.duplicate(true);var team:=team_snapshot();var ref:=clone_brain(brain);var native:=clone_brain(brain)
					seed(16000+cases);bots.combat_reference(-1,ref,.2)
					var expected: Dictionary=game.players.duplicate(true);var ref_team:=team_snapshot();var random:=randi()
					game.players=original.duplicate(true);restore_team(team);seed(16000+cases);bots.native_ai.combat(bots,-1,native,.2)
					var label:="%s carry=%s energy=%s weapon=%s"%[armour,carrier,energy,weapon]
					compare(ref,native,label+" brain");compare(expected,game.players,label+" players");compare(ref_team,team_snapshot(),label+" team");check(random==randi(),label+" RNG")
					if not bots.tribes.offense.carrier_weapon(-1,weapon):check(not game.players[-1].fire,label+" reserves jet energy")
					game.players=original;restore_team(team)
	game.disconnect_game();game.free()
	print("NATIVE_ST_BOTS_RESULT ",JSON.stringify({"checks":checks,"cases":cases,"failures":failures}));quit(0 if failures.is_empty() else 1)
