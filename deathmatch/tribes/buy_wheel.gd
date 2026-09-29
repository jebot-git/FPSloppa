extends RefCounted
const A=preload("res://deathmatch/tribes/arsenal.gd")
var armour:="light"
var pack:="energy"
var guns: Array=[]
var page:=0
var camera_page:=0
var turret_page:=0
func open(state: Dictionary):
	armour=state.get("tribes_next","light");pack=state.get("tribes_next_pack","energy");guns=state.get("tribes_next_guns",A.defaults(armour)).duplicate();page=0;camera_page=0;turret_page=0
func rows(rules,id: int) -> Array:
	var cash: int=rules.deployables.available(id);var result: Array=[]
	var cost: int=rules.refit_cost(id,armour,guns,pack)
	var near: bool=rules.can_refit(id)
	var state: Dictionary=rules.game.players[id]
	if page==0 and rules.vehicles.station(id)>=0:
		for i in rules.vehicles.Data.KINDS.size():
			var kind: String=rules.vehicles.Data.KINDS[i];var d: Dictionary=rules.vehicles.Data.definition(kind)
			result.append({"id":5000+i,"name":d.title,"detail":"LIGHT PILOT · %d PASSENGERS · USE TO BOARD"%(d.seats.size()-1),"icon":d.title,"ammo":d.price,"usable":cash>=d.price and rules.vehicles.count(rules.game.players[id].team,kind)<rules.vehicles.Data.TEAM_LIMIT})
	elif page==0:
		for row in [[200,"WEAPONS","ST WEAPONS"],[201,"BACKPACK","ST BACKPACK"],[202,"ARMOUR","ST ARMOUR"],[203,"PURCHASE / REFIT" if near else "SAVE FAVOURITES" if rules.base_ctf() else "QUEUE LOADOUT","ST REFIT"],[209,"FIELD EQUIPMENT","ST FIELD"],[205,"CARRIED WEAPONS","ST CARRIED"],[206,"DEPLOYABLES","ST DEPLOYABLES"],[207,"SENSOR NETWORK","ST NETWORK"]]:
			result.append({"id":row[0],"name":row[1],"icon":row[2],"caption":row[1],"ammo":maxi(0,cost) if row[0]==203 else -1,"usable":A.valid_loadout(armour,guns,pack) and (not near or cash>=cost and rules.deployables.can_shop(id,armour,pack)) if row[0]==203 else true})
	elif page==209:
		for row in [[204,"USE REPAIR KIT","ST KIT"],[210,"DROP BACKPACK","ST DROP PACK"],[211,"SHARE AMMUNITION","ST SHARE AMMO"],[212,"DROP HELD WEAPON","ST DROP WEAPON"],[213,"PLACE TARGET BEACON","ST BEACON"],[214,"BUY BEACONS · 5 ENERGY","ST BUY BEACONS"]]:
			var usable:=true
			match row[0]:
				204:usable=state.get("tribes_kit",false) and state.hp<rules.definition(id).hp
				210:usable=state.tribes_pack!="none"
				211:usable=rules.recovery.AMMO_CHUNK[state.weapon]>0 and state.tribes_ammo[state.weapon]>(0 if state.weapon==2 else 1)
				212:usable=state.weapon<8 and state.owned.filter(func(w):return w<8).size()>1
				213:usable=state.get("tribes_beacons",0)>0
				214:usable=near and cash>=5 and state.get("tribes_beacons",0)<rules.targeting.capacity(id)
			result.append({"id":row[0],"name":row[1],"icon":row[2],"caption":"PLACE BEACON" if row[0]==213 else "BUY BEACONS" if row[0]==214 else row[1],"ammo":int(state.get("tribes_beacons",0)) if row[0] in [213,214] else -1,"usable":usable})
	elif page==200:
		for w in 8:result.append({"id":w,"name":("✓ " if w in guns else "")+A.NAMES[w],"icon":"TRIBES "+A.NAMES[w],"ammo":A.PRICES[w],"usable":A.allowed(armour,w,pack) and (w in guns or guns.size()<rules.Armour.definition(armour).guns)})
	elif page==201:
		for i in 6:
			var key: String=A.PACKS.keys()[i];result.append({"id":300+i,"name":("✓ " if pack==key else "")+A.PACKS[key].name,"icon":A.PACKS[key].name,"ammo":A.PACKS[key].cost,"usable":true})
	elif page==206:
		for i in range(6,A.PACKS.size()):
			var key: String=A.PACKS.keys()[i];var count: int=rules.deployables.count(rules.game.players[id].team,key)
			result.append({"id":300+i,"name":A.PACKS[key].name,"detail":"TEAM %d / %d"%[count,rules.deployables.Data.KINDS[key].limit],"icon":A.PACKS[key].name,"ammo":A.PACKS[key].cost,"usable":rules.deployables.active() and rules.deployables.Data.allowed(armour,key) and rules.deployables.can_shop(id,armour,key)})
	elif page==208:
		result.append({"id":4000,"name":"RELEASE TURRET","icon":"ST RELEASE TURRET","ammo":-1,"usable":true})
		var pads=rules.stations()
		if pads:
			var keys: Array=range(pads.defences.rows.size()).filter(func(key):return pads.defences.rows[key].team==rules.game.players[id].team)
			turret_page=clampi(turret_page,0,maxi(0,(keys.size()-1)/5))
			for key in keys.slice(turret_page*5,turret_page*5+5):
				var row: Dictionary=pads.defences.rows[key]
				result.append({"id":4001+key,"name":pads.defences.Data.TYPES[row.kind].name,"icon":"ST TURRET "+row.kind.to_upper(),"ammo":roundi(row.hp),"usable":pads.defences.active(key) and row.operator in [0,id]})
			if keys.size()>5:result.append({"id":1002,"name":"NEXT TURRETS","icon":"ST NEXT","ammo":-1,"usable":true})
	elif page==217:
		var keys: Array=rules.deployables.rows.keys().filter(func(key):return rules.deployables.rows[key].team==state.team and rules.deployables.rows[key].kind in ["camera","turret"]);keys.sort()
		camera_page=clampi(camera_page,0,maxi(0,(keys.size()-1)/5))
		for key in keys.slice(camera_page*5,camera_page*5+5):
			var row: Dictionary=rules.deployables.rows[key]
			result.append({"id":60000+key,"name":"CONTROL "+row.kind.to_upper()+" %d"%key,"icon":"REMOTE CAMERA" if row.kind=="camera" else "REMOTE TURRET","ammo":roundi(row.hp),"usable":rules.remote.active(key) and rules.remote.operators.get(key,0) in [0,id]})
		if keys.size()>5:result.append({"id":1003,"name":"NEXT DEVICES","icon":"ST NEXT","ammo":-1,"usable":true})
	elif page==207:
		result.append({"id":217,"name":"REMOTE CONTROLS","icon":"REMOTE CAMERA","ammo":-1,"usable":true})
		result.append({"id":208,"name":"BASE TURRETS","icon":"ST TURRET FUSION","ammo":-1,"usable":true})
		result.append({"id":2000,"name":"CLOSE CAMERA","icon":"ST CLOSE CAMERA","ammo":-1,"usable":true})
		var team: int=rules.game.players[id].team
		var cameras: Array=rules.deployables.rows.keys().filter(func(key):return rules.deployables.rows[key].kind=="camera" and rules.deployables.rows[key].team==team);cameras.sort()
		camera_page=clampi(camera_page,0,maxi(0,(cameras.size()-1)/2))
		for key in cameras.slice(camera_page*2,camera_page*2+2):result.append({"id":2000+key,"name":"CAMERA %d"%key,"icon":"REMOTE CAMERA","ammo":-1,"usable":true})
		if cameras.size()>2:result.append({"id":1001,"name":"NEXT CAMERAS","icon":"ST NEXT","ammo":-1,"usable":true})
		result.append({"id":1500,"name":"SENSOR CONTACTS","icon":"ST CONTACTS","ammo":rules.deployables.contacts[team].size() if team in [0,1] else 0,"usable":false})
	elif page==202:
		for i in 3:
			var key: String=["light","medium","heavy"][i];result.append({"id":400+i,"name":key.to_upper()+" ARMOUR","icon":key.to_upper()+" ARMOUR","ammo":rules.CLASSES[key].cost,"usable":rules.deployables.station(id)<0 or key==state.tribes_class})
	if page==0 and result.size()>3 and cost<0:result[3]["detail"]="REFUND %d ENERGY"%-cost
	if page!=0:result.append({"id":1000,"name":"BACK","icon":"ST BACK","ammo":-1,"usable":true})
	for row in result:row.merge({"buy":true,"cash":cash,"currency":"ENERGY","heading":"INVENTORY","infinite_energy":rules.infinite_energy})
	return result
func select(id: int,rules,peer: int) -> bool:
	# True hands input to another view; purchases and field actions keep this menu.
	if id in [5000,5001,5002]:rules.buy_vehicle(rules.vehicles.Data.KINDS[id-5000])
	elif id==1000:page=0
	elif id==1002:
		var pads=rules.stations();var count: int=pads.defences.rows.filter(func(row):return row.team==rules.game.players[peer].team).size() if pads else 0
		turret_page=(turret_page+1)%maxi(1,ceili(count/5.0))
	elif id==1001:camera_page+=1;var cameras: int=rules.deployables.count(rules.game.players[peer].team,"camera");camera_page%=maxi(1,ceili(cameras/2.0))
	elif id==1003:
		var count: int=rules.deployables.rows.values().filter(func(row):return row.team==rules.game.players[peer].team and row.kind in ["camera","turret"]).size()
		camera_page=(camera_page+1)%maxi(1,ceili(count/5.0))
	elif id in [200,201,202,206,207,208,209,217]:page=id
	elif id in [210,211,212,213,214]:rules.field_action(["pack","ammo","weapon","beacon","buy_beacons"][id-210])
	elif id==7000:rules.open_pda();return true
	elif id>=60000:rules.control_remote(id-60000);return true
	elif id>=4000:rules.control_turret(id-4001);return true
	elif id>=2000:rules.view_camera(id-2000 if id>2000 else -1);return true
	elif id>=0 and id<8:
		if id in guns:guns.erase(id)
		elif A.allowed(armour,id,pack) and guns.size()<rules.Armour.definition(armour).guns:guns.append(id)
	elif id>=300 and id<300+A.PACKS.size():
		var chosen: String=A.PACKS.keys()[id-300]
		if not rules.deployables.Data.allowed(armour,chosen):return false
		pack=chosen;guns=guns.filter(func(w):return A.allowed(armour,w,pack));page=0
	elif id in [400,401,402]:
		armour=["light","medium","heavy"][id-400]
		if not rules.deployables.Data.allowed(armour,pack):pack="none"
		guns=guns.filter(func(w):return A.allowed(armour,w,pack)).slice(0,rules.Armour.definition(armour).guns);page=0
	elif id==203 and A.valid_loadout(armour,guns,pack) and (not rules.can_refit(peer) or rules.deployables.available(peer)>=rules.refit_cost(peer,armour,guns,pack)):rules.choose_equipment(armour,guns,pack,rules.can_refit(peer))
	elif id==204:rules.use_kit()
	elif id==205:return true
	return false
