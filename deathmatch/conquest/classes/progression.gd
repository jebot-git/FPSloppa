extends RefCounted
## XP is earned separately for each class; equipment choices apply on the next spawn.
const STARTERS={"shocktroop":[4],"scout":[9],"medic":[4],"technician":[5]}
const SECOND_PRIMARY={"shocktroop":1,"scout":10,"medic":3,"technician":11}
const PRIMARY_XP:=1000
const SECONDARY_XP:=1500
var tracks:Dictionary={}
var secondaries:Dictionary={}
func _init() -> void:
	for role in STARTERS:
		tracks[role]=[{"weapon":STARTERS[role][0],"xp":0},{"weapon":SECOND_PRIMARY[role],"xp":PRIMARY_XP}]
		secondaries[role]=[{"weapon":8 if role=="scout" else 2,"xp":0},{"weapon":0,"xp":SECONDARY_XP}]
func register_weapon(role:String,weapon:int,experience:int) -> bool:
	if not tracks.has(role) or weapon<0 or experience<0 or tracks[role].any(func(row):return row.weapon==weapon):return false
	tracks[role].append({"weapon":weapon,"xp":experience});tracks[role].sort_custom(func(a,b):return a.xp<b.xp);return true
func unlocked(role:String,experience:int,secondary:bool=false) -> Array:
	return (secondaries if secondary else tracks).get(role,[]).filter(func(row):return row.xp<=experience).map(func(row):return row.weapon)
