extends RefCounted
## Server-authoritative DE utility. Separate equipment slots preserve gun IDs.
const ITEMS=[110,111,112]
const NAMES=["HE GRENADE","FLASHBANG","SMOKE GRENADE"]
const LIMITS=[1,2,1]
const PRICES=[300,200,300]
const FUSE=1.5
const SMOKE_TIME=20.0
const SMOKE_RADIUS=3.6
const GRAVITY=12.5 # GoldSrc 800 * grenade gravity .5 / 32, approximately.
var rules_ref: WeakRef
var rules:
	get:return rules_ref.get_ref()
var game:
	get:return rules.game
var states: Dictionary={}
var flying: Dictionary={}
var clouds: Dictionary={}
var flashes: Dictionary={}
var next_id:=0
var visual
func setup(value):rules_ref=weakref(value)
func state(id: int) -> Dictionary:
	if not states.has(id):states[id]={"counts":[0,0,0],"selected":-1,"shoulder":-1,"primed":false,"pressed":false,"ready":0.0,"release":false,"weapon":-1,"hand":Vector3.ZERO,"hand_time":-1.0,"velocity":Vector3.ZERO,"cooldown":0.0}
	return states[id]
func selected(id: int) -> int:return int(states.get(id,{}).get("selected",-1)) if rules.enabled() else -1
func shoulder_selected(id: int) -> int:
	var u:=state(id);var kind: int=u.shoulder
	if kind>=0 and u.counts[kind]>0:return kind
	for k in 3:
		if u.counts[k]>0:return k
	return -1
func select_shoulder(id: int,kind: int) -> bool:
	if not rules.enabled() or not rules.alive(id) or rules.phase!="live" or kind not in [-1,0,1,2] or game.intermission>0 or state(id).primed or rules.busy(id):return false
	if kind>=0 and state(id).counts[kind]<=0:return false
	cancel(id);state(id).shoulder=kind
	return true
func reset():
	states.clear();flying.clear();clouds.clear();flashes.clear();next_id=0;clear_visuals()
func clear_visuals():
	if is_instance_valid(visual):visual.queue_free()
	visual=null
func new_round():
	flying.clear();clouds.clear();flashes.clear()
	for id in states:cancel(id)
func cancel(id: int):
	var s:=state(id);s.selected=-1;s.primed=false;s.pressed=false;s.release=false;s.hand_time=-1.0;s.velocity=Vector3.ZERO
	s.offhand=false;s.until=0.0
func buy(id: int,kind: int) -> bool:
	if kind<0 or kind>2 or state(id).counts[kind]>=LIMITS[kind]:return false
	state(id).counts[kind]+=1;return true
func equip(id: int,kind: int) -> bool:
	if game.players.get(id,{}).get("vr_device",false) and game.players[id].get("physical",false):return select_shoulder(id,kind)
	return equip_hand(id,kind)
func equip_hand(id: int,kind: int) -> bool:
	if not rules.enabled() or not rules.alive(id) or rules.phase!="live" or kind not in [-1,0,1,2] or game.intermission>0:return false
	if kind>=0 and (state(id).counts[kind]<=0 or rules.busy(id)):return false
	cancel(id);var s:=state(id);s.selected=kind;s.weapon=game.players[id].weapon
	return true
func inventory(id: int) -> Array:
	var rows: Array=[]
	if not rules.enabled():return rows
	for kind in 3:
		if state(id).counts[kind]>0:rows.append({"id":ITEMS[kind],"name":NAMES[kind],"ammo":state(id).counts[kind],"usable":true})
	return rows
func cycle(id: int,direction: int) -> bool:
	if direction not in [-1,1] or state(id).primed:return false
	var current: int=int(state(id).shoulder)
	if current<0:current=-1 if direction>0 else 0
	for offset in range(1,4):
		var kind: int=posmod(current+direction*offset,3)
		if state(id).counts[kind]>0:return select_shoulder(id,kind)
	return false
func origin(id: int) -> Vector3:
	var s: Dictionary=game.players[id]
	if not s.xr.is_empty():return (rules.base_pose(id)*rules.Interaction.primary(s.xr)).origin
	return game.fighters[id].position+Vector3.UP*game.fighters[id].eye_height()
func sample_player(id: int):
	var u:=state(id);var s: Dictionary=game.players[id]
	if selected(id)<0:return
	if not rules.alive(id) or rules.phase!="live" or rules.busy(id) or s.input_blocked or game.clock-s.last_input>.35 or s.weapon!=u.weapon or s.vr_device and s.xr.is_empty():
		cancel(id);return
	if u.get("offhand",false):
		if game.clock>u.until or s.xr.get("left_handed",false)!=u.left_handed:cancel(id)
		return
	if s.vr_device and s.get("physical",false):return
	var at:=origin(id)
	if u.hand_time>=0 and game.clock>u.hand_time:
		var elapsed: float=game.clock-u.hand_time
		if elapsed<.2:u.velocity=u.velocity.lerp(((at-u.hand)/elapsed).limit_length(12),.5)
	u.hand=at;u.hand_time=game.clock
	var pressed: bool=s.get("de_trigger",false) if s.vr_device else s.fire
	if pressed and not u.pressed and not u.primed and game.clock>=u.cooldown:u.primed=true;u.ready=game.clock+.5
	if not pressed and u.pressed and u.primed:u.release=true
	u.pressed=pressed
	if u.primed and u.release and game.clock>=u.ready:throw_grenade(id)
func physical_request(id: int,action: String,pose: Dictionary,velocity: Vector3) -> bool:
	if action=="cancel":cancel(id);return true
	if not rules.enabled() or not rules.alive(id) or rules.phase!="live" or rules.busy(id) or pose.is_empty() or not velocity.is_finite():cancel(id);return false
	var s: Dictionary=game.players[id];var u:=state(id)
	if s.input_blocked or game.clock-s.last_input>.35 or game.clock<u.cooldown:cancel(id);return false
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	var at: Vector3=rules.base_pose(id)*hand.origin
	var chest: Vector3=game.fighters[id].position+Vector3.UP*game.fighters[id].torso_height()
	if not rules.ray_surface(chest,at).is_empty():cancel(id);return false
	if action=="arm":
		if u.primed:return false
		var kind: int=shoulder_selected(id)
		if not equip_hand(id,kind) or kind<0:return false
		u.offhand=true;u.primed=true;u.until=game.clock+10;u.left_handed=pose.left_handed
		return true
	if action=="throw":
		if not u.get("offhand",false) or not u.primed or game.clock>u.until or pose.left_handed!=u.left_handed:cancel(id);return false
		var launched: Vector3=rules.base_pose(id).basis*preload("res://deathmatch/vr/throw_ballistics.gd").guided(pose,velocity)
		var success:=throw_grenade(id,launched,pose)
		if not success:cancel(id)
		return success
	return false
func throw_grenade(id: int,override_velocity: Variant=null,physical_pose: Dictionary={}) -> bool:
	var u:=state(id);var kind: int=u.selected
	if not rules.alive(id) or rules.phase!="live" or rules.busy(id) or kind<0 or kind>2 or u.counts[kind]<=0 or game.clock<u.cooldown:return false
	var s: Dictionary=game.players[id];var from:=origin(id)
	if not physical_pose.is_empty():from=rules.base_pose(id)*(physical_pose.right.origin if physical_pose.left_handed else physical_pose.left.origin)
	var direction: Vector3=game.W.direction(s.yaw,s.pitch)
	var velocity: Vector3
	if override_velocity is Vector3:
		velocity=override_velocity.limit_length(26)
		if velocity.length()>.1:direction=velocity.normalized()
	elif not s.xr.is_empty():
		direction=-(rules.base_pose(id)*rules.Interaction.primary(s.xr)).basis.z
		velocity=u.velocity.limit_length(12)+direction*3+game.fighters[id].velocity.limit_length(9)
	else:
		var pitch: float=clampf(s.pitch+.17,-1.5,1.5)
		direction=game.W.direction(s.yaw,pitch)
		velocity=direction*minf(23.4375,18.75+pitch*10)+game.fighters[id].velocity.limit_length(9)
	# Never accept a spawn through nearby geometry or a client-provided position.
	var eye: Vector3=game.fighters[id].position+Vector3.UP*game.fighters[id].eye_height()
	if not rules.ray_surface(eye,from).is_empty():return false
	var wall: Dictionary=rules.ray_surface(from,from+direction*.25)
	var pos: Vector3=wall.position+wall.normal*.07 if not wall.is_empty() else from+direction*.18
	u.counts[kind]-=1;u.cooldown=game.clock+.6;cancel(id)
	next_id+=1;flying[next_id]={"kind":kind,"owner":id,"position":pos,"velocity":velocity.limit_length(28),"age":0.0,"ground":false}
	game.server_log.record("de_grenade",{"peer":id,"kind":NAMES[kind],"round":rules.round_id},1)
	return true
func tick(delta: float):
	if not rules.enabled() or not game.multiplayer.is_server():return
	for id in states.keys():
		if not game.players.has(id):states.erase(id)
	for id in flashes.keys():
		if not rules.alive(id) or flashes[id].end<=game.clock:flashes.erase(id)
	for id in clouds.keys():
		clouds[id].age+=delta
		if clouds[id].age>=SMOKE_TIME:clouds.erase(id)
	if rules.phase!="live":return
	for id in flying.keys():
		var p: Dictionary=flying[id];p.age+=delta
		if not p.ground:
			var steps: int=maxi(1,ceili(p.velocity.length()*delta/.08));var dt: float=delta/steps
			for step in mini(steps,32):
				p.velocity.y-=GRAVITY*dt
				var end: Vector3=p.position+p.velocity*dt
				var ray: Dictionary=rules.ray_surface(p.position,end+p.velocity.normalized()*.06)
				if not ray.is_empty():
					p.position=ray.position+ray.normal*.065;p.velocity=p.velocity.bounce(ray.normal)*.45
					if ray.normal.y>.65 and p.velocity.length()<1.0:p.velocity=Vector3.ZERO;p.ground=true;break
				else:p.position=end
		if p.position.y<game.fall_limit-2 or p.age>12:flying.erase(id);continue
		if p.age>=FUSE and (p.kind!=2 or p.ground):detonate(id)
func detonate(id: int):
	if not flying.has(id):return
	var p: Dictionary=flying[id];flying.erase(id)
	if p.kind==2:clouds[id]={"position":p.position+Vector3.UP*.8,"age":0.0};return
	if p.kind==0:
		preload("res://deathmatch/effects/surface_marks.gd").blast(game,p.position,{"name":"HE GRENADE","splash":100,"blast_radius":1.8})
		for victim in game.players:
			if not rules.alive(victim):continue
			var target: Vector3=game.fighters[victim].position+Vector3.UP*.9
			var distance: float=target.distance_to(p.position);var radius:=350.0/32
			if distance>=radius:continue
			# Geometry shields players; damage follows the project's armor/FF rules.
			if not rules.ray_surface(p.position,target).is_empty():continue
			game._damage(victim,p.owner,roundi(100*(1-distance/radius)),"HE GRENADE",true,p.position,(target-p.position).normalized())
		game._de_grenade_fx.rpc(p.position,0)
	else:
		for victim in game.players:
			if not rules.alive(victim):continue
			var s: Dictionary=game.players[victim]
			var eye: Vector3=game.fighters[victim].position+Vector3.UP*game.fighters[victim].eye_height()
			var facing: Vector3=game.W.direction(s.yaw,s.pitch)
			if not s.xr.is_empty():
				var head: Transform3D=rules.base_pose(victim)*s.xr.head;eye=head.origin;facing=-head.basis.z
			var distance: float=eye.distance_to(p.position)
			if distance>=1500.0/32 or not rules.ray_surface(p.position,eye).is_empty():continue
			var strength: float=4*(1-distance/(1500.0/32));var front: bool=facing.dot(p.position-eye)>=0
			var hold: float=strength/(1.5 if front else 3.5);var fade: float=strength*(3 if front else 1.75)
			if flashes.has(victim) and front:hold+=maxf(0,flashes[victim].hold-game.clock)
			flashes[victim]={"hold":game.clock+minf(hold,6),"end":game.clock+minf(hold,6)+fade,"alpha":1.0 if front else 200.0/255,"serial":s.serial}
		game._de_grenade_fx.rpc(p.position,1)
func flash_amount(id: int) -> float:
	if not rules.enabled() or not rules.alive(id) or not flashes.has(id) or flashes[id].serial!=game.players[id].serial:return 0
	var f: Dictionary=flashes[id]
	return f.alpha*clampf((f.end-game.clock)/maxf(.001,f.end-f.hold),0,1)
static func cloud_radius(age: float) -> float:return SMOKE_RADIUS*clampf(age/1.0,0,1)
static func cloud_density(age: float) -> float:return clampf(age/.7,0,1)*clampf((SMOKE_TIME-age)/3,0,1)
func obscured(start: Vector3,end: Vector3) -> bool:
	if not rules.enabled():return false
	for c in clouds.values():
		if cloud_density(c.age)<.5:continue
		var radius:=cloud_radius(c.age)
		var delta:=end-start;var t:=clampf((c.position-start).dot(delta)/maxf(.001,delta.length_squared()),0,1)
		if (start+delta*t).distance_to(c.position)<radius:return true
	return false
func smoke_amount(at: Vector3) -> float:
	var result:=0.0
	for c in clouds.values():result=maxf(result,clampf((cloud_radius(c.age)-at.distance_to(c.position))*1.7,0,.985)*cloud_density(c.age))
	return result
func on_death(id: int):
	cancel(id);state(id).counts=[0,0,0];flashes.erase(id)
func bot_combat(id: int,brain: Dictionary) -> bool:
	if not rules.enabled() or rules.phase!="live":return false
	if flash_amount(id)>.35:return true
	if brain.enemy==0 or not rules.alive(brain.enemy):return false
	var target: Vector3=game.fighters[brain.enemy].position+Vector3.UP*.7
	var from:=origin(id);var distance:=from.distance_to(target)
	if obscured(from,target):return true
	if game.clock<maxf(float(state(id).cooldown),float(brain.get("utility_at",0))) or rules.busy(id):return false
	if distance<7 or distance>22 or not rules.ray_surface(from,target).is_empty():return false
	if game.players.keys().any(func(peer):return peer!=id and rules.alive(peer) and rules.mode.same_team(peer,id) and game.fighters[peer].position.distance_to(target)<7):return false
	var counts: Array=state(id).counts;var kind:=0 if counts[0]>0 else 1 if counts[1]>0 else 2 if counts[2]>0 else -1
	if kind<0:return false
	if not game.bots.action("de_equip",[id,kind]):return false
	var time: float=clampf(distance/17,.5,1.3)
	var velocity: Vector3=(target-from)/time+Vector3.UP*GRAVITY*time*.5
	var thrown: bool=game.bots.action("de_throw",[id,velocity])
	if thrown:state(id).cooldown=game.clock+8;brain.utility_at=game.clock+8
	else:game.bots.action("de_cancel",[id])
	return thrown
func snapshot() -> Dictionary:
	var inventory: Dictionary={};var shots: Array=[];var smoke: Array=[];var blind: Dictionary={}
	for id in states:
		if game.players.has(id):inventory[id]=[state(id).counts.duplicate(),selected(id),state(id).primed,state(id).get("offhand",false),int(state(id).shoulder)]
	for id in flying:
		var p: Dictionary=flying[id];shots.append([id,p.kind,p.owner,p.position,p.velocity,p.age,p.ground])
	for id in clouds:smoke.append([id,clouds[id].position,clouds[id].age])
	for id in flashes:
		var f: Dictionary=flashes[id];blind[id]=[maxf(0,f.hold-game.clock),maxf(0,f.end-game.clock),f.alpha,f.serial]
	return {"inventory":inventory,"shots":shots,"smoke":smoke,"blind":blind}
func receive(data: Dictionary):
	if not valid_snapshot(data):return
	states.clear();flying.clear();clouds.clear();flashes.clear()
	for id in data.get("inventory",{}):
		var row: Array=data.inventory[id];state(id).counts=row[0];state(id).selected=row[1];state(id).primed=row[2]
		state(id).offhand=row[3] if row.size()>3 else false
		state(id).shoulder=row[4] if row.size()>4 else -1
	for row in data.get("shots",[]):flying[row[0]]={"kind":row[1],"owner":row[2],"position":row[3],"velocity":row[4],"age":row[5],"ground":row[6]}
	for row in data.get("smoke",[]):clouds[row[0]]={"position":row[1],"age":row[2]}
	for id in data.get("blind",{}):
		var row: Array=data.blind[id];flashes[id]={"hold":game.clock+row[0],"end":game.clock+row[1],"alpha":row[2],"serial":row[3]}
static func number(v: Variant,low: float,high: float) -> bool:return (v is float or v is int) and is_finite(float(v)) and v>=low and v<=high
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary:return false
	if data.is_empty():return true
	if not data.get("inventory") is Dictionary or data.inventory.size()>32 or not data.get("shots") is Array or data.shots.size()>128 or not data.get("smoke") is Array or data.smoke.size()>32 or not data.get("blind") is Dictionary or data.blind.size()>32:return false
	for id in data.inventory:
		var row=data.inventory[id]
		if not id is int or not row is Array or row.size() not in [3,4,5] or not row[0] is Array or row[0].size()!=3 or not row[1] is int or row[1] not in [-1,0,1,2] or not row[2] is bool:return false
		if row.size()>=4 and not row[3] is bool:return false
		if row.size()==5 and (not row[4] is int or row[4] not in [-1,0,1,2]):return false
		for k in 3:
			if not row[0][k] is int or row[0][k]<0 or row[0][k]>LIMITS[k]:return false
	for row in data.shots:
		if not row is Array or row.size()!=7 or not row[0] is int or row[0]<1 or not row[1] is int or row[1] not in [0,1,2] or not row[2] is int or not row[3] is Vector3 or not row[3].is_finite() or not row[4] is Vector3 or not row[4].is_finite() or row[4].length()>100 or not number(row[5],0,12.1) or not row[6] is bool:return false
	for row in data.smoke:
		if not row is Array or row.size()!=3 or not row[0] is int or row[0]<1 or not row[1] is Vector3 or not row[1].is_finite() or not number(row[2],0,20.1):return false
	for id in data.blind:
		var row=data.blind[id]
		if not id is int or not row is Array or row.size()!=4 or not number(row[0],0,6.1) or not number(row[1],0,18.1) or not number(row[2],0,1) or not row[3] is int:return false
	return true
func draw():
	if game.headless:return
	if not rules.enabled():clear_visuals();return
	if not is_instance_valid(visual):visual=load("res://deathmatch/counterstrike/grenade_visuals.gd").new();game.add_child(visual);visual.setup(self)
	visual.update()
