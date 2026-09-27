extends RefCounted
const DIRECTORY="res://deathmatch/ui/weapon_icons/"
const NAMES={"GRENADES":"de_he","HE GRENADE":"de_he","FLASHBANG":"de_flash","SMOKE GRENADE":"de_smoke","KEVLAR":"de_vest","VEST + HELMET":"de_vest","DEFUSE CUTTERS":"de_cutters","AMMUNITION":"de_ammo","PRIMARY AMMO":"de_ammo","PISTOL AMMO":"de_ammo","BACK":"de_back","GLOCK-18":"cs_glock","USP":"cs_usp","DESERT EAGLE":"cs_deagle","M3 SUPER 90":"cs_m3","XM1014":"cs_xm1014","MP5 NAVY":"cs_mp5","AK-47":"cs_ak47","M4A1":"cs_m4a1","M249":"cs_m249","AWP":"cs_awp","P90":"cs_p90","KNIFE":"knife","SPANNER":"spanner","FIST":"fist","CHAINSAW":"chainsaw","DUAL PISTOLS":"pistols","ENFORCER":"pistol","SHOTGUN":"shotgun","SUPER SHOTGUN":"super_shotgun","CHAINGUN":"chaingun","MINIGUN":"chaingun","ASSAULT CANNON":"chaingun","ROCKET LAUNCHER":"rocket_launcher","INCENDIARY CANNON":"rocket_launcher","PLASMA RIFLE":"plasma_rifle","BFG 9000":"bfg","RAILGUN":"railgun","AXE":"axe","GRENADE LAUNCHER":"grenade_launcher","NAILGUN":"nailgun","SUPER NAILGUN":"super_nailgun","LIGHTNING GUN":"lightning_gun","IMPACT HAMMER":"impact_hammer","BIO RIFLE":"bio_rifle","SHOCK RIFLE":"shock_rifle","FLAK CANNON":"flak_cannon","PULSE GUN":"pulse_gun","REDEEMER":"redeemer","SNIPER RIFLE":"sniper_rifle","RIPPER":"ripper","TRANSLOCATOR":"translocator","FLAMETHROWER":"flamethrower","TRANQUILIZER":"tranquilizer"}
static var cache: Dictionary={}
static func texture(weapon_name: String) -> Texture2D:
	var key: String=NAMES.get(weapon_name,"pistol")
	if not cache.has(key):cache[key]=load(DIRECTORY+key+".svg")
	return cache[key]
