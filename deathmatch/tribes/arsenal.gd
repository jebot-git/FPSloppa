extends RefCounted
## Tribes 1 base scripts, normalized so light armour condition is 100 (.66 original).
const UNIT:=100.0/.66
const NAMES=["BLASTER","PLASMA GUN","CHAINGUN","DISC LAUNCHER","GRENADE LAUNCHER","LASER RIFLE","ELF GUN","MORTAR","REPAIR GUN","HAND GRENADE","LAND MINE","TARGETING LASER"]
const MODELS=["blaster","plasma","chaingun","disc","grenade_launcher","laser","elf","mortar","repair","grenade","mine","targeter"]
const PACKS={"energy":{"name":"ENERGY PACK","cost":150},"ammo":{"name":"AMMO PACK","cost":325},"repair":{"name":"REPAIR PACK","cost":125},"shield":{"name":"SHIELD PACK","cost":175},"jammer":{"name":"SENSOR JAMMER","cost":200},"none":{"name":"NO BACKPACK","cost":0},"turret":{"name":"REMOTE TURRET","cost":350},"inventory":{"name":"REMOTE INVENTORY","cost":3200},"ammo_station":{"name":"REMOTE AMMO","cost":2500},"pulse":{"name":"PULSE SENSOR","cost":125},"motion":{"name":"MOTION SENSOR","cost":125},"remote_jammer":{"name":"REMOTE JAMMER","cost":225},"camera":{"name":"REMOTE CAMERA","cost":100}}
const PRICES=[85,175,125,150,150,200,125,375]
const CAPS={"light":[0,30,100,15,10,0,0,0,0,5,3,0],"medium":[0,40,150,15,10,0,0,0,0,6,3,0],"heavy":[0,50,200,15,15,0,0,10,0,8,3,0]}
const BONUS=[0,30,150,15,15,0,0,10,0,10,5,0]
const AMMO_PRICE=[0,2,1,2,2,0,0,5,0,5,10,0]
const TYPES=["Blaster","Plasma","Chaingun","Disc","Grenade","Laser","ELF","Mortar","Repair","Grenade","Mine","Target"]
const RESISTS={"light":[1.3,1,1.2,1,1.2,1,1,1.3,1,1.2,1.2,1],"medium":[1,.6,1,1,1,1,1,1,1,1,1,1],"heavy":[.7,.4,.6,.6,.8,.6,1,.7,1,.8,.8,1]}
static func allowed(armour: String,w: int,pack: String="energy") -> bool:
	return w>=0 and w<8 and (w!=5 or armour=="light" and pack=="energy") and (w!=7 or armour=="heavy")
static func capacity(armour: String,pack: String,w: int) -> int:
	return int(CAPS.get(armour,CAPS.light)[w])+(int(BONUS[w]) if pack=="ammo" else 0)
static func defaults(armour: String) -> Array:return [3,2,4,1,7] if armour=="heavy" else [3,2,4,1] if armour=="medium" else [3,2,4]
static func valid_loadout(armour: String,weapons: Variant,pack: String) -> bool:
	if not preload("res://deathmatch/tribes/deployable_data.gd").allowed(armour,pack) or not CAPS.has(armour) or not PACKS.has(pack) or not weapons is Array or weapons.is_empty() or weapons.size()>preload("res://deathmatch/movement/tribes_armour.gd").definition(armour).guns:return false
	var seen: Array=[]
	for w in weapons:
		if not w is int or not allowed(armour,w,pack) or w in seen:return false
		seen.append(w)
	return true
static func cost(armour: String,weapons: Array,pack: String) -> int:
	var value: int=preload("res://deathmatch/movement/tribes_armour.gd").definition(armour).cost+PACKS[pack].cost+35
	for w in weapons:value+=PRICES[w]+capacity(armour,pack,w)*AMMO_PRICE[w]
	for w in [9,10]:value+=capacity(armour,pack,w)*AMMO_PRICE[w]
	return value
static func table() -> Array:
	var rows: Array=[]
	var raw=[.125,.45,.11,.5,.4,.42,.006,1.0,0,.5,.65,0]
	var cycles=[.3,.6,.2,1.5,1.0,.6,.1,2.5,.1,.5,.5,.2]
	var kinds=["tribes_bolt","plasma","tribes_bullet","tribes_disc","tribes_grenade","sniper","beam","tribes_mortar","beam","tribes_handgrenade","tribes_mine","beam"]
	var speeds=[200,55,425,65,sqrt(150.0*20),0,0,sqrt(275.0*20),0,9,15,0]
	var inherits=[.5,.3,1,.5,.5,0,0,.5,0,1,1,0]
	var life=[2,3,1.5,6.5,30,0,0,30,0,2,30,0]
	for w in 12:
		rows.append({"name":NAMES[w],"ammo":-1,"cost":0,"damage":roundi(raw[w]*UNIT),"dice":1,"cycle":cycles[w],"kind":kinds[w],"speed":speeds[w],"fuse":life[w],"inherit":inherits[w],"range":1000.0,"pellets":1,"spread":0.0,"vertical":0.0,"radius":.025,"splash":0,"blast_radius":0.0,"tribes":true})
	for w in [1,3,4,7,9,10]:rows[w].splash=rows[w].damage
	for pair in [[1,4],[3,7.5],[4,15],[7,20],[9,10],[10,10]]:rows[pair[0]].blast_radius=float(pair[1])
	for w in [4,7,9,10]:rows[w].gravity=20.0;rows[w].bounce=.45 if w==4 else .1 if w==7 else .15;rows[w].radius=.2 if w==4 else .3 if w==7 else .06
	rows[0].minimum=5.0;rows[0].energy=6.0
	rows[2].spread=rad_to_deg(.005);rows[2].vertical=rad_to_deg(.005)
	rows[3].acceleration=5.0;rows[3].terminal=80.0;rows[3].kick=150.0
	rows[4].arm=1.0;rows[4].kick=150.0;rows[7].arm=2.0;rows[7].kick=250.0
	rows[5].scope=true;rows[5].minimum=10.0;rows[5].energy=60.0
	rows[6].range=40.0;rows[6].minimum=3.0;rows[6].energy=1.1
	rows[8].range=5.0;rows[8].minimum=3.0;rows[8].energy=1.0
	rows[11].minimum=5.0;rows[11].energy=3.0 # Sustained 15 energy/sec at the .2s trace cadence.
	rows[9].kick=100.0;rows[10].kick=150.0
	return rows
