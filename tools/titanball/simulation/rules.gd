extends "res://deathmatch/experimental/weapon_rules.gd"
## Test-only profile override. Production TB still requires TF/Quake.
func select(value: String,remember: bool=true) -> bool:
 var arena=game
 game=null
 var result:=super.select(value,remember)
 game=arena
 return result
func spawn_loadout(state: Dictionary) -> void:
 state.owned=[0,2];state.weapon=2;state.ammo=[50,0,0,0]
func pickup_bundle(_index: int) -> Array:return []
