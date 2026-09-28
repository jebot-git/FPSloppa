extends RefCounted
## StaticBase defaults: disabled at .5 damage, destroyed at .75 (then full damage).
const UNIT:=100.0/.66
static func enabled(hp: float,maximum: float) -> bool:return hp>maximum*.5
static func hit(row: Dictionary,maximum: float,amount: float,powered: bool,family: String=""):
	if powered and enabled(row.hp,maximum) and row.get("energy",0.0)>0:
		var strength: float=.03*UNIT*(.25 if family=="Mortar" else .5 if family=="Grenade" else 2.0 if family=="Blaster" else 1.0)
		var absorbed: float=minf(amount,row.energy*strength)
		row.energy=maxf(0,row.energy-absorbed/strength);amount-=absorbed
	row.hp=maxf(0,row.hp-amount)
	if row.hp<=maximum*.25:row.hp=0.0
