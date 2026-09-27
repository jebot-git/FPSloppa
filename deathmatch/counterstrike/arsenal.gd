extends RefCounted
## Independently implemented arena adaptation; numerical references in docs/CS16-LOADOUT.md.
# CS 1.6 non-VIP purchase policy, in this project's stable weapon slot order.
# Bits: 1 = Terrorists, 2 = Counter-Terrorists. Knife is issued, never bought.
# Glock and USP are BOTH purchasable by either side; only starting pistols differ.
# Reference: ReGameDLL_CS weapontype.cpp, CanBuyWeaponByMaptype(..., false).
const PURCHASE_ROLES=[0,3,3,3,3,3,1,2,3,3,3,3]
const STARTING_SIDEARMS=[1,2]
const PREFERRED_RIFLES=[6,7]
static func can_purchase(slot: int,role: int) -> bool:
	return role in [0,1] and slot>0 and slot<PURCHASE_ROLES.size() and (int(PURCHASE_ROLES[slot])&(1<<role))!=0
const NAMES=["KNIFE","GLOCK-18","USP","M3 SUPER 90","XM1014","MP5 NAVY","AK-47","M4A1","M249","AWP","DESERT EAGLE","P90"]
# ammo family, damage, cycle seconds, magazine, reload seconds, range modifier per 500 GoldSrc units.
const VALUES=[[-1,25,.4,0,0,1],[0,25,.2,20,2.2,.75],[0,34,.225,12,2.7,.79],[1,20,.875,8,.55,.7],[1,20,.25,7,.3,.7],[0,26,.075,30,2.63,.84],[2,36,.0955,30,2.45,.98],[2,32,.0875,30,3.05,.97],[2,32,.1,100,4.7,.97],[3,115,1.45,10,2.5,.99],[0,54,.3,7,2.2,.81],[0,21,.066,50,3.4,.885]]
const SPEEDS=[250,250,250,230,240,250,221,230,220,210,250,245]
const SPREAD=[0,.6,.45,3.87,4.16,.45,.32,.28,.65,.06,.65,.55]
const BLOOM=[0,.35,.3,0,0,.12,.24,.18,.25,0,.5,.13]
static func table() -> Array:
	var result: Array=[]
	for i in NAMES.size():
		var v: Array=VALUES[i]
		result.append({"name":NAMES[i],"ammo":v[0],"cost":0 if i==0 else 1,"damage":v[1],"cycle":v[2],"magazine":v[3],"reload":v[4],"falloff":v[5],"dice":1,"kind":"hitscan","range":1.25 if i==0 else 200.0,"pellets":9 if i==3 else 6 if i==4 else 1,"spread":SPREAD[i],"vertical":SPREAD[i],"speed":0.0,"radius":.025,"fuse":5.0,"head_damage":v[1]*4,"semi":i in [1,2,10],"shell_reload":i in [3,4],"bloom":BLOOM[i],"move_speed":SPEEDS[i]/250.0})
	result[0].merge({"kind":"melee","alt":{"damage":65,"cycle":1.1,"range":1.0}},true)
	result[1]["burst"]=true
	result[2]["suppressor"]={"damage":30,"head_damage":120,"spread":.65,"vertical":.65}
	result[7]["suppressor"]={"damage":33,"head_damage":132,"falloff":.95,"spread":.35,"vertical":.35}
	result[9].merge({"kind":"sniper","scope":true,"alt":{"zoom":true}},true)
	return result
static func pickup(index: int) -> int:return int(VALUES[clampi(index,0,11)][3])
