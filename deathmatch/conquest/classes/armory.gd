extends "res://deathmatch/experimental/weapon_rules.gd"
# New progression weapons will be registered when their source assets are supplied.
const STARTERS={"shocktroop":[4,2],"scout":[9,8],"medic":[4,2,6,7],"technician":[5,2,6,7]}
func select(_value:String,remember:bool=true) -> bool:
	kind="ut99";preferred="ut99";table.clear()
	for i in SLOT_COUNT:set_weapon(i,"TOOL",-1,0,.2,0,{"kind":"hitscan"})
	set_weapon(2,"DOBRYL P-1",0,1,.35,25,{"range":100.0,"magazine":7,"reload":2.2})
	set_weapon(4,"LASER CARBINE",1,1,.12,18,{"range":160.0,"kind":"pulse","speed":70.0,"radius":.035,"magazine":30,"reload":2.2})
	set_weapon(5,"MASSACRE GUN",2,1,1.0,100,{"kind":"rocket","speed":25.0,"gravity":12.0,"splash":120,"blast_radius":5.0,"direct_random":20,"quake_rocket":true,"fuse":10.0,"magazine":3,"reload":2.7})
	set_weapon(6,"SUPPLY DISPENSER",-1,0,.2,0,{"range":2.5})
	set_weapon(7,"SPECIALIST TOOL",-1,0,.2,0,{"range":1.5})
	set_weapon(8,"TARGET DESIGNATOR",-1,0,.1,0,{"range":200.0})
	set_weapon(9,"SCOUT DOBRYL P-1",0,1,.6,40,{"kind":"sniper","head_damage":100,"range":200.0,"scope":true,"magazine":7,"reload":2.2,"alt":{"zoom":true}})
	return true
func spawn_loadout(state:Dictionary) -> void:
	var role:String=game.classes.role(int(state.id)) if state.has("id") else state.get("cq_class","shocktroop")
	state.owned=STARTERS[role].duplicate();state.weapon=state.owned[0];state.ammo=[42,0,0,0] if role=="scout" else [14,0,9,0] if role=="technician" else [14,120,0,0]
func max_ammo() -> Array:return [42,120,9,0]
func ammo_names() -> Array:return ["PISTOL ROUNDS","CARBINE ROUNDS","","" ]
func valid(index:int) -> bool:return index in [2,4,5,6,7,8,9]
func vr_physical_only(_index:int) -> bool:return false
func pickup_bundle(_index:int) -> Array:return []
