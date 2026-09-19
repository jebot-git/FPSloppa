extends RefCounted
## One cosmetic recipe per actual shot type, independent of damage/hit radius.
static func kind(profile: String,slot: int,definition: Dictionary={}) -> String:
	if slot in [0,1] and profile!="ut99":return "melee"
	if definition.get("name","")=="FLAMETHROWER":return "flame"
	if definition.get("name","")=="SNIPER RIFLE":return "sniper"
	if definition.get("tranquilize",false):return "dart"
	if definition.get("pierce_players",false):return "rail_nail"
	if definition.has("kind"):return str(definition.kind)
	if slot<2:return "melee"
	if profile=="doom":return {6:"rocket",7:"plasma",8:"bfg",9:"rail"}.get(slot,"hitscan")
	return "rail" if slot==9 else "hitscan"
static func recipe(kind: String) -> Dictionary:
	var rows:={
		"rocket":["ff7626",2.3,.75,.10,.65,.030],"warhead":["ffb147",3.0,1.0,.12,1.0,.055],
		"plasma":["48bfff",2.0,.80,.09,.75,.035],"bfg":["80ef42",3.8,1.15,.14,1.2,.07],
		"shock_orb":["ae52ff",2.5,.90,.12,.55,.04],"pulse":["42ee62",1.8,.65,.085,.7,.025],
		"rail":["62dfff",2.2,.85,.24,200.0,.025],"shock_beam":["b75eff",2.2,.85,.16,200.0,.035],
		"beam":["8aa9ff",1.8,.65,.10,20.0,.03],"pulse_beam":["48ef69",1.7,.60,.10,20.0,.03],
		"flame":["ff7925",2.1,.65,.14,8.0,.025],"explosion":["ff962e",3.2,1.1,.26,0.0,.0],
		"combo":["bc62ff",4.0,1.2,.32,0.0,.0],"bio":["79d92e",.65,.20,.10,.20,.014],
		"nail":["e4c18d",0.0,0.0,.05,.42,.009],"rail_nail":["7ad9ff",.65,.25,.08,.65,.012],
		"dart":["c4bf93",0.0,0.0,.045,.25,.007],"flak":["ffc459",.6,.20,.07,.24,.009],
		"grenade":["b79856",0.0,0.0,.06,0.0,.0],"flak_shell":["ffd076",.4,.12,.07,.12,.012],
		"razor":["9ed8e0",0.0,0.0,.06,.22,.007],"razor_blast":["59d5e5",.55,.18,.08,.25,.009],
		"translocator":["85aaff",0.0,0.0,.08,.18,.01],
		"hitscan":["ffd192",.65,.18,.045,7.0,.006],"sniper":["e0eaff",.75,.22,.065,200.0,.007],
		"muzzle":["ffbc6d",1.8,.6,.055,0.0,.0]}
	if not rows.has(kind):return {}
	var r: Array=rows[kind]
	return {"color":Color(r[0]),"radius":r[1],"energy":r[2],"life":r[3],"length":r[4],"width":r[5]}
static func projectile_recipe(kind: String,definition: Dictionary) -> Dictionary:
	var result:=recipe(kind)
	if kind=="bio":
		result.radius=maxf(.65,minf(1.5,float(definition.get("radius",.13))*3.5))
		result.energy=minf(.4,.2*float(definition.get("radius",.13))/.13)
	return result
