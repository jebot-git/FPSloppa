extends "res://deathmatch/bots.gd"
var diagnostic_enabled:=false
var diagnostic_goal:=Vector3.ZERO
func mode_goals(id:int,brain:Dictionary,rows:Array)->void:
	if diagnostic_enabled:candidate(rows,"diagnostic","objective",diagnostic_goal,160)
	else:super.mode_goals(id,brain,rows)
func plan(id:int,brain:Dictionary)->void:
	if not diagnostic_enabled:super.plan(id,brain);return
	var spawns:Array=game.spawn_points;var supplies:Array=game.pickups
	game.spawn_points=[];game.pickups=[]
	super.plan(id,brain)
	game.spawn_points=spawns;game.pickups=supplies
