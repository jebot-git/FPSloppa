extends RefCounted
const BACK:=1000
const GROUPS={200:"SIDEARMS",201:"LONG GUNS",202:"EQUIPMENT",203:"AMMUNITION",204:"GRENADES"}
static func rows(rules,id: int,page: int) -> Array:
	var result: Array=[];var cash: int=rules.account(id).cash
	if page==0:
		for group in GROUPS:result.append({"id":group,"name":GROUPS[group],"icon":{200:"USP",201:"AK-47" if rules.role(id)==0 else "M4A1",202:"KEVLAR",203:"AMMUNITION",204:"GRENADES"}[group],"ammo":-1,"usable":true,"buy":true,"cash":cash})
		return result
	for offer in rules.offers(id):
		if (page==200 and offer.id in rules.PISTOLS) or (page==201 and offer.id<12 and offer.id not in rules.PISTOLS) or (page==202 and offer.id in [100,101,102]) or (page==203 and offer.id in [103,104]) or (page==204 and offer.id in [110,111,112]):result.append(offer)
	result.append({"id":BACK,"name":"BACK","ammo":-1,"usable":true,"buy":true,"cash":cash})
	return result
