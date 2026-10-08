extends RefCounted
## Server-owned CS economy and single-life rounds, with Pavlov-style fictional
## keypad arming/defusing and spatial cutter contacts. Clients only mirror state.
const Arsenal=preload("res://deathmatch/counterstrike/arsenal.gd")
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
const Interaction=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
const MAP=Maps.DEFAULT
const PRICES={1:400,2:500,3:1700,4:3000,5:1500,6:2500,7:3100,8:5750,9:4750,10:650,11:2350,100:650,101:1000,102:200,103:60,104:60,110:300,111:200,112:300}
const GEAR={100:"KEVLAR",101:"VEST + HELMET",102:"DEFUSE CUTTERS",103:"PRIMARY AMMO",104:"PISTOL AMMO",110:"HE GRENADE",111:"FLASHBANG",112:"SMOKE GRENADE"}
const PISTOLS=[1,2,10]
var utility=preload("res://deathmatch/counterstrike/grenades.gd").new()
var mode_ref: WeakRef
var mode:
	get:return mode_ref.get_ref()
var game:
	get:return mode.game
var phase:="waiting"
var round_id:=0
var attacking:=0
var phase_end:=0.0
var prepare_seconds:=15.0
var round_seconds:=120.0
var fuse_seconds:=45.0
var win_limit:=16
var halftime_done:=false
var losses: Array=[0,0]
var accounts: Dictionary={}
var input_edges: Dictionary={}
var action_sequences: Dictionary={}
var bot_times: Dictionary={}
var tactics=preload("res://deathmatch/bot_ai/defusal.gd").new()
var carrier:=0
var held:=false
var planted:=false
var bomb_position:=Vector3.ZERO
var bomb_basis:=Basis.IDENTITY
var planted_site:=-1
var fuse_end:=0.0
var armed_until:=0.0
var arm_code: Array=[]
var arm_index:=0
var defuse_code: Array=[]
var defuse_index:=0
var defuser:=0
var defuse_touch:=0.0
var cut_mask:=0
var key_at:=0.0
var message:="Waiting for both teams"
var spawning:=false
var sites: Array=[]
var starts: Array=[[],[]] # Roles: attackers, defenders.
var site_bounds: Array=[]
var site_volumes: Array=[]
var spawn_yaws: Array=[PI,0.0]
var individual_yaws: Array=[]
var visuals: Node3D
var panel
var local_sequence:=0
var observer_position:=Vector3.ZERO
var observer_life:=""
func observing(id: int=0) -> bool:
	if id==0:id=game.multiplayer.get_unique_id()
	var s: Dictionary=game.players.get(id,{})
	return game.active and not game.demos.playing and enabled() and s.get("dead",false) and not s.get("spectator",false)
func observer_origin(fallback: Vector3) -> Vector3:
	if not observing():observer_life="";return fallback
	var life: String="%d:%d"%[game.map_epoch,game.local_state().serial]
	if observer_life!=life:observer_life=life;observer_position=fallback
	return observer_position
func move_observer(command: Dictionary,delta: float):
	if not observing():observer_life="";return
	observer_origin(game.fighters[game.multiplayer.get_unique_id()].render_position())
	# Only the camera moves: the corpse, team, life and authoritative fighter stay put.
	var move: Vector2=command.move
	var direction: Vector3=(Basis(Vector3.UP,float(command.yaw))*Vector3(move.x,0,move.y)+Vector3.UP*float(command.get("fly",0.0))).limit_length(1)
	observer_position+=direction*(3.0 if command.slow else 7.0)*delta
func setup(value):mode_ref=weakref(value);utility.setup(self)
func enabled() -> bool:return mode.kind=="de" and not game.lobby.active()
func classic_movement() -> bool:return enabled() and supported()
func supported() -> bool:return Maps.supported(game.current_map,game.map_sha)
func configure(settings: Dictionary):
	prepare_seconds=float(settings.get("sv_de_prepare",15));round_seconds=float(settings.get("sv_de_roundtime",120));fuse_seconds=float(settings.get("sv_de_bombtime",45));win_limit=int(settings.get("sv_de_winlimit",16))
static func point(u: float,v: float,z: float) -> Vector3:return Vector3((v-300)*6/32,z/32+.05,-(u-400)*6/32)
func reset():
	utility.reset()
	observer_life=""
	phase="waiting";round_id=0;attacking=0;halftime_done=false;phase_end=0;losses=[0,0];accounts.clear();input_edges.clear();action_sequences.clear();bot_times.clear();local_sequence=0;spawning=false
	message="Waiting for both teams";clear_bomb();clear_visuals()
	load_layout()

func load_layout():
	var layout:=Maps.resolve(game.current_map,game.map_sha)
	if layout.is_empty():layout=Maps.resolve(MAP)
	# A launcher preload can start with an empty asset folder. Other modes and
	# disconnects also reset DE state, even when its optional default is absent.
	if layout.is_empty():
		sites.clear();starts=[[],[]];site_bounds.clear();site_volumes.clear()
		spawn_yaws=[PI,0.0];individual_yaws.clear();return
	sites=layout.sites.map(func(p):return Maps.vector(p));starts=[[],[]];site_bounds.clear();site_volumes.clear()
	for team in 2:starts[team]=layout.starts[team].map(func(p):return Maps.vector(p))
	for bounds in layout.bounds:site_bounds.append(AABB(Maps.vector(bounds.min),Maps.vector(bounds.max)-Maps.vector(bounds.min)))
	for boxes in layout.get("volumes",[]):
		site_volumes.append(boxes.map(func(box):return AABB(Maps.vector(box.min),Maps.vector(box.max)-Maps.vector(box.min))))
	spawn_yaws=layout.yaw.duplicate()
	individual_yaws=layout.get("start_yaws",[]).duplicate(true)

func spawn_yaw(id: int) -> float:
	var team:=role(id)
	if individual_yaws.size()!=2 or not game.fighters.has(id):return spawn_yaws[team]
	var nearest:=0;var distance:=INF
	for i in starts[team].size():
		var d: float=starts[team][i].distance_squared_to(game.fighters[id].position)
		if d<distance:nearest=i;distance=d
	return float(individual_yaws[team][nearest])

func clear_visuals():
	utility.clear_visuals()
	if is_instance_valid(visuals):visuals.queue_free()
	visuals=null
	if is_instance_valid(panel):panel.queue_free()
	panel=null
func clear_bomb():
	tactics.assigned=0;tactics.assignment_until=0;tactics.assignment_round=-1
	carrier=0;held=false;planted=false;planted_site=-1;fuse_end=0;armed_until=0;arm_index=0;defuse_index=0;defuser=0;defuse_touch=0;cut_mask=0;key_at=0
	arm_code=random_code(4);defuse_code=random_code(8)
static func random_code(count: int) -> Array:
	var result: Array=[]
	for i in count:result.append(randi_range(0,9))
	return result
func account(id: int) -> Dictionary:
	if not accounts.has(id):accounts[id]={"cash":800,"kit":false,"helmet":false,"tool":false,"notice":"","request_at":-1.0}
	return accounts[id]
func alive(id: int) -> bool:return game.players.has(id) and game.fighters.has(id) and not game.players[id].dead and not game.players[id].spectator and game.players[id].team in [0,1]
func crouch_defuse_assist(id: int,crouched: bool,active: bool=false) -> bool:
	if not crouched or not enabled() or phase!="live" or not planted or game.clock>=fuse_end or game.intermission>0 or not alive(id) or role(id)!=1:return false
	var actor=game.fighters[id]
	if actor.in_water or not actor.is_supported() or bomb_basis.z.dot(Vector3.UP)<.7:return false
	var delta: Vector3=bomb_position-actor.position
	# Only low floor mounts need this assist, not a wall or high crate keypad.
	if delta.y<-.15 or delta.y>.4 or Vector2(delta.x,delta.z).length()>(1.1 if active else .9):return false
	return ray_surface(actor.position+Vector3.UP*.48,bomb_position+bomb_basis.z*.05).is_empty()

func role(id: int) -> int:return 0 if game.players.get(id,{}).get("team",-1)==attacking else 1
func spawns(team: int) -> Array:return starts[0 if team==attacking else 1]
func preparing() -> bool:return enabled() and phase=="prepare"
func movement_blocked() -> bool:return enabled() and phase!="live"
func busy(id: int) -> bool:return enabled() and (carrier==id and held or defuser==id or accounts.get(id,{}).get("tool",false))
func gun_holstered(id: int) -> bool:return busy(id) or utility.selected(id)>=0
func combat_blocked(id: int) -> bool:return enabled() and (phase!="live" or gun_holstered(id))
func credit(id: int,amount: int):account(id).cash=clampi(int(account(id).cash)+amount,0,16000)
func spawn_loadout(id: int):
	if not enabled():return
	var s: Dictionary=game.players[id];var a:=account(id)
	s.owned=[0,Arsenal.STARTING_SIDEARMS[role(id)]];s.weapon=s.owned[1];s.ammo=[60,0,0,0];s.invulnerable=0
	a.tool=false
	if not spawning and phase in ["live","post","finished"]:s.dead=true;s.hp=0;s.respawn_at=INF
func begin_round():
	# Authored DE sliding leaves return to their closed position each round.
	# Existing mover snapshots replicate the transform; no new network message.
	for i in game.gates.size():
		var gate: Dictionary=game.gates[i]
		if gate.node.get_script()!=preload("res://deathmatch/maps/entity.gd") or int(gate.node.attributes.get("_de_reset",0))!=1:continue
		if gate.open:game._gate_state.rpc(i,false)
		if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
		gate.open=false;gate.until=0.0;gate.node.position=gate.base_position
	var halftime: bool=not halftime_done and round_id==win_limit-1 and round_id>0
	if halftime:attacking=1-attacking;losses=[0,0];halftime_done=true
	round_id+=1;clear_bomb();input_edges.clear();bot_times.clear();utility.new_round()
	phase="prepare";phase_end=game.clock+prepare_seconds;message="Buy equipment · prepare";spawning=true
	game.dropped_weapons.clear()
	for shot in game.projectiles.values():
		if is_instance_valid(shot.node):shot.node.queue_free()
	game.projectiles.clear();game.history.clear()
	for id in game.players:
		var s: Dictionary=game.players[id];var a:=account(id)
		var survived: bool=round_id>1 and not halftime and not s.dead and not s.spectator
		var kept: Dictionary={};var clips: Dictionary={}
		if survived:
			for field in ["owned","ammo","weapon","armor","tier"]:kept[field]=s[field].duplicate() if s[field] is Array else s[field]
			var c: Dictionary=game.variant_combat.cs.states.get(id,{})
			for field in ["clips","modes","physical"]:clips[field]=c.get(field,{}).duplicate(true)
		else:a.kit=false;a.helmet=false;utility.state(id).counts=[0,0,0]
		if halftime:a.cash=800
		game._spawn(id)
		if survived:
			s.merge(kept,true)
			var c: Dictionary=game.variant_combat.cs.state(id);c.merge(clips,true);c.serial=s.serial
			for p in c.physical.values():game.variant_combat.cs.Reload.interrupt(p)
			s.starting_weapons=[0,Arsenal.STARTING_SIDEARMS[role(id)]]
		enforce_capacity(id)
		if id==game.multiplayer.get_unique_id():game.desired_weapon=s.weapon
		if not s.spectator:s.yaw=spawn_yaw(id)
	spawning=false
	var attackers: Array=game.players.keys().filter(func(id):return alive(id) and role(id)==0)
	if not attackers.is_empty():carrier=attackers[(round_id-1)%attackers.size()]
	bomb_position=starts[0][0]+Vector3.UP*.2;bomb_basis=Basis.IDENTITY
	game._announcement.rpc("DE · ROUND %d%s · BUY %ds"%[round_id," · SIDES SWITCHED" if halftime else "",int(prepare_seconds)])
func can_buy(id: int) -> bool:
	return preparing() and game.clock<phase_end and alive(id) and game.intermission<=0 and spawns(game.players[id].team).any(func(p):return game.fighters[id].position.distance_to(p)<5)
func offer_allowed(id: int,item: int) -> bool:
	if not PRICES.has(item) or not game.players.has(id) or game.players[id].spectator or game.players[id].team not in [0,1]:return false
	if item<12:return Arsenal.can_purchase(item,role(id))
	return item!=102 or role(id)==1
func offers(id: int) -> Array:
	if not game.players.has(id):return []
	var result: Array=[];var s: Dictionary=game.players[id];var a:=account(id)
	for item in PRICES:
		if not offer_allowed(id,item):continue
		var name: String=game.armory.data(item).name if item<12 else GEAR[item]
		result.append({"id":item,"name":name,"ammo":PRICES[item],"usable":can_buy(id) and a.cash>=PRICES[item] and (item>=12 or not s.owned.has(item)) and (item not in utility.ITEMS or utility.state(id).counts[utility.ITEMS.find(item)]<utility.LIMITS[utility.ITEMS.find(item)]),"buy":true,"cash":a.cash})
	return result
func category(w: int) -> int:return -1 if w<0 or w>=Arsenal.NAMES.size() else 0 if w==0 else 1 if w in PISTOLS else 2
func enforce_capacity(id: int):
	# Surviving inventories may come from an older/test session. Prefer the active
	# gun, then the most recently acquired gun in each slot; drop any surplus.
	var s: Dictionary=game.players[id]
	var kept: Dictionary={}
	for w in s.owned:
		if category(w)>0:kept[category(w)]=w
	if category(s.weapon)>0 and s.weapon in s.owned:kept[category(s.weapon)]=s.weapon
	for w in kept.values():replace_weapon(id,w)
	var unique: Array=[]
	for w in s.owned:
		if category(w)>=0 and not w in unique:unique.append(w)
	if not 0 in unique:unique.push_front(0)
	s.owned=unique
	if not s.weapon in s.owned:s.weapon=s.owned.back()
func replace_weapon(id: int,w: int,swap_same: bool=false):
	if category(w)<=0:return
	var s: Dictionary=game.players[id]
	var c: Dictionary=game.variant_combat.cs.state(id)
	for old in s.owned.duplicate():
		if old==w and not swap_same or category(old)!=category(w):continue
		var pool: int=game.armory.data(old).ammo
		var amount: int=game.variant_combat.cs.loaded_ammo(id,old)
		game.dropped_weapons.next_id+=1
		game.dropped_weapons.add(game.dropped_weapons.next_id,game.fighters[id].position,old,amount);s.ammo[pool]-=amount
		s.owned.erase(old)
		c.clips.erase(old);c.physical.erase(old);c.modes.erase(old)
func buy(id: int,item: int) -> bool:
	if not can_buy(id) or not offer_allowed(id,item):return false
	var s: Dictionary=game.players[id];var a:=account(id);var price: int=PRICES[item]
	if a.cash<price:a.notice="Not enough money";return false
	if item<12:
		if item in s.owned:a.notice="Already owned";return false
		replace_weapon(id,item);s.owned.append(item);s.weapon=item
		var d: Dictionary=game.armory.data(item);s.ammo[d.ammo]=mini(game.armory.max_ammo()[d.ammo],s.ammo[d.ammo]+d.magazine)
		var c: Dictionary=game.variant_combat.cs.state(id);c.clips[item]=d.magazine;c.physical.erase(item)
	elif item in utility.ITEMS:
		if not utility.buy(id,utility.ITEMS.find(item)):return false
	elif item in [100,101]:
		if s.armor>=100 and (item==100 or a.helmet):return false
		s.armor=100;s.tier=2 if item==101 or a.helmet else 1
		if item==101:a.helmet=true
	elif item==102:
		if a.kit:return false
		a.kit=true
	else:
		var weapons: Array=s.owned.filter(func(w):return category(w)==(2 if item==103 else 1))
		if weapons.is_empty():return false
		var d: Dictionary=game.armory.data(weapons[0]);var cap: int=game.armory.max_ammo()[d.ammo]
		if s.ammo[d.ammo]>=cap:return false
		s.ammo[d.ammo]=mini(cap,s.ammo[d.ammo]+d.magazine)
	credit(id,-price);a.notice="Bought "+(game.armory.data(item).name if item<12 else GEAR[item])
	if item<12:game._pickup_event.rpc(id,"weapon",item,item,true)
	game.server_log.record("de_purchase",{"peer":id,"item":item,"price":price,"cash":a.cash,"round":round_id},1)
	if id==game.multiplayer.get_unique_id():game.desired_weapon=s.weapon
	return true
func base_pose(id: int) -> Transform3D:return Transform3D(Basis(Vector3.UP,game.players[id].yaw),game.fighters[id].position)
func bomb_pose() -> Transform3D:
	if carrier!=0 and game.players.has(carrier) and game.fighters.has(carrier):
		var s: Dictionary=game.players[carrier]
		if held:
			if not s.xr.is_empty():return base_pose(carrier)*Interaction.held(s.xr)
			return base_pose(carrier)*Transform3D(Basis(Vector3.RIGHT,-.25),Vector3(0,1.05,-.5))
		return base_pose(carrier)*Interaction.carried(s.xr)
	return Transform3D(bomb_basis,bomb_position)
func reachable(id: int,where: Vector3,radius: float=1.8) -> bool:
	if not alive(id):return false
	var pos: Vector3=game.fighters[id].position
	return pos.distance_to(where)<radius and game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.9,where,1)).is_empty()
func site_at(point: Vector3) -> int:
	for i in site_bounds.size():
		if not site_bounds[i].grow(.06).has_point(point):continue
		if site_volumes.size()!=site_bounds.size() or site_volumes[i].any(func(box):return box.grow(.06).has_point(point)):return i
	return -1

func ray_surface(start: Vector3,end: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
const MAX_PLANT_HEIGHT:=1.5
func plant_ground(center: Vector3,normal: Vector3) -> Dictionary:
	# Check the floor beside the keypad, not the planter's feet (which may be
	# jumping). Leave room for a standing defender in front of a wall mount.
	var outward:=Vector3(normal.x,0,normal.z).normalized()
	var at:=center+outward*.25
	var floor_hit:=ray_surface(at+Vector3.UP*.01,at-Vector3.UP*(MAX_PLANT_HEIGHT+.01))
	if floor_hit.is_empty() or floor_hit.normal.y<cos(deg_to_rad(50)) or center.y-floor_hit.position.y>MAX_PLANT_HEIGHT+.001:return {}
	# A narrow trim ledge or a low overhang is not standable ground.
	var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	query.transform.origin=floor_hit.position+Vector3.UP*(capsule.height*.5+.025)
	if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty():return {}
	for offset in [Vector3.RIGHT*.24,Vector3.LEFT*.24,Vector3.FORWARD*.24,Vector3.BACK*.24]:
		var support:=ray_surface(floor_hit.position+offset+Vector3.UP*.1,floor_hit.position+offset-Vector3.UP*.3)
		if support.is_empty() or support.normal.y<cos(deg_to_rad(50)):return {}
	return floor_hit
func surface_mount(id: int,hit: Dictionary,up: Vector3) -> Dictionary:
	if hit.is_empty():return {}
	var index:=site_at(hit.position)
	if index<0:return {}
	var normal: Vector3=hit.normal.normalized();var vertical: Vector3=up-normal*up.dot(normal)
	if vertical.length_squared()<.01:
		vertical=-base_pose(id).basis.z;vertical=(vertical-normal*vertical.dot(normal)).normalized()
	else:vertical=vertical.normalized()
	var basis:=Basis(vertical.cross(normal).normalized(),vertical,normal).orthonormalized()
	var center: Vector3=hit.position+normal*.102
	if not reachable(id,center,2.1):return {}
	if plant_ground(center,normal).is_empty():return {}
	# All four mounting feet must rest on the same solid plane. This rules out
	# thin edges, holes, corners, and partly embedded/unsupported placements.
	for x in [-.12,.12]:
		for y in [-.15,.15]:
			var point: Vector3=hit.position+basis*Vector3(x,y,0)
			var support:=ray_surface(point+normal*.065,point-normal*.045)
			if support.is_empty() or support.normal.dot(normal)<.96 or support.position.distance_to(point)>.025 or site_at(support.position)!=index:return {}
	return {"site":index,"pose":Transform3D(basis,center)}
func placement(id: int) -> Dictionary:
	if not alive(id):return {}
	var s: Dictionary=game.players[id];var pose:=bomb_pose()
	if s.vr_device and s.xr.is_empty():return {}
	if not s.xr.is_empty():
		var hit:=ray_surface(pose.origin+pose.basis.z*.04,pose.origin-pose.basis.z*.25)
		if hit.is_empty() or hit.normal.dot(pose.basis.z)<.65:return {}
		return surface_mount(id,hit,pose.basis.y)
	var base:=base_pose(id);var start: Vector3=base.origin+Vector3.UP*1.35
	var direction: Vector3=game.W.direction(s.yaw,s.pitch)
	var hit:=ray_surface(start,start+direction*1.85)
	if not hit.is_empty():return surface_mount(id,hit,Vector3.UP)
	# Desktop Use, and bots, can set it on the floor immediately in front.
	var floor_point: Vector3=base.origin-base.basis.z*.65
	return surface_mount(id,ray_surface(floor_point+Vector3.UP*.8,floor_point-Vector3.UP*.4),-base.basis.z)
func drop(id: int):
	if not enabled():return
	if defuser==id:reset_defuse()
	if accounts.has(id):accounts[id].tool=false
	if carrier!=id:return
	var position: Vector3=game.fighters[id].position if game.fighters.has(id) else starts[0][0]
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP,position-Vector3.UP*3,1))
	bomb_position=hit.position+Vector3.UP*.20 if not hit.is_empty() and position.y>game.fall_limit+2 else starts[0][0]+Vector3.UP*.20
	bomb_basis=Basis.IDENTITY;carrier=0;held=false;arm_index=0;armed_until=0
func killed(victim: int,attacker: int):
	if not enabled():return
	drop(victim);utility.on_death(victim)
	if attacker!=victim and game.players.has(attacker):credit(attacker,-3300 if mode.same_team(victim,attacker) else 300)
func can_recover_bomb(id: int) -> bool:
	return enabled() and phase=="live" and game.intermission<=0 and carrier==0 and not planted and alive(id) and role(id)==0 and reachable(id,bomb_position)
func recover_bomb(id: int) -> bool:
	if not can_recover_bomb(id):return false
	carrier=id;held=false;arm_index=0;armed_until=0;key_at=0
	utility.cancel(id)
	return true
func bot_input(id: int) -> bool:
	if not enabled() or not alive(id):return false
	var s: Dictionary=game.players[id]
	if phase=="prepare":
		if not bot_times.has(id) or bot_times[id]!=-round_id:
			bot_times[id]=-round_id
			var primary: int=Arsenal.PREFERRED_RIFLES[role(id)]
			if not s.owned.any(func(w):return category(w)==2):
				if not game.bots.action("de_buy",[id,primary]):game.bots.action("de_buy",[id,5])
			if role(id)==1:game.bots.action("de_buy",[id,102])
			if not game.bots.action("de_buy",[id,101]):game.bots.action("de_buy",[id,100])
			game.bots.action("de_buy",[id,103]);game.bots.action("de_buy",[id,104])
			for item in [110,111,112,111]:game.bots.action("de_buy",[id,item])
		return true
	if phase!="live":return true
	if not busy(id) and nearby_weapon(id)>=0:game.bots.action("de_use",[id])
	if carrier==0 and not planted and role(id)==0 and reachable(id,bomb_position):game.bots.action("de_use",[id])
	var brain: Dictionary=game.bots.brains.get(id,{}) if is_instance_valid(game.bots) else {}
	var threatened: bool=alive(int(brain.get("enemy",0))) or alive(int(brain.get("remembered_enemy",0))) and game.clock-float(brain.get("last_seen_at",-10))<.6
	threatened=threatened or s.get("bot_hurt_serial",-1)==s.serial and game.clock<float(s.get("bot_hurt_until",0))
	if threatened:
		game.bots.action("de_bot_stow_objective",[id])
		return false
	var working: bool=false
	if carrier==id:
		var site: int=round_id%2
		if reachable(id,sites[site]+Vector3.UP*.2,1.5):
			working=true;game.bots.action("de_hold",[id])
			if armed_until>game.clock:game.bots.action("de_plant",[id,site])
			elif game.clock>=float(bot_times.get(id,0)):game.bots.action("de_digit",[id,arm_code[arm_index]]);bot_times[id]=game.clock+.65
	elif planted and role(id)==1 and reachable(id,bomb_position,1.5) and defuser in [0,id]:
		working=true;game.bots.action("de_lock_defuse",[id])
		if game.clock>=float(bot_times.get(id,0)):
			if account(id).kit:
				game.bots.action("de_tool",[id])
				for wire in 3:
					if cut_mask&(1<<wire)==0:game.bots.action("de_cut",[id,wire]);break
			else:game.bots.action("de_digit",[id,defuse_code[defuse_index]])
			bot_times[id]=game.clock+.65
	if working:s.move=Vector2.ZERO;s.fire=false;s.melee=false;s.alt_fire=false;s.jump=false
	else:game.bots.action("de_bot_stow_objective",[id])
	return working
func bot_stow_objective(id: int):
	# A recovered bomb travels on the chest. Cutters and interrupted arming
	# must release the normal gun controls before the bot resumes its route.
	if carrier==id and held:held=false;arm_index=0;armed_until=0
	if defuser==id:reset_defuse()
	account(id).tool=false
func bot_goals(ai,id: int,rows: Array):
	tactics.goals(self,ai,id,rows)
func nearby_weapon(id: int) -> int:
	if not enabled() or phase not in ["prepare","live"] or not alive(id) or busy(id):return -1
	var s: Dictionary=game.players[id];var origin: Vector3=game.fighters[id].position
	var closest:=-1;var distance:=1.05
	for key in game.dropped_weapons.entries:
		var p: Dictionary=game.dropped_weapons.entries[key]
		if not p.available or game.clock>=p.expires:continue
		var ammo: int=game.armory.data(p.item).ammo
		if id<0 and s.owned.has(p.item) and (p.amount<=0 or ammo<0 or s.ammo[ammo]>=game.armory.max_ammo()[ammo]):continue
		# Bots explicitly use drops to fill an empty category or replenish ammunition.
		if id<0 and not s.owned.has(p.item) and s.owned.any(func(w):return category(w)==category(p.item)):continue
		var reach: float=origin.distance_to(p.position)
		if reach>distance:continue
		if not ray_surface(origin+Vector3.UP*.9,p.position+Vector3.UP*.15).is_empty():continue
		closest=key;distance=reach
	return closest
func use(id: int) -> bool:
	if not enabled() or not alive(id) or game.intermission>0:return false
	if phase in ["prepare","live"] and game.players[id].vr_device and carrier==id and held:
		drop(id);return true
	# Death drops the equipped gun beside the bomb. Taking weapons first could
	# swap that same slot forever and prevent a surviving terrorist recovering it.
	if recover_bomb(id):return true
	var key:=nearby_weapon(id)
	if key>=0:
		if game.clock<game.players[id].use_at:return false
		game.players[id].use_at=game.clock+.25
		game._collect(id,key)
		return true
	if phase!="live":return false
	if role(id)==0 and not planted:
		if carrier==id:
			if game.players[id].vr_device:
				return false # VR draws from the chest with the weapon-hand grip.
			if held and armed_until>game.clock:
				return plant(id)
			held=not held
			if not held:arm_index=0;armed_until=0
			return true
	elif role(id)==1 and planted and reachable(id,bomb_position):
		if game.players[id].vr_device:return false # Physical cutters belong to grip + trigger.
		account(id).tool=not account(id).tool if account(id).kit else false
		return lock_defuse(id)
	return false
func lock_defuse(id: int) -> bool:
	if defuser!=0 and defuser!=id:return false
	defuser=id;defuse_touch=game.clock;return true
func reset_defuse():defuser=0;defuse_index=0;defuse_touch=0;cut_mask=0
func digit(id: int,value: int) -> bool:
	if not enabled() or phase!="live" or not alive(id) or value<0 or value>9 or game.clock<key_at or game.intermission>0:return false
	if not planted and armed_until>0 and game.clock>=armed_until:armed_until=0;arm_index=0
	if planted:
		if game.clock>=fuse_end or role(id)!=1 or not reachable(id,bomb_position) or not lock_defuse(id):return false
		key_at=game.clock+.16
		defuse_index=defuse_index+1 if value==int(defuse_code[defuse_index]) else 0
		if defuse_index==8:credit(id,300);finish_round(1-attacking,"BOMB DEFUSED")
		return true
	if game.clock>=phase_end or carrier!=id or not held or armed_until>game.clock:return false
	key_at=game.clock+.16;arm_index=arm_index+1 if value==int(arm_code[arm_index]) else 0
	if arm_index==4:armed_until=game.clock+5
	return true
func cut(id: int,index: int) -> bool:
	if not enabled() or phase!="live" or not planted or game.clock>=fuse_end or not alive(id) or role(id)!=1 or not account(id).kit or not account(id).tool or not reachable(id,bomb_position) or index<0 or index>2 or game.clock<key_at or not lock_defuse(id):return false
	if not game.players[id].vr_device:snip(id)
	key_at=game.clock+.16;cut_mask|=1<<index
	if cut_mask==7:credit(id,300);finish_round(1-attacking,"BOMB DEFUSED")
	return true
func snip(id: int):
	# Feedback also works away from a wire, once per fresh trigger squeeze.
	if game.clock<float(account(id).get("snip_at",-1.0)):return
	account(id).snip_at=game.clock+.12
	game._de_tool_snip.rpc(game.map_epoch,id,int(game.players[id].serial))
func plant(id: int,index: int=-1) -> bool:
	if not enabled() or phase!="live" or planted or not alive(id) or carrier!=id or not held or armed_until<=game.clock or game.clock>=phase_end:return false
	var candidate:=placement(id)
	if candidate.is_empty() or index>=0 and candidate.site!=index:return false
	planted=true;held=false;carrier=0;planted_site=candidate.site;bomb_position=candidate.pose.origin;bomb_basis=candidate.pose.basis;fuse_end=game.clock+fuse_seconds;armed_until=0
	credit(id,300);game._announcement.rpc("BOMB PLANTED · SITE "+("A" if planted_site==0 else "B"))
	game.announcer.defusal_event("de_bomb_planted");return true
func stow_items(id: int):
	if carrier==id and held:held=false;arm_index=0;armed_until=0
	if account(id).tool and defuser==id:reset_defuse()
	account(id).tool=false
func sample_player(id: int):
	if not enabled() or not alive(id):return
	var s: Dictionary=game.players[id]
	utility.sample_player(id)
	if utility.selected(id)>=0:return
	if phase not in ["prepare","live"] or s.input_blocked or game.clock-s.last_input>.35:
		if defuser==id:reset_defuse()
		stow_items(id)
		input_edges[id]={"grip":true,"trigger":true}
		return
	if s.xr.is_empty():
		if s.vr_device:
			stow_items(id)
			if defuser==id:reset_defuse()
			input_edges[id]={"grip":true,"trigger":true}
		return
	var pose: Dictionary=s.xr;var grip: bool=s.get("de_grip",false);var trigger: bool=s.get("de_trigger",false)
	var old: Dictionary=input_edges.get(id,{"grip":false,"trigger":false})
	var palm: Vector3=Interaction.primary(pose).origin
	var hand: Vector3=base_pose(id)*palm
	if not grip:stow_items(id)
	elif not old.grip and not busy(id):
		var bomb_distance: float=palm.distance_to(Interaction.carried(pose).origin) if carrier==id and not planted else INF
		var tool_distance: float=palm.distance_to(Interaction.holster(pose)) if account(id).kit else INF
		if bomb_distance<.15 and bomb_distance<=tool_distance:held=true
		elif tool_distance<.13:account(id).tool=true
		elif not planted and hand.distance_to(bomb_position)<.28:recover_bomb(id)
	if carrier==id and held and armed_until>game.clock:plant(id)
	if account(id).tool and trigger and not old.trigger:
		snip(id)
		if planted and role(id)==1:
			var tip: Vector3=base_pose(id)*Interaction.cutter_tip(pose)
			cut(id,Interaction.wire_at(bomb_pose().affine_inverse()*tip))
	var tip:=Vector3.INF
	var contact: int=-1
	var pressed: bool=old.get("pressed",false)
	var stamp: float=s.last_input
	if phase=="live" and pose.has("offhand_weapon") and (carrier==id and held or planted and role(id)==1 and not account(id).tool):
		tip=bomb_pose().affine_inverse()*(base_pose(id)*Interaction.fingertip(pose))
		var fresh: bool=stamp>float(old.get("stamp",-1)) and stamp-float(old.get("stamp",-1))<=.25
		if tip.z>=Interaction.RELEASE_DEPTH:pressed=false
		if fresh and not pressed:
			contact=Interaction.press(old.get("tip",Vector3.INF),tip)
			if contact>=0:
				pressed=true
				if digit(id,contact) and id==game.multiplayer.get_unique_id() and game.is_vr():game.xr_rig.feedback(.2,.035,true)
		if planted and defuser==id and reachable(id,bomb_position) and Interaction.key_at(tip)>=0:defuse_touch=game.clock
	else:pressed=false
	input_edges[id]={"grip":grip,"trigger":trigger,"tip":tip,"pressed":pressed,"stamp":stamp}
func request(id: int,action: String,value: int,epoch: int,round_number: int,life: int,sequence: int) -> bool:
	if not game.multiplayer.is_server() or not enabled() or not alive(id) or epoch!=game.map_epoch or round_number!=round_id or life!=game.players[id].serial or sequence<=int(action_sequences.get(id,0)) or sequence>2147483647:return false
	action_sequences[id]=sequence
	var a:=account(id)
	if game.clock<float(a.request_at):return false
	a.request_at=game.clock+.08
	if action=="buy":return buy(id,value)
	if action=="grenade":return utility.equip(id,value)
	if action=="grenade_cycle":return utility.cycle(id,value)
	# VR contacts are derived from validated tracking, never remote keypad indices.
	if game.players[id].vr_device:return false
	if action=="digit":return digit(id,value)
	if action=="cut":return cut(id,value)
	if action=="drop" and carrier==id:drop(id);return true
	return false
func send(action: String,value: int=0):
	local_sequence+=1
	var id: int=game.multiplayer.get_unique_id();var life: int=game.local_state().get("serial",-1)
	if game.multiplayer.is_server():request(id,action,value,game.map_epoch,round_id,life,local_sequence)
	else:game._de_request.rpc_id(1,action,value,game.map_epoch,round_id,life,local_sequence)
func tick(_delta: float):
	utility.tick(_delta)
	if not enabled() or not game.multiplayer.is_server() or game.intermission>0:return
	var both_teams: bool=[0,1].all(func(team):return game.players.values().any(func(s):return not s.spectator and s.team==team))
	if phase=="prepare" and not both_teams:
		round_id=maxi(0,round_id-1);phase="waiting";message="Waiting for both teams";clear_bomb()
	if phase=="waiting":
		if both_teams:begin_round()
	elif phase=="prepare" and game.clock>=phase_end:
		phase="live";phase_end=game.clock+round_seconds;message="Plant at A or B · defend the sites"
	elif phase=="post" and game.clock>=phase_end:
		if mode.scores.max()>=win_limit or round_id>=maxi(1,2*(win_limit-1)):phase="finished";game._end_round()
		elif both_teams:begin_round()
		else:phase="waiting";message="Waiting for both teams";clear_bomb()
	elif phase=="live":
		if armed_until>0 and game.clock>=armed_until:armed_until=0;arm_index=0
		if defuser!=0 and (not alive(defuser) or not reachable(defuser,bomb_position) or game.clock-defuse_touch>1.5):reset_defuse()
		if planted and game.clock>=fuse_end:
			# Resolve the winner before blast damage, so a simultaneous wipe cannot
			# override a completed objective or grant a second round reward.
			finish_round(attacking,"BOMB EXPLODED")
			game._de_explosion.rpc(bomb_position)
			for id in game.players:
				if alive(id):
					var distance: float=game.fighters[id].position.distance_to(bomb_position)
					if distance<24:game._damage(id,id,roundi(500*(1-distance/24)),"C4",true)
		elif not planted and game.clock>=phase_end:finish_round(1-attacking,"TIME EXPIRED")
		else:
			var live: Array=[0,0]
			for id in game.players:
				if alive(id):live[game.players[id].team]+=1
			if live[1-attacking]==0:finish_round(attacking,"DEFENDERS ELIMINATED")
			elif live[attacking]==0 and not planted:finish_round(1-attacking,"ATTACKERS ELIMINATED")
	game.round_left=maxf(0,(fuse_end if planted and phase=="live" else phase_end)-game.clock)
func finish_round(winner: int,reason: String):
	if phase!="live":return
	phase="post";phase_end=game.clock+5;message=reason;mode.scores[winner]+=1
	var loser:=1-winner;losses[loser]+=1;losses[winner]=0
	var reward:=3500 if reason=="BOMB EXPLODED" else 3250 if reason in ["BOMB DEFUSED","TIME EXPIRED"] else 3000
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.spectator or not s.team in [0,1]:continue
		var bonus:=reward if s.team==winner else mini(3000,1400+(losses[loser]-1)*500)
		if reason=="TIME EXPIRED" and s.team==attacking and not s.dead:bonus=0
		if planted and s.team==attacking and winner!=attacking:bonus+=800
		credit(id,bonus);account(id).tool=false
	game._announcement.rpc("%s · %s WIN · %d : %d"%[reason,"T" if winner==attacking else "CT",mode.scores[0],mode.scores[1]])
	game.announcer.defusal_event("de_terrorists_win" if winner==attacking else "de_counter_terrorists_win")
	game.server_log.record("de_round",{"round":round_id,"winner":winner,"reason":reason,"scores":mode.scores.duplicate()},1)
	held=false;defuser=0
func status(id: int=0) -> String:
	var role_name: String=("TERRORISTS" if role(id)==0 else "COUNTER-TERRORISTS") if game.players.has(id) else "SPECTATOR"
	return "DE · ROUND %d · RED %d : %d BLUE · %s · %s"%[round_id,mode.scores[0],mode.scores[1],role_name,message]
func hint(id: int) -> String:
	if not game.players.has(id):return ""
	if game.players[id].dead:return "OUT · NEXT ROUND" if phase!="finished" else message
	if can_recover_bomb(id):return "USE / GRAB · RECOVER BOMB"
	if utility.selected(id)>=0:
		return utility.NAMES[utility.selected(id)]+(" · OFFHAND GRIP + TRIGGER, SWING + RELEASE GRIP" if game.is_vr() and game.bindings.physical_interactions else " · HOLD TRIGGER / FIRE, RELEASE TO THROW · WHEEL / Q TO HOLSTER")
	var pickup:=nearby_weapon(id)
	if pickup>=0:return "USE · PICK UP / SWAP "+game.armory.data(game.dropped_weapons.entries[pickup].item).name
	if phase=="prepare":return "$%d · BUY: RIGHT STICK CLICK / B · %ds"%[int(account(id).cash),ceili(maxf(0,phase_end-game.clock))]
	if carrier==id:return "ARM: %s · PLACE AT A/B"%str(arm_code[mini(arm_index,3)]) if held and armed_until<=game.clock else "ARMED · PRESS BACK TO SURFACE · %ds"%ceili(armed_until-game.clock) if held else "BOMB · GRAB CHEST BOMB / USE"
	if planted:return "BOMB · %ds · CODE OR CUT THREE WIRES"%ceili(maxf(0,fuse_end-game.clock))
	return "$%d · %s"%[int(account(id).cash),"DEFUSE CUTTERS · CHEST" if account(id).kit else "DEFEND A / B" if role(id)==1 else "ESCORT THE BOMB"]
func snapshot() -> Dictionary:
	if not enabled():return {}
	var rows: Dictionary={}
	for id in game.players:
		var a:=account(id);rows[id]=[a.cash,a.kit,a.helmet,a.tool,a.notice]
	return {"phase":phase,"round":round_id,"attacking":attacking,"remaining":maxf(0,phase_end-game.clock),"win_limit":win_limit,"accounts":rows,"carrier":carrier,"held":held,"planted":planted,"position":bomb_position,"basis":bomb_basis,"site":planted_site,"fuse":maxf(0,fuse_end-game.clock),"armed":maxf(0,armed_until-game.clock),"arm_code":arm_code,"arm_index":arm_index,"defuse_code":defuse_code,"defuse_index":defuse_index,"defuser":defuser,"cuts":cut_mask,"sites":sites,"starts":starts,"message":message,"utility":utility.snapshot()}
func receive(data: Dictionary):
	if data.is_empty() or not valid_snapshot(data):return
	utility.receive(data.get("utility",{}))
	phase=data.phase;round_id=data.round;attacking=data.attacking;phase_end=game.clock+float(data.remaining);win_limit=data.win_limit
	carrier=data.carrier;held=data.held;planted=data.planted;bomb_position=data.position;bomb_basis=data.basis;planted_site=data.site;fuse_end=game.clock+float(data.fuse);armed_until=game.clock+float(data.armed) if data.armed>0 else 0
	arm_code=data.arm_code;arm_index=data.arm_index;defuse_code=data.defuse_code;defuse_index=data.defuse_index;defuser=data.defuser;cut_mask=data.cuts;sites=data.sites;starts=data.starts;message=data.message
	for id in data.accounts:
		var row: Array=data.accounts[id];account(id).merge({"cash":row[0],"kit":row[1],"helmet":row[2],"tool":row[3],"notice":row[4]},true)
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary:return false
	if data.is_empty():return true
	if not preload("res://deathmatch/counterstrike/grenades.gd").valid_snapshot(data.get("utility",{})):return false
	if not data.get("phase") in ["waiting","prepare","live","post","finished"] or not data.get("message") is String or data.message.length()>120:return false
	for key in ["round","attacking","win_limit","carrier","site","arm_index","defuse_index","defuser","cuts"]:
		if not data.get(key) is int:return false
	if data.round<0 or data.round>1000 or data.attacking not in [0,1] or data.win_limit<1 or data.win_limit>30 or data.site not in [-1,0,1] or data.arm_index<0 or data.arm_index>4 or data.defuse_index<0 or data.defuse_index>8 or data.cuts<0 or data.cuts>7:return false
	for key in ["remaining","fuse","armed"]:
		var number=data.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or number<0 or number>600.01:return false
	if data.fuse>90.01 or data.armed>5.01 or not data.get("held") is bool or not data.get("planted") is bool:return false
	if not data.get("position") is Vector3 or not data.position.is_finite() or not data.get("basis") is Basis or not data.basis.is_finite() or absf(data.basis.determinant()-1)>.02:return false
	for key in ["arm_code","defuse_code"]:
		if not data.get(key) is Array or data[key].size()!=(4 if key=="arm_code" else 8):return false
		for digit in data[key]:
			if not digit is int or digit<0 or digit>9:return false
	if not data.get("sites") is Array or data.sites.size()!=2 or not data.get("starts") is Array or data.starts.size()!=2:return false
	for list in [data.sites,data.starts[0],data.starts[1]]:
		if not list is Array or list.is_empty() or list.size()>32:return false
		for point in list:
			if not point is Vector3 or not point.is_finite():return false
	if not data.get("accounts") is Dictionary or data.accounts.size()>32:return false
	for id in data.accounts:
		var row=data.accounts[id]
		if not id is int or not row is Array or row.size()!=5 or not row[0] is int or row[0]<0 or row[0]>16000 or not row[1] is bool or not row[2] is bool or not row[3] is bool or not row[4] is String or row[4].length()>100:return false
	return true
func draw():
	utility.draw()
	if game.headless:return
	if not enabled():clear_visuals();return
	if not is_instance_valid(visuals):visuals=load("res://deathmatch/ui/defusal_world.gd").new();game.get_node("Map").add_child(visuals);visuals.setup(self)
	visuals.update()
	if not game.is_vr() and not game.dedicated:
		if not is_instance_valid(panel):panel=load("res://deathmatch/ui/defusal_panel.gd").new();game.add_child(panel);panel.setup(self)
		panel.refresh()
func desktop_input(event: InputEvent) -> bool:
	if not enabled() or game.menu_open or game.demos.playing or not event is InputEventKey or not event.pressed or event.echo:return false
	if event.physical_keycode==KEY_B and can_buy(game.multiplayer.get_unique_id()):
		draw();panel.toggle();return true
	if is_instance_valid(panel) and panel.opened:
		return panel.handle_key(event.physical_keycode)
	var mine: int=game.multiplayer.get_unique_id()
	if event.physical_keycode==KEY_4 and phase=="live" and alive(mine):
		var current: int=utility.selected(mine)
		for offset in range(1,4):
			var kind: int=posmod(current+offset,3)
			if utility.state(mine).counts[kind]>0:send("grenade",kind);break
		return true
	if event.physical_keycode==KEY_Q and utility.selected(mine)>=0:send("grenade",-1);return true
	if busy(game.multiplayer.get_unique_id()):
		if event.physical_keycode>=KEY_0 and event.physical_keycode<=KEY_9:send("digit",event.physical_keycode-KEY_0);return true
		if event.physical_keycode==KEY_G:send("drop");return true
		if event.physical_keycode in [KEY_J,KEY_K,KEY_L]:send("cut",[KEY_J,KEY_K,KEY_L].find(event.physical_keycode));return true
	return false
