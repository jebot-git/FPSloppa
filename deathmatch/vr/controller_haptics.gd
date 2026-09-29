extends RefCounted
## Controller recoil follows weapon behavior, independent of vest settings or slot IDs.
static func recipe(definition: Dictionary) -> Dictionary:
	var title: String=definition.get("name","")
	var kind: String=definition.get("kind","")
	var amplitude:=.42;var duration:=.055;var frequency:=140.0
	if title in ["FIST","AXE","KNIFE","SPANNER","WEAPON WHIP"] or kind=="melee":
		amplitude=.32;duration=.065;frequency=85
	elif title=="CHAINSAW":amplitude=.32;duration=.08;frequency=65
	elif title=="IMPACT HAMMER" or kind=="hammer":amplitude=.85;duration=.13;frequency=70
	elif title in ["BFG 9000","REDEEMER"]:amplitude=1.0;duration=.20;frequency=65
	elif title in ["SUPER SHOTGUN","FLAK CANNON"]:amplitude=.95;duration=.14;frequency=90
	elif title in ["SHOTGUN","M3 SUPER 90","XM1014"]:amplitude=.85;duration=.12;frequency=95
	elif title in ["AWP","SNIPER RIFLE","RAILGUN"] or kind=="sniper":amplitude=.9;duration=.12;frequency=100
	elif title=="DESERT EAGLE":amplitude=.72;duration=.085;frequency=110
	elif title in ["ROCKET LAUNCHER","GRENADE LAUNCHER","INCENDIARY CANNON","TITAN CANNON"] or kind in ["rocket","grenade","flak_shell","warhead"]:amplitude=.8;duration=.13;frequency=80
	elif title=="FLAMETHROWER":amplitude=.24;duration=.065;frequency=60
	elif kind in ["beam","pulse_beam"]:amplitude=.28;duration=.065;frequency=200
	elif title in ["PLASMA RIFLE","PULSE GUN","LIGHTNING GUN","SHOCK RIFLE","BIO RIFLE"] or kind in ["shock_beam","shock_orb","plasma","pulse","bio"]:amplitude=.48;duration=.065;frequency=180
	elif title in ["AK-47","M4A1","M249","ASSAULT CANNON"]:amplitude=.56;duration=.055;frequency=135
	elif title in ["MP5 NAVY","P90","MINIGUN","CHAINGUN","NAILGUN","SUPER NAILGUN","RIPPER"] or kind in ["nail","flak","razor","razor_blast"]:amplitude=.36;duration=.045;frequency=155
	elif title in ["TRANSLOCATOR","REPAIR GUN","TARGETING LASER"] or kind=="translocator":amplitude=.18;duration=.035;frequency=180
	# Rapid weapons retain a discrete pulse for each accepted shot.
	duration=minf(duration,maxf(.02,float(definition.get("cycle",.3))*.8))
	return {"amplitude":amplitude,"duration":duration,"frequency":frequency}
