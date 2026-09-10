extends RefCounted
## All rules run on the server. Clients receive a read-only objective snapshot.
const NAMES={"dm":"DEATHMATCH","tdm":"TEAM DEATHMATCH","ctf":"CAPTURE THE FLAG","koth":"KING OF THE HILL","ig":"INSTAGIB","ft":"FREEZE TAG","cc":"CHAINSAW CIRCUS","tf":"TEAM FORTRESS"}
const COLORS=[Color("ed6558"),Color("65a9ef")]
const TEAMS=["RED","BLUE"]
var game
var fortress=preload("res://deathmatch/modes/fortress.gd").new()
var special=preload("res://deathmatch/modes/special.gd").new()
var kind:="dm"
var friendly_fire:=false
var capture_limit:=5
var hill_limit:=120
var scores: Array=[0,0]
var bases: Array=[]
var flags: Array=[]
var captures: Array=[]
var hill:=Vector3.ZERO
var hill_owner:=-1 # -1 empty, -2 contested.
var hill_credit:=0.0
var visuals: Node3D
var visual_key:=""

func setup(arena: Node) -> void: game=arena;special.setup(self);fortress.name="FortressRules";game.add_child(fortress);fortress.setup(self)
func configure(settings: Dictionary) -> void:
	kind=settings.get("sv_gametype","dm")
	friendly_fire=settings.get("sv_friendlyfire",0)==1
	capture_limit=settings.get("capturelimit",5)
	hill_limit=settings.get("hilllimit",120)
func team_game() -> bool: return kind in ["tdm","ctf","koth","ft","tf"]
func assign_team(spectator: bool) -> int:
	if spectator or not team_game():return -1
	var count: Array=[0,0]
	for s in game.players.values():
		if not s.spectator and s.get("team",-1)>=0:count[s.team]+=1
	return 0 if count[0]<=count[1] else 1
func same_team(a: int,b: int) -> bool:
	return team_game() and game.players.has(a) and game.players.has(b) and game.players[a].team>=0 and game.players[a].team==game.players[b].team
func reset() -> void:
	special.reset();fortress.reset()
	scores=[0,0];hill_owner=-1;hill_credit=0.0;flags.clear();bases.clear();captures.clear()
	if game.spawn_points.is_empty():return
	# BSP spawn origins are known playable locations; custom maps get a conservative fallback.
	var first: Vector3=game.spawn_points[0]
	var second:=first
	var distance:=-1.0
	for a in game.spawn_points:
		for b in game.spawn_points:
			if a.distance_squared_to(b)>distance:distance=a.distance_squared_to(b);first=a;second=b
	bases=[first,second]
	var midpoint:=(first+second)*.5
	hill=game.spawn_points[0]
	for point in game.spawn_points:
		if point.distance_squared_to(midpoint)<hill.distance_squared_to(midpoint):hill=point
	for row in game.map_catalog:
		if row.id!=game.current_map or not row.has("objectives"):continue
		var data: Dictionary=row.objectives
		bases=[vector(data.red),vector(data.blue)];hill=vector(data.hill)
	if game.map_objectives.has("red") and game.map_objectives.has("blue"):bases=[game.map_objectives.red,game.map_objectives.blue]
	if game.map_objectives.has("hill"):hill=game.map_objectives.hill
	for i in range(2):captures.append(game.tf_capture.get(i,bases[i]) if kind=="tf" else bases[i])
	for i in range(2):flags.append({"carrier":0,"dropped":false,"position":bases[i],"return_at":0.0})
	clear_visuals()
func vector(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func spawns(team: int) -> Array:
	if kind in ["ctf","tf"] and team in [0,1] and not game.ctf_spawns[team].is_empty():return game.ctf_spawns[team]
	if not kind in ["ctf","tf"] or team<0 or bases.size()!=2:return game.spawn_points
	var result: Array=[]
	for point in game.spawn_points:
		if point.distance_squared_to(bases[team])<=point.distance_squared_to(bases[1-team]):result.append(point)
	return result if not result.is_empty() else game.spawn_points
func killed(victim: int,attacker: int) -> void:
	drop(victim)
	if not game.players.has(attacker):return
	var penalty: bool=attacker==victim or same_team(victim,attacker)
	game.players[attacker].kills+=-1 if penalty else 1
	if kind=="tdm" and game.players[attacker].team>=0:
		scores[game.players[attacker].team]+=-1 if penalty else 1
		check_limit()
	elif kind in ["dm","ig","cc"] and game.players[attacker].kills>=game.frag_limit:game._end_round()
func drop(id: int) -> void:
	for i in range(flags.size()):
		var f: Dictionary=flags[i]
		if f.carrier!=id:continue
		f.carrier=0
		var pos: Vector3=game.fighters[id].position if game.fighters.has(id) else bases[i]
		# Never strand the flag in a kill pit: return when there is no nearby floor.
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.4,pos-Vector3.UP*3,1))
		if hit.is_empty() or pos.y<game.fall_limit+2:return_flag(i)
		else:f.position=hit.position+Vector3.UP*.08;f.dropped=true;f.return_at=game.clock+30
		game._announcement.rpc(TEAMS[i]+" flag dropped")
func return_flag(team: int) -> void:
	flags[team]={"carrier":0,"dropped":false,"position":bases[team],"return_at":0.0}
func nearby(id: int,pos: Vector3,radius: float) -> bool:
	var origin: Vector3=game.fighters[id].position
	var offset:=origin-pos
	if absf(offset.y)>1.8 or Vector2(offset.x,offset.z).length()>radius:return false
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.8,pos+Vector3.UP*.8,1)).is_empty()
func tick(delta: float) -> void:
	if not game.multiplayer.is_server() or game.intermission>0:return
	special.tick(delta);fortress.tick(delta)
	if kind in ["ctf","tf"]:
		for i in range(2):
			var f: Dictionary=flags[i]
			if f.carrier!=0:
				if not game.players.has(f.carrier) or game.players[f.carrier].dead:drop(f.carrier)
				else:f.position=game.fighters[f.carrier].position
			elif f.dropped and game.clock>=f.return_at:
				return_flag(i);game._announcement.rpc(TEAMS[i]+" flag returned")
		for id in game.players:
			var s: Dictionary=game.players[id]
			if s.spectator or s.dead or s.team<0:continue
			var own: int=s.team;var enemy:=1-own
			if kind!="tf" and flags[own].dropped and nearby(id,flags[own].position,1.15):
				return_flag(own);game._announcement.rpc(s.name+" returned the "+TEAMS[own]+" flag")
			if flags[enemy].carrier==0 and nearby(id,flags[enemy].position,1.15):
				flags[enemy].carrier=id;flags[enemy].dropped=false;s.invulnerable=0
				fortress.revealed(id)
				game._announcement.rpc(s.name+" took the "+TEAMS[enemy]+" flag")
			if flags[enemy].carrier==id and (kind=="tf" or flags[own].carrier==0 and not flags[own].dropped) and nearby(id,captures[own] if kind=="tf" else bases[own],1.4):
				return_flag(enemy);scores[own]+=1;game._announcement.rpc(TEAMS[own]+" captured the flag!");check_limit()
				if game.intermission>0:return
	elif kind=="koth":
		var present: Array=[false,false]
		for id in game.players:
			var s: Dictionary=game.players[id]
			if not s.spectator and not s.dead and s.team>=0 and nearby(id,hill,3.0):present[s.team]=true
		var owner: int=-2 if present[0] and present[1] else 0 if present[0] else 1 if present[1] else -1
		if owner!=hill_owner:hill_credit=0.0
		hill_owner=owner
		if owner>=0:
			hill_credit+=delta
			while hill_credit>=1.0:
				scores[owner]+=1;hill_credit-=1.0;check_limit()
				if game.intermission>0:return
func limit() -> int:return capture_limit if kind in ["ctf","tf"] else hill_limit if kind=="koth" else game.frag_limit
func check_limit() -> void:
	if maxi(scores[0],scores[1])>=limit():game._end_round()
func result() -> String:
	return ("DRAW" if scores[0]==scores[1] else TEAMS[0 if scores[0]>scores[1] else 1]+" WINS")+" · %d : %d"%[scores[0],scores[1]]
func status(id: int=0) -> String:
	if not team_game():return kind.to_upper()+" · %d FRAGS"%game.frag_limit
	var text: String=kind.to_upper()+" · RED %d  BLUE %d / %d"%[scores[0],scores[1],limit()]
	if game.players.has(id) and game.players[id].team>=0:text+=" · YOU: "+TEAMS[game.players[id].team]
	if kind in ["ctf","tf"] and flags.size()==2:
		for i in range(2):text+=" · "+TEAMS[i]+" FLAG "+("TAKEN" if flags[i].carrier!=0 else "DROPPED" if flags[i].dropped else "HOME")
	elif kind=="koth":text+=" · HILL "+("CONTESTED" if hill_owner==-2 else "OPEN" if hill_owner==-1 else TEAMS[hill_owner])
	if kind=="ft":text+=" · "+("FROZEN · THAW %.1f / 3s"%special.frozen[id] if special.frozen.has(id) else "STAY NEAR FROZEN TEAMMATES TO THAW")
	return text+fortress.status(id)
func snapshot() -> Dictionary:
	return {"kind":kind,"scores":scores.duplicate(),"bases":bases.duplicate(),"captures":captures.duplicate(),"flags":flags.duplicate(true),"hill":hill,"owner":hill_owner,"limit":limit(),"friendly_fire":friendly_fire,"frozen":special.frozen.duplicate(),"freeze_reset":special.reset_at,"fortress":fortress.snapshot()}
func receive(data: Dictionary) -> void:
	if data.is_empty():return
	special.frozen=data.get("frozen",{});special.reset_at=data.get("freeze_reset",0.0)
	kind=data.kind;fortress.receive(data.get("fortress",{}));scores=data.scores;bases=data.bases;captures=data.get("captures",bases);flags=data.flags;hill=data.hill;hill_owner=data.owner;friendly_fire=data.friendly_fire
	if kind in ["ctf","tf"]:capture_limit=data.limit
	elif kind=="koth":hill_limit=data.limit
func clear_visuals() -> void:
	if is_instance_valid(visuals):visuals.free()
	visuals=null;visual_key=""
func draw_objectives() -> void:
	if game.headless:return
	fortress.draw()
	for id in game.fighters:game.fighters[id].set_frozen(special.frozen.has(id),float(special.frozen.get(id,0.0)))
	var key: String=kind+str(bases)+str(hill)
	if visual_key!=key or not is_instance_valid(visuals):
		clear_visuals();visual_key=key
		visuals=Node3D.new();game.get_node("Map").add_child(visuals)
		if kind in ["ctf","tf"] and bases.size()==2:
			for i in range(2):
				marker(bases[i],COLORS[i],TEAMS[i]+" FLAG",1.4)
				if captures.size()==2 and captures[i].distance_to(bases[i])>2:marker(captures[i],COLORS[i],TEAMS[i]+" CAPTURE",1.4)
				var flag:=preload("res://deathmatch/modes/flag.gd").create(i);flag.name="Flag"+str(i);visuals.add_child(flag)
		elif kind=="koth":marker(hill,Color("dbb66c"),"HILL · HOLD TO SCORE",3.0)
	if kind in ["ctf","tf"] and flags.size()==2:
		for i in range(2):
			var flag: Node3D=visuals.get_node("Flag"+str(i))
			flag.position=flags[i].position+Vector3.UP*(1.1 if flags[i].carrier!=0 else 0.0)
			flag.visible=flags[i].carrier!=game.multiplayer.get_unique_id()
func marker(pos: Vector3,color: Color,title: String,radius: float) -> void:
	var root:=Node3D.new();root.position=pos;visuals.add_child(root)
	var mesh:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=radius-.06;ring.outer_radius=radius
	mesh.mesh=ring;mesh.position.y=.10;mesh.material_override=preload("res://deathmatch/art.gd").material(color,0,.5);root.add_child(mesh)
	var label:=Label3D.new();label.text=title;label.position.y=2.6;label.font_size=40;label.pixel_size=.006;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;root.add_child(label)
