extends "res://deathmatch/bots.gd"
func mode_goals(_id: int,_brain: Dictionary,rows: Array) -> void:
	for index in range(1,8):candidate(rows,str(index),"roam",Vector3(index,0,0),100-index)
func cover_goals(_id: int,_brain: Dictionary,_rows: Array) -> void:pass
