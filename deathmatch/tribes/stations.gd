extends Node3D
## Fixed BSP inventory pads. The same map entities and boundary shapes are used
## by the authority, predicted clients and replay viewers.
const Health=preload("res://deathmatch/tribes/equipment_health.gd")
var game
var rows: Array=[]
var patch_markers: Array=[]
var navigation_points:=PackedVector3Array()
var repair: Dictionary={}
var supply: Dictionary={}
const GENERATOR_HP:=300.0
var generators: Array=[]
var health: Array=[GENERATOR_HP,GENERATOR_HP]
var playable_bounds:=AABB()
var power_notices: Dictionary={}
var defences=preload("res://deathmatch/tribes/fixed_defences.gd").new()
var assets=preload("res://deathmatch/tribes/base_assets.gd").new()

func configure(arena,entities: Array) -> void:
	game=arena
	for node in entities:
		var e: Dictionary=node.attributes
		if e.get("classname","")=="info_tribes_navigation":
			if navigation_points.size()<1024:navigation_points.append(node.global_position-Vector3.UP*.70)
		elif e.get("classname","")=="info_tribes_repair_patch":patch_markers.append(node.global_position-Vector3.UP*.5)
		elif e.get("classname","")=="info_playable_bounds":
			var dimensions:=str(e.get("size","")).split_floats(" ",false)
			if dimensions.size()==3 and Array(dimensions).all(func(v):return is_finite(v) and v>0 and v<=8192):
				boundary(node.global_position-Vector3.UP*.70,Vector3(dimensions[0],dimensions[1],dimensions[2]))
		elif e.get("classname","") in ["info_tribes_inventory","info_tribes_ammo","info_tribes_command","info_tribes_vehicle"] and int(e.get("team",-1)) in [0,1]:
			var row:={"team":int(e.team),"position":node.global_position-Vector3.UP*.70,"kind":str(e.classname).trim_prefix("info_tribes_")}
			row.merge(circuit(e))
			row.frame=Transform3D(Basis(Vector3.UP,deg_to_rad(float(e.get("angle",0)))),row.position)
			rows.append(row)
			fixture(row,deg_to_rad(float(e.get("angle",0))))
			if not game.headless:
				visual(row,deg_to_rad(float(e.get("angle",0))))
				var label:=Label3D.new();label.text=row.kind.to_upper();label.font_size=48;label.pixel_size=.009
				label.modulate=Color("ff9385") if row.team==0 else Color("8ebeff")
				label.outline_size=8;label.no_depth_test=false;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
				add_child(label);label.global_position=row.position+Vector3.UP*2.6
				row.label=label
		elif e.get("classname","") in ["info_tribes_generator","info_tribes_solar","info_tribes_portable_generator"] and int(e.get("team",-1)) in [0,1]:
			if generators.size()>=32:continue
			var maximum: float=Health.UNIT if e.classname=="info_tribes_solar" else 1.6*Health.UNIT if e.classname=="info_tribes_portable_generator" else GENERATOR_HP
			var primary: bool=not generators.any(func(row):return row.team==int(e.team))
			var source:={"team":int(e.team),"position":node.global_position-Vector3.UP*.70,"hp":maximum,"maximum":maximum,"primary":primary,"native":e.classname!="info_tribes_generator","key":generators.size(),"name":str(e.get("targetname","power_%d"%generators.size())).left(64)}
			source.merge(circuit(e));generators.append(source)
	rows.sort_custom(func(a,b):return a.team<b.team or a.team==b.team and a.position.x<b.position.x)
	for generator in generators:
		var center:=Vector3.ZERO;var count:=0
		for row in rows:
			if row.team==generator.team:center+=row.position;count+=1
		var forward: Vector3=(center/maxi(1,count)-generator.position);forward.y=0;forward=forward.normalized()
		if forward.length_squared()<.1:forward=Vector3.BACK
		generator["frame"]=Transform3D(Basis(Vector3.UP.cross(forward),Vector3.UP,forward),generator.position+Vector3.UP*1.45)
		if generator.native:
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;add_child(body);body.global_transform=generator.frame
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5.8,2.8,2);shape.shape=box;body.add_child(shape)
			if not game.headless:
				var art=preload("res://deathmatch/art.gd");art.box(body,Vector3.ZERO,box.size,art.material(Color("334654"),.6))
				for x in [-2,-1,0,1,2]:art.box(body,Vector3(x,0,1.02),Vector3(.86,2.4,.04),art.material(Color("325e87"),.65))
		generator["repair_position"]=generator.frame*Vector3(5,-1.45,4)
		if not game.headless:
			var rack=preload("res://deathmatch/tribes/equipment.gd").model("pack",generator.team)
			add_child(rack);rack.global_position=generator.repair_position+Vector3.UP*.8; rack.scale=Vector3.ONE*3
			var sign:=Label3D.new();sign.text="EMERGENCY REPAIR PACK";sign.font_size=30;sign.pixel_size=.006;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			add_child(sign);sign.global_position=generator.repair_position+Vector3.UP*1.5
			var lamp:=preload("res://deathmatch/art.gd").box(self,Vector3.ZERO,Vector3(4.8,.55,.06),preload("res://deathmatch/art.gd").material(Color("65dfa6"),.4,1.0))
			lamp.global_transform=generator.frame*Transform3D(Basis.IDENTITY,Vector3(0,0,1.06));generator["lamp"]=lamp
			var label:=Label3D.new();label.font_size=36;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			add_child(label);label.global_position=generator.position+Vector3.UP*3.4;generator["label"]=label
	assets.setup(self,entities);defences.setup(self,entities)

static func circuit(e: Dictionary) -> Dictionary:
	return {"power_group":str(e.get("power_group","base")).left(64),"power_sources":str(e.get("power_sources","")).left(512).split(",",false)}
func source_hp(row: Dictionary) -> float:return health[row.team] if row.primary else row.hp
func source_active(row: Dictionary) -> bool:return Health.enabled(source_hp(row),row.maximum)
func connected(row: Dictionary) -> bool:
	if game.match_mode.kind!="st":return true
	for source in generators:
		if source.team!=row.team or not source_active(source):continue
		if not row.get("power_sources",[]).is_empty():
			if source.name in row.power_sources:return true
		elif source.power_group==row.get("power_group","base"):return true
	return false
func reset() -> void:
	health=[GENERATOR_HP,GENERATOR_HP];repair.clear();supply.clear();power_notices.clear();assets.reset();defences.reset()
	for row in generators:
		row.hp=row.maximum
		if row.primary:health[row.team]=row.maximum
func powered(team: int) -> bool:
	return game.match_mode.kind!="st" or team not in [0,1] or connected({"team":team})
func trace(hit: Dictionary) -> Dictionary:
	if game.match_mode.kind!="st" or not hit.hit or hit.id!=0 or hit.has("beacon") or hit.has("deployable"):return hit
	for row in generators:
		var local: Vector3=row.frame.affine_inverse()*hit.position
		# Existing BSP generator housing remains the collision and cover geometry.
		if absf(local.x)<=3.2 and absf(local.y)<=1.6 and local.z>=-2.2 and local.z<=1.2:
			hit["generator"]=row.team;hit["power_source"]=row.key;break
	return defences.trace(assets.trace(hit))
func damage(team: int,attacker: int,amount: float) -> void:
	for row in generators:
		if row.team==team:damage_source(row.key,attacker,amount);return
func damage_source(key: int,attacker: int,amount: float) -> void:
	if not multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=generators.size() or not is_finite(amount) or amount<=0:return
	var row: Dictionary=generators[key]
	if game.players.get(attacker,{}).get("team",-1)==row.team and not game.match_mode.friendly_fire:return
	var before:=powered(row.team);row.hp=source_hp(row);Health.hit(row,row.maximum,amount,false)
	if row.primary:health[row.team]=row.hp
	if before!=powered(row.team):power_notice(row.team,powered(row.team))
func restore(team: int,id: int,amount: float) -> bool:
	for row in generators:
		if row.team==team:return restore_source(row.key,id,amount)
	return false
func restore_source(key: int,id: int,amount: float) -> bool:
	if not multiplayer.is_server() or game.match_mode.kind!="st" or key<0 or key>=generators.size() or not is_finite(amount) or amount<=0:return false
	var row: Dictionary=generators[key]
	if game.players.get(id,{}).get("team",-1)!=row.team:return false
	var power_before:=powered(row.team);var before:=source_hp(row);row.hp=minf(row.maximum,before+amount)
	if row.primary:health[row.team]=row.hp
	if power_before!=powered(row.team):power_notice(row.team,powered(row.team))
	return row.hp>before
func power_notice(team: int,active: bool) -> void:
	var key:=str(team)+str(active)
	if game.clock<float(power_notices.get(key,-1)):return
	power_notices[key]=game.clock+8
	game._announcement.rpc(game.match_mode.TEAMS[team]+" base power "+("restored" if active else "disabled"))
func blast(where: Vector3,attacker: int,amount: float,radius: float,source_team: int=-1,family: String="") -> void:
	if game.match_mode.kind!="st":return
	assets.blast(where,attacker,amount,radius,source_team,family)
	defences.blast(where,attacker,amount,radius,source_team,family)
	for row in generators:
		if row.team==source_team and not game.match_mode.friendly_fire:continue
		var end: Vector3=row.frame.origin
		var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where,end,1))
		if ray.is_empty():continue
		var contact:=trace({"position":ray.position,"id":0,"hit":true})
		if contact.get("power_source",-1)!=row.key:continue
		var distance: float=where.distance_to(ray.position)
		if distance<radius:damage_source(row.key,attacker,amount*(1-distance/radius))
func _process(_delta: float) -> void:
	assets.update();defences.update()
	for row in generators:
		if not row.has("lamp"):continue
		var active: bool=source_active(row)
		row.lamp.material_override.albedo_color=Color("65dfa6") if active else Color("b52320")
		row.lamp.material_override.emission=Color("65dfa6") if active else Color("b52320")
		row.lamp.material_override.emission_energy_multiplier=1.0 if active else .15
		row.label.text="GENERATOR · %d%%"%roundi(source_hp(row)/row.maximum*100) if active else "GENERATOR · OFFLINE"

func fixture(row: Dictionary,yaw: float) -> void:
	var body:=StaticBody3D.new();body.name="InventoryStation";body.collision_layer=1;body.collision_mask=0
	for part in [[Vector3(-1.65,1.5,1.7),Vector3(.32,3,.6)],[Vector3(1.65,1.5,1.7),Vector3(.32,3,.6)],[Vector3(0,2.4,1.87),Vector3(2.4,1,.5)]]:
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=part[1];shape.shape=box;shape.position=part[0];body.add_child(shape)
	add_child(body);body.global_transform=Transform3D(Basis(Vector3.UP,yaw),row.position)

func visual(row: Dictionary,yaw: float) -> void:
	var mesh:=ArrayMesh.new()
	var colors: Array=[Color("414953"),Color("e75443") if row.team==0 else Color("438de7"),Color("101c24")]
	var parts: Array=[
		[[Vector3(0,-.025,0),Vector3(2.9,.04,2.9)],[Vector3(-1.65,1.5,1.7),Vector3(.32,3,.6)],[Vector3(1.65,1.5,1.7),Vector3(.32,3,.6)]],
		[[Vector3(-1.65,1.9,1.37),Vector3(.20,1.7,.05)],[Vector3(1.65,1.9,1.37),Vector3(.20,1.7,.05)],[Vector3(0,2.4,1.57),Vector3(2.1,.6,.05)]],
		[[Vector3(0,2.4,1.87),Vector3(2.4,1,.5)]]]
	for i in 3:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts[i]:
			var box:=BoxMesh.new();box.size=part[1]
			surface.append_from(box,0,Transform3D(Basis.IDENTITY,part[0]))
		var material:=StandardMaterial3D.new();material.albedo_color=colors[i];material.metallic=.55;material.roughness=.7
		surface.set_material(material);surface.commit(mesh)
	var node:=MeshInstance3D.new();node.mesh=mesh;add_child(node)
	node.global_transform=Transform3D(Basis(Vector3.UP,yaw),row.position)
	row.visual=node

func boundary(center: Vector3,size: Vector3) -> void:
	playable_bounds=AABB(center-size*.5,size)
	# Sky triangles are intentionally omitted by the BSP importer. Use closed
	# solid slabs just inside the sampled terrain, including a jet ceiling.
	for axis in 3:
		for direction in [-1,1]:
			var body:=StaticBody3D.new();body.name="Boundary%d_%d"%[axis,direction];body.collision_layer=1;body.collision_mask=0
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size+Vector3.ONE*8;box.size[axis]=4
			shape.shape=box;body.add_child(shape);add_child(body)
			body.global_position=center;body.global_position[axis]+=direction*(size[axis]*.5+2)

func at(id: int,kinds: Array=["inventory"]) -> int:
	if not game.players.has(id) or not game.fighters.has(id):return -1
	var p: Vector3=game.fighters[id].global_position;var team: int=game.players[id].team
	for i in rows.size():
		var row: Dictionary=rows[i];var offset: Vector3=p-row.position
		if row.kind not in kinds or row.team!=team or not connected(row) or game.match_mode.kind=="st" and not assets.active(row.asset) or absf(offset.y)>.9 or Vector2(offset.x,offset.z).length()>1.5:continue
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.9,row.position+Vector3.UP*.9,1)
		if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return i
	return -1

func tick(rules,delta: float) -> void:
	defences.tick(delta);assets.tick(delta)
	if rows.is_empty():return
	for id in game.players:
		if game.match_mode.kind=="st":recover_pack(id)
		if not rules.recovery.eligible(id) or at(id,["inventory","ammo"])<0:repair.erase(id);supply.erase(id);continue
		var s: Dictionary=game.players[id];var account: int=rules.bank(id)
		# Native inventory stations service users while they remain on the pad.
		# Fractional accumulation keeps healing independent of server tick rate.
		if at(id)>=0 and rules.balance(id)>0 and s.hp<rules.definition(id).hp:
			repair[id]=float(repair.get(id,0.0))+delta*8.0
			var amount: int=mini(int(repair[id]),rules.definition(id).hp-s.hp)
			s.hp+=amount;repair[id]-=amount
		else:repair.erase(id)
		supply[id]=float(supply.get(id,0.0))+delta
		if supply[id]<.5:continue
		supply[id]=fmod(supply[id],.5)
		for w in [1,2,3,4,7,9,10]:
			if w not in s.owned:continue
			var count: int=mini(rules.Arsenal.capacity(s.tribes_class,s.tribes_pack,w)-s.tribes_ammo[w],20 if w==2 else 5 if w==1 else 2)
			var price: int=rules.Arsenal.AMMO_PRICE[w]
			count=mini(count,int(rules.balance(id)/price))
			if count<=0:continue
			s.tribes_ammo[w]+=count;rules.spend(id,count*price);s.tribes_paid=mini(rules.MAX_TEAM_ENERGY,s.tribes_paid+count*price)
		if not s.tribes_kit and rules.balance(id)>=35:
			s.tribes_kit=true;s.tribes_paid=mini(rules.MAX_TEAM_ENERGY,s.tribes_paid+35);rules.spend(id,35)

func recover_pack(id: int) -> bool:
	# A powerless base must remain repairable after its last repairer dies.
	# This fixed, power-independent rack has no trade-in value and replaces
	# only an empty backpack. It uses the normal personal-energy repair gun.
	if not multiplayer.is_server() or game.match_mode.kind!="st" or not game.players.has(id) or not game.fighters.has(id) or game.intermission>0:return false
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or s.get("input_blocked",false) or s.get("tribes_pack","none")!="none":return false
	for row in generators:
		if row.team!=s.team or game.fighters[id].position.distance_to(row.repair_position)>1.25:continue
		if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.fighters[id].position+Vector3.UP,row.repair_position+Vector3.UP,1)).is_empty():continue
		s.tribes_pack="repair";s.owned.append(8);game.fighters[id].tribes_state.pack="repair";game.fighters[id].tribes_state.pack_on=false
		return true
	return false

func power_snapshot() -> Dictionary:
	return {"sources":generators.map(func(row):return source_hp(row)),"shields":assets.rows.map(func(row):return row.get("energy",0.0))}
static func valid_power(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2 or not data.get("sources") is Array or data.sources.size()>32 or not data.get("shields") is Array or data.shields.size()>128:return false
	for value in data.sources+data.shields:
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>300:return false
	return true
func receive_power(data: Dictionary):
	if not valid_power(data) or data.sources.size()!=generators.size() or data.shields.size()!=assets.rows.size():return
	for key in generators.size():
		if data.sources[key]>generators[key].maximum:return
	for key in assets.rows.size():
		if data.shields[key]>(100 if assets.rows[key].kind=="pulse" else 0):return
	for key in generators.size():
		generators[key].hp=data.sources[key]
		if generators[key].primary:health[generators[key].team]=data.sources[key]
	for key in assets.rows.size():assets.rows[key].energy=data.shields[key]
