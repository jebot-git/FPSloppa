extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var options:Dictionary=JSON.parse_string(OS.get_cmdline_user_args()[0])
	seed(9127)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Aim comparison",0,100,60,true,"dm","doom");game.set_physics_process(false);game.set_process(false)
	Fixture.box(game,Fixture.ORIGIN+Vector3(0,-.5,0),Vector3(140,1,140))
	for id in [-2,-3]:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(60,60)
	if options.has("ai_script"):
		game.bots.free();game.bots=load(options.ai_script).new();game.add_child(game.bots);game.bots.setup(game)
	var s:Dictionary=game.players[-1];var actor=game.fighters[-1];var target=game.fighters[1]
	var rows:Array=[]
	for distance in [5.,20.,40.]:
		for moving in [false,true]:
			for trial in 8:
				seed(1000+trial);game.clock=0
				s.merge({"owned":[9],"weapon":9,"dead":false,"spectator":false,"input_blocked":false,"yaw":0.,"pitch":0.,"ammo":[100,100,100,100]},true)
				actor.position=Fixture.point();actor.velocity=Vector3.ZERO
				var brain:Dictionary=game.bots.new_brain(-1)
				var hits:=0;var shots:=0;var windows:Array=[];var window_hits:=0;var window_shots:=0;var maximum_step:=0.
				for tick in 840:
					var t:float=tick/60.
					target.position=Fixture.point(2.5*sin(t*2.6) if moving else 0.,-distance)
					target.velocity=Vector3(6.5*cos(t*2.6),0,0) if moving else Vector3.ZERO
					await physics_frame;game.clock=t
					if tick%12==0:game.bots.perceive(-1,brain)
					var before:float=s.yaw;game.bots.combat(-1,brain,1./60.)
					maximum_step=maxf(maximum_step,absf(angle_difference(before,s.yaw)))
					if tick>=120 and tick%6==0 and s.fire:
						var origin:Vector3=game._shot_solution(-1).origin
						var hit:Dictionary=game._trace(origin,origin+game.W.direction(s.yaw,s.pitch)*100,-1,0.)
						shots+=1;window_shots+=1
						if hit.id==1:hits+=1;window_hits+=1
					if tick>=120 and tick%120==119:
						windows.append(float(window_hits)/maxi(1,window_shots));window_hits=0;window_shots=0
				rows.append({"distance_m":distance,"moving":moving,"seed":1000+trial,"hits":hits,"samples":shots,"coverage":float(hits)/maxi(1,shots),"windows":windows,"max_yaw_step":maximum_step})
			print("BOT_ACCURACY_PROGRESS ",distance," moving=",moving)
	if options.get("expect_variation",false):
		# Even the close, rapidly strafing target gets a firing opportunity in
		# more than half the probes; bots must not simply give up to miss more.
		check(rows.all(func(row):return row.samples>60 and row.max_yaw_step<.15),"Bots keep engaging and turn smoothly in every aiming trial")
		var close:Array=rows.filter(func(row):return row.distance_m==5 and not row.moving)
		check(close.all(func(row):return row.coverage>.9),"Nearby stationary opponents remain easy targets")
		var distant:Array=rows.filter(func(row):return row.distance_m==40 and not row.moving)
		var average:=0.;var lowest:=1.;var highest:=0.;var fluctuating:=0
		for row in distant:
			average+=row.coverage/distant.size();lowest=minf(lowest,row.coverage);highest=maxf(highest,row.coverage)
			if float(row.windows.max())-float(row.windows.min())>.25:fluctuating+=1
		check(average>.25 and average<.85,"Distant aim allows mistakes without making bots ineffective")
		check(highest-lowest>.1 and fluctuating>=6,"Precision differs between bots and fluctuates within engagements")
	FileAccess.open(options.output,FileAccess.WRITE).store_string(JSON.stringify({"metric":"Zero-spread firing-line capsule coverage; not full-match weapon hit rate","trials":rows,"failures":failures},"  "))
	game.disconnect_game();game.free();await process_frame
	print("BOT_ACCURACY_RESULT ",options.output);quit(0 if failures.is_empty() else 1)
