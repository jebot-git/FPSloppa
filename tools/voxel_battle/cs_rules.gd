extends "res://deathmatch/experimental/weapon_rules.gd"
## Scenario-local CS-style balance, rendered with the bundled generic weapon art.
## No economy or bomb rules: a fixed rifle/pistol/knife loadout respawns in TDM.
func select(_value: String,remember: bool=true) -> bool:
	if remember:preferred="cs"
	kind="cs";table=Doom.DATA.duplicate(true)
	set_weapon(0,"KNIFE",-1,0,.45,35,{"range":1.7})
	set_weapon(2,"DESERT EAGLE",1,1,.25,34,{"range":100.0,"spread":.55,"vertical":.55})
	set_weapon(4,"M4A1",0,1,.09,25,{"range":140.0,"spread":.7,"vertical":.7})
	set_weapon(5,"AK-47",0,1,.1,30,{"range":140.0,"spread":.9,"vertical":.9})
	set_weapon(9,"AWP",2,1,1.45,100,{"kind":"sniper","range":220.0,"head_damage":150,"spread":.08,"vertical":.08,"scope":true})
	return true
func valid(index: int) -> bool:return index in [0,2,4,5,9]
func color(_index: int) -> Color:return Color(.75,.74,.63)
func ammo_names() -> Array:return ["RIFLE","PISTOL","SNIPER",""]
func max_ammo() -> Array:return [30,7,10,0]
func spawn_loadout(state: Dictionary) -> void:
	var primary:=5 if state.team==0 else 4
	state.owned=[0,2,primary];state.weapon=primary;state.ammo=[30,7,0,0]
	state.cs_reserve=[120,35,0,0];state.cs_reload_until=0.0;state.cs_reload_ammo=-1
	state.armor=100;state.tier=1
