extends RefCounted
## Fixed inventory units and medium pulse sensors share their base generator.
## Their BSP/native fixtures remain solid cover when disabled and repairable.
const Props=preload("res://deathmatch/tribes/prop_library.gd")
const Health=preload("res://deathmatch/tribes/equipment_health.gd")
const HP:=100.0/.66
const SENSOR_RANGE:=250.0
const STATION_PARTS=[[Vector3(-1.65,1.5,1.7),Vector3(.32,3,.6)],[Vector3(1.65,1.5,1.7),Vector3(.32,3,.6)],[Vector3(0,2.4,1.87),Vector3(2.4,1,.5)]]
const SENSOR_PARTS=[[Vector3(0,1,0),Vector3(4.6,2,4.6)],[Vector3(0,3.5,0),Vector3(.9,3,.9)],[Vector3(0,5,0),Vector3(7.4,2,1.2)]]
var pads
var rows: Array=[]
func setup(value,entities: Array):
	pads=value
	for station in pads.rows:
		station.asset=rows.size()
		rows.append({"kind":station.kind,"self_powered":station.get("self_powered",false),"power_group":station.power_group,"power_sources":station.power_sources,"team":station.team,"frame":station.frame,"hp":HP,"parts":STATION_PARTS,"point":station.frame*Vector3(0,2.4,1.57),"approach":station.position,"label":station.get("label"),"visual":station.get("visual")})
	var sensors: Array=[]
	for entity in entities:
		var data: Dictionary=entity.attributes
		if data.get("classname","")!="info_tribes_sensor" or int(data.get("team",-1)) not in [0,1]:continue
		var team:=int(data.team)
		var large: bool=data.get("type","")=="large"
		# The initial BSP omitted its sensor angle. Match that shipped geometry;
		# subsequently generated maps carry the explicit angle on the marker.
		var fallback: float=[2.38086,-.639979][team] if pads.game.current_map=="ctf_stonehenge" else 0.0
		var yaw: float=deg_to_rad(float(data.angle)) if data.has("angle") else fallback
		var frame:=Transform3D(Basis(Vector3.UP,yaw),entity.global_position-Vector3.UP*.70)
		sensors.append({"kind":"pulse","self_powered":pads.circuit(data).self_powered,"energy":100.0,"power_group":pads.circuit(data).power_group,"power_sources":pads.circuit(data).power_sources,"team":team,"frame":frame,"hp":HP*(1.5 if large else 1),"maximum":HP*(1.5 if large else 1),"range":400.0 if large else SENSOR_RANGE,"large":large,"parts":SENSOR_PARTS,"point":frame*Vector3(0,5,.6),"approach":frame*Vector3(0,0,3.4)})
	sensors.sort_custom(func(a,b):return a.team<b.team or a.team==b.team and a.frame.origin.x<b.frame.origin.x)
	for row in sensors:
		# Raindance's Oracle occupies a tight roof beside the original spawns.
		# Its compact native housing must not inherit Stonehenge's large BSP plinth.
		row.model_scale=.6 if pads.game.current_map=="ctf_raindance" and not row.large else 1.0
		row.parts=SENSOR_PARTS.map(func(part):return [part[0]*row.model_scale,part[1]*row.model_scale])
		row.point=row.frame*Vector3(0,5*row.model_scale,.6*row.model_scale)
		row.approach=row.frame*Vector3(0,0,3.4*row.model_scale)
		if row.large or pads.game.current_map!="ctf_stonehenge":
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;pads.add_child(body);body.global_transform=row.frame
			for part in row.parts:
				var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=part[1];shape.shape=box;shape.position=part[0];body.add_child(shape)
		if not pads.game.headless:
			var visual=Props.make("large_sensor" if row.large else "base_sensor",row.team);pads.add_child(visual);visual.global_transform=row.frame;visual.scale*=row.model_scale;row.visual=visual
			var label:=Label3D.new();label.font_size=30;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			pads.add_child(label);label.global_position=row.frame.origin+Vector3.UP*(7*row.model_scale);row.label=label
		rows.append(row)
func reset():
	for row in rows:row.hp=maximum(row);row.energy=100.0 if row.kind=="pulse" else 0.0
func active(key: int) -> bool:
	return key>=0 and key<rows.size() and Health.enabled(rows[key].hp,maximum(rows[key])) and pads.connected(rows[key])
func trace(hit: Dictionary) -> Dictionary:
	if pads.game.match_mode.kind!="st" or not hit.hit or hit.id!=0 or hit.has("deployable") or hit.has("generator"):return hit
	for key in rows.size():
		var row: Dictionary=rows[key];var local: Vector3=row.frame.affine_inverse()*hit.position
		for part in row.parts:
			if AABB(part[0]-part[1]*.5,part[1]).grow(.035).has_point(local):
				hit["base_asset"]=key;hit.erase("surface_normal");return hit
	return hit
func damage(key: int,attacker: int,amount: float,family: String=""):
	var game=pads.game
	if not game.multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=rows.size() or not is_finite(amount) or amount<=0:return
	if game.players.get(attacker,{}).get("team",-1)==rows[key].team and not game.match_mode.friendly_fire:return
	Health.hit(rows[key],maximum(rows[key]),amount,pads.connected(rows[key]),family)
func repair(key: int,id: int,amount: float) -> bool:
	var game=pads.game
	if not game.multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=rows.size() or game.players.get(id,{}).get("team",-1)!=rows[key].team or not is_finite(amount) or amount<=0:return false
	var before: float=rows[key].hp;rows[key].hp=minf(maximum(rows[key]),before+amount);return rows[key].hp>before
func blast(where: Vector3,attacker: int,amount: float,radius: float,source_team: int=-1,family: String=""):
	for key in rows.size():
		if rows[key].team==source_team and not pads.game.match_mode.friendly_fire:continue
		var point: Vector3=rows[key].point
		if where.distance_squared_to(point)>pow(radius+8,2):continue
		var hit: Dictionary=pads.game._trace(where,point+(point-where).normalized()*.1,attacker)
		if hit.get("base_asset",-1)!=key:continue
		var distance: float=where.distance_to(hit.position)
		if distance<radius:damage(key,attacker,amount*(1-distance/radius),family)
func snapshot() -> Array:return rows.map(func(row):return row.hp)
static func valid(data: Variant) -> bool:
	if not data is Array or data.size()>128:return false
	for hp in data:
		if not (hp is float or hp is int) or not is_finite(float(hp)) or hp<0 or hp>HP*1.5:return false
	return true
func receive(data: Array):
	if data.size()!=rows.size() or not valid(data):return
	for key in rows.size():
		if data[key]>maximum(rows[key]):return
	for key in rows.size():rows[key].hp=data[key]
func update():
	for key in rows.size():
		var row: Dictionary=rows[key]
		var state: String="DISABLED" if not Health.enabled(row.hp,maximum(row)) else "NO POWER" if not pads.connected(row) else "%d%%"%roundi(row.hp/maximum(row)*100)
		if is_instance_valid(row.get("visual")):Props.set_active(row.visual,active(key))
		if is_instance_valid(row.get("label")):
			row.label.text=(row.kind.to_upper()+" STATION" if row.kind!="pulse" else "LARGE PULSE SENSOR" if row.get("large",false) else "PULSE SENSOR")+" · "+state
			row.label.modulate=(Color("ff9385") if row.team==0 else Color("8ebeff")) if active(key) else Color("85858a")

func maximum(row: Dictionary) -> float:return float(row.get("maximum",HP))

func tick(delta: float):
	if not pads.game.multiplayer.is_server() or pads.game.match_mode.kind!="st":return
	for key in rows.size():
		if rows[key].kind=="pulse" and active(key):rows[key].energy=minf(100.0,float(rows[key].get("energy",0))+10*delta)
