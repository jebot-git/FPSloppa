extends RefCounted
## XP is earned separately for each class; equipment choices apply on the next spawn.
const STARTERS={"shocktroop":[4],"scout":[9],"medic":[3],"technician":[5]}
const SECOND_PRIMARY={"shocktroop":1,"scout":10,"medic":12,"technician":11}
const THIRD_PRIMARY={"shocktroop":14,"scout":16,"medic":13,"technician":15}
const TERTIARY_XP:=5000
const XP_PER_LEVEL:=500
const PRIMARY_LEVEL:=5
const SECONDARY_LEVEL:=10
const UTILITY_LEVEL:=15
const UTILITY_XP:=UTILITY_LEVEL*XP_PER_LEVEL
const PRIMARY_XP:=PRIMARY_LEVEL*XP_PER_LEVEL
const SECONDARY_XP:=SECONDARY_LEVEL*XP_PER_LEVEL
var tracks:Dictionary={}
var secondaries:Dictionary={}
func _init() -> void:
	for role in STARTERS:
		tracks[role]=[{"weapon":STARTERS[role][0],"xp":0,"tier":1},{"weapon":SECOND_PRIMARY[role],"xp":PRIMARY_XP,"tier":2},{"weapon":THIRD_PRIMARY[role],"xp":TERTIARY_XP,"tier":3}]
		secondaries[role]=[{"weapon":8 if role=="scout" else 2,"xp":0},{"weapon":0,"xp":SECONDARY_XP}]
func register_weapon(role:String,weapon:int,experience:int) -> bool:
	if not tracks.has(role) or weapon<0 or experience<0 or tracks[role].any(func(row):return row.weapon==weapon):return false
	tracks[role].append({"weapon":weapon,"xp":experience});tracks[role].sort_custom(func(a,b):return a.xp<b.xp);return true
func unlocked(role:String,experience:int,secondary:bool=false) -> Array:
	return (secondaries if secondary else tracks).get(role,[]).filter(func(row):return row.xp<=experience).map(func(row):return row.weapon)

static func level(experience:int) -> int:return maxi(0,experience)/XP_PER_LEVEL
