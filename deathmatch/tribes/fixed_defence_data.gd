extends RefCounted
## Pinned community base scripts; original engine timing/heat are approximated.
const UNIT:=100.0/.66
const TYPES={
	"fusion":{"name":"FUSION TURRET","hp":1.0,"energy":200.0,"minimum":75.0,"cost":6.0,"recharge":10.0,"range":100.0,"cycle":.8,"speed":50.0,"damage":.25,"weapon":0,"turn":2.0},
	"mini":{"name":"MINI-FUSION TURRET","hp":2.5,"energy":60.0,"minimum":20.0,"cost":6.0,"recharge":10.0,"range":25.0,"cycle":.4,"speed":80.0,"damage":.1,"weapon":0,"turn":5.0},
	"elf":{"name":"ELF TURRET","hp":1.0,"energy":150.0,"minimum":50.0,"cost":3.0,"recharge":10.0,"range":40.0,"cycle":.1,"speed":0.0,"damage":.006,"weapon":6,"turn":5.0},
	"missile":{"name":"MISSILE TURRET","hp":.75,"energy":100.0,"minimum":60.0,"cost":60.0,"recharge":14.0,"range":150.0,"cycle":.5,"speed":72.0,"damage":.5,"weapon":3,"turn":2.0},
	"mortar":{"name":"MORTAR TURRET","hp":1.0,"energy":45.0,"minimum":45.0,"cost":45.0,"recharge":10.0,"range":0.0,"cycle":2.0,"speed":sqrt(400.0*20),"damage":1.32,"weapon":7,"turn":2.0}
}
static func hp(kind: String) -> float:return TYPES[kind].hp*UNIT
static func size(kind: String) -> Vector3:return Vector3(2.1,1.6,2.1) if kind=="mini" else Vector3(3.2,2.8,3.2)
static func projectile(kind: String,team: int,target: int=0) -> Dictionary:
	var t: Dictionary=TYPES[kind];var d: Dictionary=preload("res://deathmatch/tribes/arsenal.gd").table()[t.weapon].duplicate()
	d.merge({"name":t.name,"speed":t.speed,"damage":roundi(t.damage*UNIT),"splash":0,"turret_team":team,"fixed_turret":kind,"inherit":0.0,"fuse":6.0},true)
	if kind=="missile":d.merge({"splash":d.damage,"blast_radius":9.5,"kick":175.0,"seek":target,"fuse":10.0,"acceleration":0.0,"radius":.1},true)
	if kind=="mortar":d.merge({"splash":d.damage,"blast_radius":30.0,"kick":250.0,"fuse":30.0,"arm":2.0},true)
	return d
