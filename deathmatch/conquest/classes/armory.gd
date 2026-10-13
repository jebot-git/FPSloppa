extends "res://deathmatch/experimental/weapon_rules.gd"
# Slot IDs remain within the existing twelve-slot network protocol.
const STARTERS={"shocktroop":[4,2],"scout":[9,8],"medic":[4,2,6,7],"technician":[5,2,6,7]}
func select(_value:String,remember:bool=true) -> bool:
	kind="ut99";preferred="ut99";table.clear()
	for i in SLOT_COUNT:set_weapon(i,"TOOL",-1,0,.2,0,{"kind":"hitscan"})
	set_weapon(2,"FIELD PISTOL",0,1,.35,25,{"range":100.0,"magazine":7,"reload":2.2})
	set_weapon(4,"LASER CARBINE",1,1,.12,18,{"range":160.0,"fuse":160.0/70.0,"kind":"pulse","speed":70.0,"radius":.035,"magazine":30,"reload":2.2})
	set_weapon(5,"MASSACRE GUN",2,1,1.0,100,{"kind":"rocket","speed":25.0,"gravity":12.0,"splash":120,"blast_radius":5.0,"direct_random":20,"quake_rocket":true,"fuse":10.0,"magazine":3,"reload":2.7})
	set_weapon(6,"SUPPLY DISPENSER",-1,0,.2,0,{"range":2.5})
	set_weapon(7,"SPECIALIST TOOL",-1,0,.2,0,{"range":1.5})
	set_weapon(8,"TARGET DESIGNATOR",-1,0,.1,0,{"range":200.0})
	set_weapon(9,"SCOUT SCOPED PISTOL",0,1,.6,40,{"kind":"sniper","head_damage":100,"range":200.0,"scope":true,"magazine":7,"reload":2.2,"alt":{"zoom":true}})
	set_weapon(3,"MEDIC SMG",1,1,.06,12,{"kind":"nail","speed":150.0,"radius":.015,"range":60.0,"fuse":.4,"spread":1.8,"vertical":1.8,"magazine":40,"reload":2.2})
	set_weapon(10,"SCOUT BEAM PISTOL",1,1,.8,55,{"kind":"sniper","head_damage":110,"range":250.0,"scope":true,"magazine":10,"reload":2.2,"cq_beam":true,"alt":{"zoom":true}})
	set_weapon(1,"ENERGY ASSAULT RIFLE",1,1,.075,16,{"range":180.0,"fuse":2.0,"kind":"pulse","speed":90.0,"radius":.035,"spread":.6,"vertical":.6,"scope":true,"magazine":36,"reload":2.2,"alt":{"zoom":true}})
	set_weapon(11,"GUIDED ENERGY LAUNCHER",2,1,1.0,100,{"kind":"rocket","speed":40.0,"gravity":0.0,"splash":120,"blast_radius":5.0,"quake_rocket":true,"fuse":10.0,"magazine":1,"reload":2.7})
	set_weapon(0,"BURST ENERGY PISTOL",3,1,.36,14,{"range":90.0,"fuse":1.2,"kind":"pulse","speed":75.0,"radius":.025,"magazine":18,"reload":2.2,"burst":3})
	return true
func spawn_loadout(state:Dictionary) -> void:
	var role:String=game.classes.role(int(state.id)) if state.has("id") else state.get("cq_class","shocktroop")
	var id:int=int(state.get("cq_id",0))
	state.owned=STARTERS[role].duplicate()
	state.owned[0]=game.classes.equipment(id)
	state.owned[1]=game.classes.equipment(id,true)
	state.weapon=state.owned[0];state.ammo=loadout_capacity(state)
func loadout_capacity(state:Dictionary) -> Array:
	var result:Array=[0,0,0,0]
	for index in state.get("owned",[]):
		var d:Dictionary=data(index)
		if d.ammo<0:continue
		var spare:int=2 if index in [5,11] else 5 if index==9 else 1 if index in [2,0] else 3
		result[d.ammo]+=int(d.magazine)*(spare+1)
	return result
func max_ammo() -> Array:return [42,160,9,36]
func ammo_names() -> Array:return ["PISTOL ROUNDS","PRIMARY AMMO / CELLS","ORDNANCE","SECONDARY CELLS"]
func valid(index:int) -> bool:return index>=0 and index<SLOT_COUNT
func vr_physical_only(_index:int) -> bool:return false
func pickup_bundle(_index:int) -> Array:return []
