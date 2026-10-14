extends Node3D
## No colliders: only explicitly classified energy rays interact with this field.
const RADIUS:=5.0
const HEALTH:=500
const ENERGY:=500.0
const SECONDS:=10.0
const RATE:=10.0
var game
var fields:Dictionary={}
var credits:Dictionary={}
var next_id:=0
var cursor:=0
var next_heal:=0.0
var heal_delta:=0.0
var visual:MultiMeshInstance3D
func setup(arena) -> void:game=arena
func activate(owner:int,position:Vector3,team:int) -> bool:
	if not game.multiplayer.is_server() or not position.is_finite() or team not in [0,1] or game.intermission>0 or game.lobby.active():return false
	next_id+=1;fields[next_id]={"owner":owner,"team":team,"position":position+Vector3.UP*.1,"health":HEALTH,"energy":ENERGY,"until":game.clock+SECONDS,"xp_credit":0.0,"hit_at":-100.0}
	return true
func tick(delta:float) -> void:
	if not game.multiplayer.is_server():return
	for key in fields.keys():
		if fields[key].until<=game.clock or fields[key].energy<=0:fields.erase(key)
	if fields.is_empty():credits.clear();heal_delta=0;return
	heal_delta+=maxf(0,delta)
	if game.clock<next_heal:return
	next_heal=game.clock+.1;var elapsed:=heal_delta;heal_delta=0.0
	var eligible:Dictionary={}
	for key in fields.keys():
		var row:Dictionary=fields[key]
		if row.until<=game.clock or row.energy<=0:fields.erase(key);continue
		if row.health<=0:continue
		var targets:Array=[]
		for id in game.players:
			if not game.classes.alive(id) or game.players[id].team!=row.team or game.players[id].hp>=100:continue
			var chest:Vector3=game.fighters[id].position+Vector3.UP*minf(.8,game.fighters[id].collision_height*.5)
			if chest.distance_squared_to(row.position)>RADIUS*RADIUS or not game.grenade_adapter.ray_surface(row.position,chest).is_empty():continue
			targets.append(id);eligible[Vector2i(key,id)]=true
		targets.sort()
		# Rotate allocation order when several wounded allies exhaust the shared pool.
		for i in targets.size():
			var id:int=targets[(i+cursor)%targets.size()];var token:=Vector2i(key,id)
			credits[token]=minf(100,float(credits.get(token,0))+elapsed*RATE)
			var amount:int=mini(mini(int(credits[token]),row.health),100-game.players[id].hp)
			if amount<=0:continue
			game.players[id].hp+=amount;row.health-=amount;credits[token]-=amount
			if id!=row.owner:
				row.xp_credit+=amount;var xp:int=int(row.xp_credit/10);row.xp_credit-=xp*10
				if game.classes.role(row.owner)=="medic":game.classes.award(row.owner,xp)
	cursor+=1
	for token in credits.keys():
		if not eligible.has(token):credits.erase(token)
static func boundary(start:Vector3,end:Vector3,center:Vector3) -> float:
	var d:=end-start;var a:=d.length_squared()
	if a<.000001:return INF
	var offset:=start-center;var b:=2*offset.dot(d);var c:=offset.length_squared()-RADIUS*RADIUS;var disc:=b*b-4*a*c
	if disc<0:return INF
	var near:float=(-b-sqrt(disc))/(2*a);var far:float=(-b+sqrt(disc))/(2*a)
	var t:float=near if near>=0 else far
	return t if t>=0 and t<=1 else INF
func intercept(owner:int,start:Vector3,end:Vector3,damage:float,energy_ray:bool) -> Dictionary:
	var result:Dictionary={"damage":damage,"position":end,"absorbed":0.0}
	if not energy_ray or not game.multiplayer.is_server() or damage<=0:return result
	var hits:Array=[];var team:int=game.players.get(owner,{}).get("team",-1)
	for key in fields:
		var row:Dictionary=fields[key]
		if row.energy<=0 or row.until<=game.clock:continue
		if team==row.team and start.distance_squared_to(row.position)<=RADIUS*RADIUS:continue
		var t:=boundary(start,end,row.position)
		if is_finite(t):hits.append({"key":key,"t":t})
	hits.sort_custom(func(a,b):return a.t<b.t)
	for hit in hits:
		var row:Dictionary=fields[hit.key];var absorbed:float=minf(result.damage,row.energy)
		row.energy-=absorbed;row.hit_at=game.clock;result.damage-=absorbed;result.absorbed+=absorbed
		if row.energy<=0:fields.erase(hit.key) # Break ends both regeneration and shielding.
		if result.damage<=0:result.position=start.lerp(end,hit.t);break
	return result
func receive(rows:Dictionary,offset:float) -> void:
	fields=rows.duplicate(true)
	for row in fields.values():row.until+=offset;row.hit_at+=offset
func draw() -> void:
	if game.headless:return
	if not is_instance_valid(visual):
		visual=MultiMeshInstance3D.new();visual.name="HealingShields";visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.multimesh=MultiMesh.new();visual.multimesh.transform_format=MultiMesh.TRANSFORM_3D;visual.multimesh.use_custom_data=true
		var mesh:=SphereMesh.new();mesh.radius=RADIUS;mesh.height=RADIUS*2;mesh.radial_segments=32;mesh.rings=12
		var material:=ShaderMaterial.new();material.shader=preload("res://deathmatch/conquest/classes/healing_field.gdshader");mesh.material=material;visual.multimesh.mesh=mesh;add_child(visual)
	var active:Array=fields.values().filter(func(row):return row.until>game.clock and row.energy>0)
	if visual.multimesh.instance_count!=active.size():visual.multimesh.instance_count=active.size()
	for i in active.size():
		var row:Dictionary=active[i];visual.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,row.position))
		visual.multimesh.set_instance_custom_data(i,Color(row.energy/ENERGY,row.health/float(HEALTH),clampf(1-(game.clock-row.hit_at)/.25,0,1),row.team))
func _process(_delta:float) -> void:
	if game and game.active:draw()
func reset() -> void:
	fields.clear();credits.clear();heal_delta=0.0;next_heal=0.0
	if is_instance_valid(visual):visual.multimesh.instance_count=0
