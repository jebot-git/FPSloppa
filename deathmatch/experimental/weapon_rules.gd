extends RefCounted
## Arena approximations. TF/TB require Quake; Assault requires UT99.
const Doom=preload("res://deathmatch/weapons.gd")
const IDS=["doom","quake","ut99"]
const NAMES={"doom":"DOOM · classic","quake":"QUAKE I · experimental","ut99":"UT99 · experimental"}
const SLOT_COUNT:=12
const MODE_RULES={"tf":"quake","tb":"quake","as":"ut99","cq":"ut99"}
static func selectable(mode:String) -> bool:return mode in ["dm","tdm","ctf","koth","ft"]
static func required(mode:String) -> String:return "doom" if mode in ["ig","if","cc"] else MODE_RULES.get(mode,"")
var preferred:="doom"
var kind:="doom"
var game
var table: Array=[]
func setup(arena: Node) -> void:game=arena;select("doom")
static func for_mode(mode: String,value: String) -> String:return MODE_RULES.get(mode,value)
func apply_mode() -> void:select(preferred,false)
func select(value: String,remember: bool=true) -> bool:
	if not value in IDS:return false
	if remember:preferred=value
	var resolved:=for_mode(game.match_mode.kind if game else "dm",value)
	if kind==resolved and not table.is_empty():return true
	kind=resolved;table=Doom.DATA.duplicate(true)
	if kind=="quake":
		set_weapon(0,"AXE",-1,0,.5,20,{"range":2.0})
		set_weapon(1,"AXE",-1,0,.5,20,{"range":2.0})
		set_weapon(2,"SHOTGUN",1,1,.5,4,{"pellets":6,"spread":2.29,"vertical":2.29})
		set_weapon(3,"SUPER SHOTGUN",1,2,.7,4,{"pellets":14,"spread":7.97,"vertical":4.57})
		set_weapon(4,"GRENADE LAUNCHER",2,1,.6,120,{"kind":"grenade","speed":18.75,"gravity":25.0,"fuse":2.5,"bounce":.55,"splash":120,"blast_radius":5.0,"radius":.10})
		set_weapon(5,"NAILGUN",0,1,.1,9,{"kind":"nail","speed":31.25,"radius":.035})
		set_weapon(6,"ROCKET LAUNCHER",2,1,.8,100,{"kind":"rocket","speed":31.25,"radius":.10,"splash":120,"blast_radius":5.0,"direct_random":20})
		set_weapon(7,"SUPER NAILGUN",0,2,.1,18,{"kind":"nail","speed":31.25,"radius":.045})
		set_weapon(8,"LIGHTNING GUN",3,1,.1,30,{"kind":"beam","range":18.75,"beam_radius":.10})
	elif kind=="ut99":
		set_weapon(0,"IMPACT HAMMER",-1,0,.8,60,{"kind":"hammer","range":1.6,"surface_range":2.5,"charge_max":1.5,"alt":{"damage":30,"cycle":.5,"range":1.3,"surface_range":3.75}})
		set_weapon(1,"BIO RIFLE",3,1,.35,20,{"kind":"bio","speed":14.0,"gravity":12.0,"fuse":8.0,"splash":20,"blast_radius":1.8,"radius":.13,"alt":{"charge_max":2.0}})
		set_weapon(2,"ENFORCER",0,1,.4,17,{"spread":.5,"vertical":.5,"alt":{"cycle":.2,"spread":3.5,"vertical":3.5}})
		set_weapon(3,"SHOCK RIFLE",3,1,.7,40,{"kind":"shock_beam","alt":{"kind":"shock_orb","speed":20.0,"radius":.22,"damage":55,"splash":55,"blast_radius":1.4}})
		set_weapon(4,"FLAK CANNON",1,1,.9,16,{"kind":"flak","pellets":8,"spread":8.0,"vertical":6.0,"speed":50.0,"radius":.055,"bounce":.65,"gravity":4.0,"fuse":2.0,"alt":{"kind":"flak_shell","pellets":1,"speed":24.0,"gravity":15.0,"spread":0.0,"vertical":0.0,"damage":75,"splash":75,"blast_radius":3.0,"radius":.15}})
		set_weapon(5,"MINIGUN",0,1,.1,9,{"spread":1.2,"vertical":1.2,"alt":{"cycle":.06,"damage":7,"spread":4.0,"vertical":4.0}})
		set_weapon(6,"ROCKET LAUNCHER",2,1,.9,100,{"kind":"rocket","speed":18.0,"radius":.12,"splash":100,"blast_radius":4.4,"charge_max":3.0,"alt":{"kind":"grenade","speed":15.0,"gravity":19.0,"fuse":2.5,"bounce":.6}})
		set_weapon(7,"PULSE GUN",3,1,.12,20,{"kind":"pulse","speed":40.0,"radius":.10,"alt":{"kind":"beam","cycle":.1,"damage":12,"range":18.0,"beam_radius":.10}})
		set_weapon(8,"REDEEMER",2,10,2.0,1000,{"kind":"warhead","speed":16.0,"radius":.30,"splash":1000,"blast_radius":30.0,"fuse":12.0,"alt":{"guided":true}})
		set_weapon(9,"SNIPER RIFLE",0,1,.7,45,{"kind":"sniper","range":200.0,"head_damage":100,"scope":true,"alt":{"zoom":true}})
		set_weapon(10,"RIPPER",0,1,.35,30,{"kind":"razor","speed":32.0,"radius":.10,"bounce":1.0,"fuse":3.0,"head_damage":90,"alt":{"kind":"razor_blast","splash":34,"blast_radius":2.6,"bounce":0.0}})
		set_weapon(11,"TRANSLOCATOR",-1,0,.5,0,{"kind":"translocator","speed":18.0,"gravity":19.0,"radius":.12,"fuse":30.0,"bounce":.4})
	return true
func set_weapon(index: int,title: String,ammo: int,cost: int,cycle: float,damage: int,extra: Dictionary) -> void:
	while table.size()<=index:table.append({})
	table[index]={"name":title,"ammo":ammo,"cost":cost,"cycle":cycle,"damage":damage,"dice":1,"kind":"hitscan","range":100.0,"pellets":1,"spread":0.0,"vertical":0.0,"radius":.025,"speed":0.0,"fuse":5.0}
	table[index].merge(extra,true)
func data(index: int,alternate: bool=false) -> Dictionary:
	if game and game.match_mode.fixed_loadout():return Doom.DATA[clampi(index,0,9)]
	var row: Dictionary=table[clampi(index,0,table.size()-1)]
	if alternate and kind=="ut99":row=row.duplicate();row.merge(row.get("alt",{}),true)
	return row
func experimental() -> bool:return kind!="doom" and (not game or not game.match_mode.fixed_loadout())
func effective() -> String:return kind if experimental() else "doom"
func dual() -> bool:return not experimental()
func valid(index: int) -> bool:return index>=0 and index<(table.size() if experimental() else 10) and not (index==11 and game and game.match_mode.kind=="as")
func max_ammo() -> Array:return [200,100,100,100] if kind=="quake" else Doom.MAX_AMMO
func ammo_names() -> Array:return ["NAILS","SHELLS","ROCKETS","CELLS"] if kind=="quake" else ["BULLETS / BLADES","FLAK","ROCKETS","ENERGY / BIO"] if kind=="ut99" else Doom.AMMO_NAMES
func color(index: int) -> Color:
	if not experimental():return Doom.COLORS[clampi(index,0,9)]
	if kind=="quake":return Color("aebcff") if index==8 else Color("ffa13b") if index in [4,6] else Color("e1ba80")
	return [Color("dbdcce"),Color("7adb38"),Color("ffca83"),Color("bd65ff"),Color("ffb842"),Color("ffe59c"),Color("ff683c"),Color("61ed83"),Color("fff3b8"),Color("e0eaff"),Color("57cedb"),Color("85aaff")][clampi(index,0,11)]
func spawn_loadout(state: Dictionary) -> void:
	if not experimental():return
	state.owned=[0,2];state.weapon=2;state.ammo=[0,25,0,0] if kind=="quake" else [50,0,0,0]
	if kind=="ut99" and game.match_mode.kind!="as":state.owned.append(11)
func tf_loadout(state: Dictionary) -> void:
	if not experimental():return
	if kind=="ut99":
		state.ammo=[100,30,20,150];return
	var definition: Dictionary=game.match_mode.fortress.class_definition(state.tf_class)
	state.owned=definition.owned.duplicate();state.weapon=definition.weapon;state.ammo=definition.ammo.duplicate()
func pickup_bundle(index: int) -> Array:
	# Existing BSPs have seven weapon entity types. These paired caches expose the
	# two extra UT weapons without changing geometry or network pickup ordering.
	if game and game.match_mode.kind in ["as","cq"]:return []
	return [9] if effective()=="ut99" and index==3 else [10] if effective()=="ut99" and index==5 else []
func pickup_title(index: int) -> String:
	var title: String=data(index).name
	for bonus in pickup_bundle(index):title+=" + "+data(bonus).name
	return title
func pickup_weapon(classname: String,fallback: int) -> int:
	if not experimental():return fallback
	if kind=="quake":return {"weapon_shotgun":2,"weapon_supershotgun":3,"weapon_nailgun":5,"weapon_supernailgun":7,"weapon_grenadelauncher":4,"weapon_rocketlauncher":6,"weapon_lightning":8}.get(classname,fallback)
	return {"weapon_shotgun":3,"weapon_supershotgun":4,"weapon_nailgun":5,"weapon_supernailgun":7,"weapon_grenadelauncher":1,"weapon_rocketlauncher":6,"weapon_lightning":8}.get(classname,fallback)

func vr_physical_only(index: int) -> bool:
	return index in [0,1] if effective()=="quake" else index==0 and effective()=="doom"
