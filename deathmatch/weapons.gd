extends RefCounted

# Independent implementation of Doom-like weapon rules; units are meters/seconds.
# Keys: fist, saw, pistol, shotgun, super shotgun, chaingun, rocket, plasma, BFG.
const DATA = [
	{"name":"FIST", "ammo":-1, "cost":0, "cycle":0.57, "pellets":1, "spread":5.6, "vertical":0.0, "range":2.88, "damage":2, "dice":10},
	{"name":"CHAINSAW", "ammo":-1, "cost":0, "cycle":0.114, "pellets":1, "spread":5.6, "vertical":0.0, "range":2.92, "damage":2, "dice":10},
	{"name":"DUAL PISTOLS", "ammo":0, "cost":1, "cycle":0.4, "pellets":1, "spread":4.2, "vertical":0.0, "range":100.0, "damage":6, "dice":3},
	{"name":"SHOTGUN", "ammo":1, "cost":1, "cycle":1.0, "pellets":7, "spread":5.6, "vertical":0.0, "range":100.0, "damage":5, "dice":3},
	{"name":"SUPER SHOTGUN", "ammo":1, "cost":2, "cycle":1.63, "pellets":20, "spread":11.2, "vertical":7.1, "range":100.0, "damage":5, "dice":3},
	{"name":"CHAINGUN", "ammo":0, "cost":1, "cycle":0.114, "pellets":1, "spread":5.6, "vertical":0.0, "range":100.0, "damage":5, "dice":3},
	{"name":"ROCKET LAUNCHER", "ammo":2, "cost":1, "cycle":0.57, "speed":31.5, "radius":0.14, "damage":20, "dice":8},
	{"name":"PLASMA RIFLE", "ammo":3, "cost":1, "cycle":0.086, "speed":39.4, "radius":0.16, "damage":5, "dice":8},
	{"name":"BFG 9000", "ammo":3, "cost":40, "cycle":1.72, "charge":0.86, "speed":39.4, "radius":0.30, "damage":100, "dice":8},
	{"name":"RAILGUN","ammo":-1,"cost":0,"cycle":1.5,"pellets":1,"spread":0.0,"vertical":0.0,"range":200.0,"damage":10000,"dice":1}
]
const MAX_AMMO = [200,50,50,300]
const AMMO_NAMES = ["BULLETS","SHELLS","ROCKETS","CELLS"]
const COLORS = [Color("b99170"),Color("ebae42"),Color("d4cfc4"),Color("d29c55"),Color("eac06e"),Color("e4bb56"),Color("ff7849"),Color("69ccff"),Color("92f56b"),Color("67edff")]

static func can_fire(weapon: int, ammo: Array) -> bool:
	if weapon < 0 or weapon >= DATA.size(): return false
	var d: Dictionary = DATA[weapon]
	return d.ammo < 0 or ammo[d.ammo] >= d.cost

static func armor_damage(damage: int, armor: int, tier: int) -> Vector2i:
	var saved := mini(armor, int(damage / (2.0 if tier == 2 else 3.0)))
	return Vector2i(damage-saved, armor-saved)

static func direction(yaw: float, pitch: float) -> Vector3:
	return Basis(Vector3.UP,yaw) * Basis(Vector3.RIGHT,pitch) * Vector3.FORWARD

static func next_owned(current: int, step: int, owned: Array) -> int:
	for i in range(1,DATA.size()+1):
		var w := posmod(current+i*step,DATA.size())
		if owned.has(w): return w
	return current
