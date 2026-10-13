extends "res://tools/vrm_to_mdl/no_ai_arena.gd"
## Local 64-slot experiment only; production multiplayer limits are unchanged.
func network_player_limit() -> int:return max_clients
func start_host(player_name:String,port:int,frags:int,minutes:int,training:bool,mode:String="dm",weapon_rules:String="doom") -> void:
	var requested:=max_clients
	super.start_host(player_name,port,frags,minutes,training,mode,weapon_rules)
	if requested>max_clients:
		max_clients=requested
		bot_population.maintain()
