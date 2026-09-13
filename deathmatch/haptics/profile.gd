extends RefCounted
## Game-authored profile, shared by native BLE, OSC fallback and the hardware simulation.
const PATH="res://deathmatch/haptics/fpsloppa_vest.json"
var data: Dictionary={}
func _init() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("schema")==1:data=parsed
func family(weapon: String) -> String:
	for key in data.get("weapon_families",{}):
		if weapon.to_upper() in data.weapon_families[key]:return key
	return "pistol"
func recoil(weapon: String) -> String:
	return "" if weapon=="TRANSLOCATOR" else "recoil_"+family(weapon)
func damage(weapon: String,blast: bool=false) -> String:
	if blast:return "hit_blast"
	match weapon.to_upper():
		"LAVA","BURN","NAPALM":return "environment_fire"
		"SLIME","ACID":return "environment_acid"
		"DROWNING":return "environment_drowning"
		"FELL OUT OF THE ARENA","FALL":return "environment_fall"
		"ENVIRONMENT":return "environment_generic"
	match family(weapon):
		"shotgun","heavy_shotgun":return "hit_shotgun"
		"energy","heavy_energy":return "hit_energy"
		"rocket":return "hit_blast"
		"sniper":return "hit_sniper"
		"melee","saw":return "hit_melee"
	return "hit_bullet"
func sequence(effect: String,target: Array,scale: float=1.0) -> Array:
	var result: Array=[]
	if not is_finite(scale):return result
	var wide:=target.duplicate()
	for index in target:
		for neighbor in [int(index)-1,int(index)+1]:
			if neighbor>=0 and neighbor<40 and neighbor/4==int(index)/4 and not wide.has(neighbor):wide.append(neighbor)
	for step in data.get("effects",{}).get(effect,[]):
		var motors: Array=target if step.zone=="target" else wide if step.zone=="target_wide" else data.groups.get(step.zone,[])
		result.append({"delay":step.delay,"duration":step.duration,"level":clampi(roundi(float(step.level)*clampf(scale,0,1)),0,15),"motors":motors})
	return result
static func hit_zone(direction: Vector3,basis: Basis,impact: Vector3=Vector3.INF,feet: Vector3=Vector3.ZERO,height: float=1.65) -> Array:
	if not basis.is_finite() or absf(basis.determinant())<.01:return [5,6,25,26]
	var source:=basis.inverse()*-direction if direction.is_finite() else Vector3.ZERO
	var row:=2
	var column:=1
	if impact.is_finite() and feet.is_finite() and is_finite(height) and height>.1:
		var local:=basis.inverse()*(impact-feet)
		var fraction:=clampf(local.y/height,0,1)
		row=0 if fraction>=.88 else 1 if fraction>=.70 else 2 if fraction>=.45 else 3 if fraction>=.25 else 4
		column=0 if local.x<-.15 else 3 if local.x>.15 else 1
	if absf(source.x)>absf(source.z):
		return [row*4,20+row*4+3] if source.x<0 else [row*4+3,20+row*4]
	if Vector2(source.x,source.z).length()<.1:return [row*4+1,row*4+2,20+row*4+1,20+row*4+2]
	var offset:=20 if source.z>0 else 0
	# Back is viewed from outside, so its columns reverse the wearer's left/right.
	if offset==20 and column in [0,3]:column=3-column
	return [offset+row*4+1,offset+row*4+2] if column==1 else [offset+row*4+column]
