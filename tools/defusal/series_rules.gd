extends "res://deathmatch/modes/defusal.gd"
## Six-round test format only. Production combat, economy and round outcomes
## remain unchanged; reuse the normal halftime reset before round four.
func begin_round():
	var saved:=win_limit
	if round_id==3:win_limit=4
	super.begin_round()
	win_limit=saved
func tick(delta: float):
	if enabled() and game.multiplayer.is_server() and phase=="post" and round_id==6 and game.clock>=phase_end:
		phase="finished";game._end_round();return
	super.tick(delta)
