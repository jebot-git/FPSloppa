extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
func _initialize():run.call_deferred()
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Reaction timing",0,100,60,true,"dm","doom");game.set_physics_process(false);game.set_process(false);Fixture.setup(game)
	for id in [-2,-3]:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(18,18)
	var s:Dictionary=game.players[-1];var target:Dictionary=game.players[1];var rows:Array=[];var failures:Array=[]
	for angle in [0.,-75.]:
		for phase in 12:
			for trial in 10:
				seed(1900+trial);game.clock=0
				s.merge({"owned":[9],"weapon":9,"yaw":0.,"pitch":0.,"dead":false,"cooldown":0.,"input_blocked":false},true)
				game.fighters[-1].position=Fixture.point();game.fighters[-1].velocity=Vector3.ZERO
				game.fighters[1].position=Fixture.point(20*sin(deg_to_rad(angle)),-20*cos(deg_to_rad(angle)));game.fighters[1].velocity=Vector3.ZERO
				target.hp=100000;target.dead=false;target.invulnerable=0;target.armor=0;target.spectator=true
				var brain:Dictionary=game.bots.new_brain(-1);var shots:int=s.shots;var fired:=-1.
				for tick in 90:
					target.spectator=tick<phase
					await physics_frame;game.clock=tick/60.
					if tick%12==0:game.bots.perceive(-1,brain)
					game.bots.combat(-1,brain,1./60.)
					if s.fire:game._fire(-1)
					if s.shots>shots:fired=game.clock-phase/60.;break
				rows.append({"angle":angle,"phase":phase,"seed":trial,"reaction_ms":brain.reaction*1000,"first_shot_ms":fired*1000})
				if fired<.28 or fired>1.:failures.append(rows.back())
	FileAccess.open("res://test-results/bot-accuracy/reaction.json",FileAccess.WRITE).store_string(JSON.stringify({"trials":rows,"failures":failures},"  "))
	game.disconnect_game();game.free();await process_frame
	print("BOT_REACTION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
