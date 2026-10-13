extends RefCounted
## Class-specific progression registry. Future weapons are added with explicit XP requirements.
const STARTERS={"shocktroop":[4],"scout":[9],"medic":[4],"technician":[5]}
var tracks:Dictionary={}
func _init() -> void:
	for role in STARTERS:tracks[role]=STARTERS[role].map(func(weapon):return {"weapon":weapon,"xp":0})
func register_weapon(role:String,weapon:int,experience:int) -> bool:
	if not tracks.has(role) or weapon<0 or experience<0 or tracks[role].any(func(row):return row.weapon==weapon):return false
	tracks[role].append({"weapon":weapon,"xp":experience});tracks[role].sort_custom(func(a,b):return a.xp<b.xp);return true
func unlocked(role:String,experience:int) -> Array:
	return tracks.get(role,[]).filter(func(row):return row.xp<=experience).map(func(row):return row.weapon)
