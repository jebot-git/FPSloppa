extends RefCounted
const Arsenal=preload("res://deathmatch/tribes/arsenal.gd")
const LENGTHS=[.48,.68,.78,.68,.72,1.12,.69,1.02,.6,.1,.1,.46]
static var scenes: Dictionary={}
static func muzzle(w: int) -> Vector3:return Vector3(0,.24 if w==7 else .17,-LENGTHS[clampi(w,0,11)])
static func model(key: String) -> Node3D:
	if not scenes.has(key):scenes[key]=load("res://deathmatch/weapons/tribes/"+key+".scn")
	return scenes[key].instantiate()
static func make(w: int) -> Node3D:
	var node:=model(Arsenal.MODELS[clampi(w,0,11)]);node.name="WeaponModel";node.set_meta("muzzle",muzzle(w));node.set_meta("tribes",true)
	if w==5:
		node.set_meta("scope_rear",Vector3(0,.33,.032));node.set_meta("scope_front",Vector3(0,.33,-.33));node.set_meta("scope_radius",.032)
	return node
