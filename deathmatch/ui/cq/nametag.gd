extends Label3D
## CQ names have one neutral colour and no user-defined colour runs.
const Names=preload("res://deathmatch/ui/name_style.gd")
func set_player_name(nickname:String,team:int,_color:Color)->void:
	text=("◆ " if team==0 else "● " if team==1 else "")+Names.plain(nickname)
	modulate=Color("dceff0")
