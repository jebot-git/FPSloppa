extends RefCounted
const DIRECTORY="res://deathmatch/ui/weapon_icons/"
const NAMES={"BEOWULF GRAV TANK":"st_beowulf","THUNDERSWORD BOMBER":"st_thundersword","JERICHO MOBILE BASE":"st_jericho","WILDCAT GRAVCYCLE":"st_wildcat","SHRIKE FIGHTER":"st_shrike","HAVOC TRANSPORT":"st_havoc","LIGHT TRANSPORT":"st_lpc","HEAVY TRANSPORT":"st_hpc","SCOUT FLYER":"st_scout","GRENADES":"de_he","HE GRENADE":"de_he","FLASHBANG":"de_flash","SMOKE GRENADE":"de_smoke","KEVLAR":"de_vest","VEST + HELMET":"de_vest","DEFUSE CUTTERS":"de_cutters","AMMUNITION":"de_ammo","PRIMARY AMMO":"de_ammo","PISTOL AMMO":"de_ammo","BACK":"de_back","GLOCK-18":"cs_glock","USP":"cs_usp","DESERT EAGLE":"cs_deagle","M3 SUPER 90":"cs_m3","XM1014":"cs_xm1014","MP5 NAVY":"cs_mp5","AK-47":"cs_ak47","M4A1":"cs_m4a1","M249":"cs_m249","AWP":"cs_awp","P90":"cs_p90","KNIFE":"knife","SPANNER":"spanner","FIST":"fist","CHAINSAW":"chainsaw","DUAL PISTOLS":"pistols","ENFORCER":"pistol","SHOTGUN":"shotgun","SUPER SHOTGUN":"super_shotgun","CHAINGUN":"chaingun","MINIGUN":"chaingun","ASSAULT CANNON":"chaingun","ROCKET LAUNCHER":"rocket_launcher","INCENDIARY CANNON":"rocket_launcher","PLASMA RIFLE":"plasma_rifle","BFG 9000":"bfg","RAILGUN":"railgun","AXE":"axe","GRENADE LAUNCHER":"grenade_launcher","NAILGUN":"nailgun","SUPER NAILGUN":"super_nailgun","LIGHTNING GUN":"lightning_gun","IMPACT HAMMER":"impact_hammer","BIO RIFLE":"bio_rifle","SHOCK RIFLE":"shock_rifle","FLAK CANNON":"flak_cannon","PULSE GUN":"pulse_gun","REDEEMER":"redeemer","SNIPER RIFLE":"sniper_rifle","RIPPER":"ripper","TRANSLOCATOR":"translocator","FLAMETHROWER":"flamethrower","TRANQUILIZER":"tranquilizer"}
const TRIBES={
	"TRIBES BLASTER": "tribes_blaster",
 "TRIBES PLASMA GUN": "tribes_plasma",
 "TRIBES CHAINGUN": "tribes_chaingun",
 "TRIBES DISC LAUNCHER": "tribes_disc",
 "TRIBES GRENADE LAUNCHER": "tribes_grenade_launcher",
 "TRIBES LASER RIFLE": "tribes_laser",
 "TRIBES ELF GUN": "tribes_elf",
 "TRIBES MORTAR": "tribes_mortar",
 "TRIBES REPAIR GUN": "tribes_repair",
 "TRIBES HAND GRENADE": "tribes_grenade",
 "TRIBES LAND MINE": "tribes_mine",
 "TRIBES TARGETING LASER": "tribes_targeter",
 "BLASTER": "tribes_blaster",
 "PLASMA GUN": "tribes_plasma",
 "DISC LAUNCHER": "tribes_disc",
 "LASER RIFLE": "tribes_laser",
 "ELF GUN": "tribes_elf",
 "MORTAR": "tribes_mortar",
 "REPAIR GUN": "tribes_repair",
 "HAND GRENADE": "tribes_grenade",
 "LAND MINE": "tribes_mine",
 "TARGETING LASER": "tribes_targeter",
 "LIGHT ARMOUR": "tribes_light",
 "MEDIUM ARMOUR": "tribes_medium",
 "HEAVY ARMOUR": "tribes_heavy",
 "ENERGY PACK": "tribes_energy_pack",
 "AMMO PACK": "tribes_ammo_pack",
 "REPAIR PACK": "tribes_repair_pack",
 "SHIELD PACK": "tribes_shield_pack",
 "SENSOR JAMMER": "tribes_jammer_pack",
 "NO BACKPACK": "tribes_no_pack",
 "REMOTE TURRET": "tribes_remote_turret",
 "REMOTE INVENTORY": "tribes_remote_inventory",
 "REMOTE AMMO": "tribes_remote_ammo",
 "PULSE SENSOR": "tribes_pulse_sensor",
 "MOTION SENSOR": "tribes_motion_sensor",
 "REMOTE JAMMER": "tribes_remote_jammer",
 "REMOTE CAMERA": "tribes_remote_camera",
 "ST ARMOUR": "tribes_menu_armour",
 "ST BACK": "tribes_menu_back",
 "ST BACKPACK": "tribes_menu_backpack",
 "ST BEACON": "tribes_menu_beacon",
 "ST BUY BEACONS": "tribes_menu_buy_beacons",
 "ST CARRIED": "tribes_menu_carried",
 "ST CLOSE CAMERA": "tribes_menu_close_camera",
 "ST CONTACTS": "tribes_menu_contacts",
 "ST DEPLOYABLES": "tribes_menu_deployables",
 "ST DROP PACK": "tribes_menu_drop_pack",
 "ST DROP WEAPON": "tribes_menu_drop_weapon",
 "ST FIELD": "tribes_menu_field",
 "ST KIT": "tribes_menu_kit",
 "ST NETWORK": "tribes_menu_network",
 "ST NEXT": "tribes_menu_next",
 "ST REFIT": "tribes_menu_refit",
 "ST RELEASE TURRET": "tribes_menu_release_turret",
 "ST SHARE AMMO": "tribes_menu_share_ammo",
 "ST TURRET ELF": "tribes_menu_turret_elf",
 "ST TURRET FUSION": "tribes_menu_turret_fusion",
 "ST TURRET MINI": "tribes_menu_turret_mini",
 "ST TURRET MISSILE": "tribes_menu_turret_missile",
 "ST TURRET MORTAR": "tribes_menu_turret_mortar",
 "ST WEAPONS": "tribes_menu_weapons"
}
static var cache: Dictionary={}
static func texture(weapon_name: String) -> Texture2D:
	var key: String=TRIBES.get(weapon_name,NAMES.get(weapon_name,"pistol"))
	if key.begins_with("tribes_menu_"):
		if not cache.has(key):cache[key]=load("res://deathmatch/tribes/menu_icons/"+key+".res")
		return cache[key]
	if key in ["st_scout","st_lpc","st_hpc","st_wildcat","st_shrike","st_havoc","st_beowulf","st_thundersword","st_jericho"]:
		if not cache.has(key):cache[key]=load("res://deathmatch/vehicles/tribes/"+key.trim_prefix("st_")+"-icon.res")
		return cache[key]
	if not cache.has(key):cache[key]=load("res://deathmatch/weapons/tribes/"+key+".res") if key.begins_with("tribes_") else load(DIRECTORY+key+".svg")
	return cache[key]
