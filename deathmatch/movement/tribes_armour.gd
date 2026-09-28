extends RefCounted
## Tribes 1 base class ratios; health is normalized to the existing 100 HP light.
## Provenance and test-loadout adaptations: docs/TRIBES-MOVEMENT.md.
const CLASSES={
	"light":{"name":"LIGHT · PELTAST","hp":100,"energy":60.0,"mass":9.0,"walk":11.0,"accel":40.0,"thrust":236.0/9.0,"jump":75.0/9.0,"side_speed":22.0,"drain":25.0,"cost":175,"guns":3,"bullet":1.2,"grenade":1.2,"rocket":1.0},
	"medium":{"name":"MEDIUM · HOPLITE","hp":152,"energy":80.0,"mass":13.0,"walk":8.0,"accel":35.0,"thrust":320.0/13.0,"jump":110.0/13.0,"side_speed":17.0,"drain":31.25,"cost":250,"guns":4,"bullet":1.0,"grenade":1.0,"rocket":1.0},
	"heavy":{"name":"HEAVY · MYRMIDON","hp":200,"energy":110.0,"mass":18.0,"walk":5.0,"accel":35.0,"thrust":385.0/18.0,"jump":150.0/18.0,"side_speed":12.0,"drain":34.375,"cost":400,"guns":5,"bullet":.6,"grenade":.8,"rocket":.6}
}
static func definition(key: String) -> Dictionary:return CLASSES.get(key,CLASSES.light)
static func damage_scale(key: String,weapon: String) -> float:
	var data:=definition(key)
	if weapon in ["SHOTGUN","SUPER SHOTGUN","NAILGUN","SUPER NAILGUN"]:return data.bullet
	if weapon=="GRENADE LAUNCHER":return data.grenade
	if weapon=="ROCKET LAUNCHER":return data.rocket
	return 1.0
