extends RefCounted
## Experimental UT99-style paired assaults. Only the server advances objectives.
var mode_ref: WeakRef
var mode:
	get:return mode_ref.get_ref()
var game:
	get:return mode.game
var leg:=0
var attacking:=0
var stage:=0
var checkpoint:=0
var budget:=0.0
var first_time:=-1.0
var first_finished:=false
var switching:=false
var finished:=false
var objectives: Array=[]
var message:=""
func setup(value) -> void:mode_ref=weakref(value)
func enabled() -> bool:return mode.kind=="as"
func supported() -> bool:
	var steps: Array=[]
	for row in game.map_assault:
		if row.kind=="info_as_objective":steps.append(int(row.get("step",0)))
	steps.sort()
	return steps==[1,2] and not game.ctf_spawns[0].is_empty() and not game.ctf_spawns[1].is_empty()
func reset() -> void:
	leg=0;attacking=0;stage=0;checkpoint=0;budget=0;first_time=-1;first_finished=false;switching=false;finished=false;message=""
	objectives.clear()
	if not enabled():return
	for row in game.map_assault:
		if row.kind=="info_as_objective":objectives.append(row.duplicate())
	objectives.sort_custom(func(a,b):return int(a.step)<int(b.step))
	install_sentries()
func install_sentries() -> void:
	mode.fortress.buildings.clear()
	var key:=100000
	for row in game.map_assault:
		if row.kind!="info_as_sentry":continue
		if key>=100016:break
		mode.fortress.buildings[key]={"owner":0,"team":1-attacking,"position":row.position,"kind":"sentry","hp":150,"ready":game.clock+3,"next":game.clock+3,"expires":game.clock+86400,"map_owned":true}
		key+=1
	for index in objectives.size():
		var hp:=clampi(int(objectives[index].get("health",0)),0,10000)
		if hp>0:mode.fortress.buildings[100100+index]={"owner":0,"team":1-attacking,"position":objectives[index].position,"kind":"compressor","hp":hp,"max_hp":hp,"objective":index,"ready":game.clock,"next":game.clock,"expires":game.clock+86400,"map_owned":true}
func spawns(team: int) -> Array:
	var role: String="attack" if team==attacking else "defend"
	var result: Array=[];var best:=0
	for row in game.map_assault:
		if row.kind!="info_as_spawn" or row.get("role","")!=role:continue
		var index:=int(row.get("checkpoint",0))
		if index>checkpoint or index<best:continue
		if index>best:result.clear();best=index
		result.append(row.position)
	return result if not result.is_empty() else game.ctf_spawns[0 if team==attacking else 1]
func tick(_delta: float) -> void:
	if not enabled() or not game.multiplayer.is_server() or finished or switching or objectives.size()!=2:return
	if budget<=0:budget=game.round_left
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.spectator or s.dead or s.team!=attacking:continue
		for row in game.map_assault:
			if row.kind=="info_as_checkpoint" and int(row.get("checkpoint",0))>checkpoint and mode.nearby(id,row.position,2.5):
				checkpoint=int(row.checkpoint);game._announcement.rpc("Attackers secured forward spawn "+str(checkpoint))
		# Tracked clients press the console or use the accessible Use binding.
		if not s.get("vr_device",false):activate(id)
func button_position(index: int) -> Vector3:
	return objectives[index].position+Vector3.UP*1.1
func activate(id: int) -> bool:
	if stage<objectives.size() and int(objectives[stage].get("health",0))>0:return false
	if not can_advance(id) or not mode.nearby(id,objectives[stage].position,1.4):return false
	advance()
	return true
func can_advance(id: int) -> bool:
	if not enabled() or not game.multiplayer.is_server() or not game.active or game.map_loading or game.lobby.active() or game.intermission>0 or finished or switching or stage>=objectives.size():return false
	if not game.players.has(id):return false
	var s: Dictionary=game.players[id]
	return not s.dead and not s.spectator and s.team==attacking and not mode.special.blocked(id)
func can_damage_objective(id: int,index: int) -> bool:
	return can_advance(id) and index==stage and int(objectives[index].get("health",0))>0
func destroyed(id: int,index: int) -> void:
	# Called only after the authoritative structure damage path exhausted its HP.
	if can_damage_objective(id,index) and not mode.fortress.buildings.has(100100+index):advance()
func advance() -> void:
	stage+=1
	for i in game.gates.size():
		var gate: Dictionary=game.gates[i]
		if int(gate.get("as_unlock",0))>0 and int(gate.as_unlock)<=stage:
			gate.until=game.clock+86400;game._gate_state.rpc(i,true)
	game._announcement.rpc("AS objective %d / %d: %s"%[stage,objectives.size(),objectives[stage-1].get("title","activated")])
	game.announcer.objective_completed();mode.clear_visuals()
	if stage==objectives.size():complete_leg(true)
func draw_button(parent: Node3D,index: int) -> void:
	if int(objectives[index].get("health",0))>0:return
	var art=preload("res://deathmatch/art.gd")
	var stand:=MeshInstance3D.new();var stem:=CylinderMesh.new();stem.top_radius=.10;stem.bottom_radius=.18;stem.height=1.0
	stand.mesh=stem;stand.position=objectives[index].position+Vector3.UP*.5;stand.material_override=art.material(Color("343941"));parent.add_child(stand)
	var button:=MeshInstance3D.new();var cap:=CylinderMesh.new();cap.top_radius=.16;cap.bottom_radius=.19;cap.height=.10 if index>=stage else .035
	button.mesh=cap;button.position=button_position(index);button.material_override=art.material(Color("67dba8") if index<stage else Color("eaaa45") if index==stage else Color("636773"),0,.5);parent.add_child(button)
	var label:=Label3D.new();label.text="PRESS / USE" if index==stage else "DONE" if index<stage else "LOCKED";label.position=button.position+Vector3.UP*.28;label.font_size=28;label.pixel_size=.003;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;parent.add_child(label)
func timeout() -> void:
	if enabled() and not switching and not finished:complete_leg(false)
func complete_leg(success: bool) -> void:
	if not game.multiplayer.is_server() or switching or finished:return
	if success:
		for row in game.map_assault:
			if row.kind=="info_as_cannon":
				var target:=Vector3(-float(row.get("target_y",0)),float(row.get("target_z",0)),-float(row.get("target_x",0)))/32.0
				game._ability_fx.rpc("explosion",row.position,row.position,attacking)
				game._ability_fx.rpc("explosion",target,target,attacking)
	var elapsed:=maxf(0.0,budget-game.round_left)
	if leg==0:
		first_finished=success;first_time=elapsed if success else -1.0;switching=true
		message=("RED completed the assault in %.2fs"%elapsed if success else "BLUE held the objectives")+" · switching attack/defend"
		game.intermission=8;game.round_message=message;game._announcement.rpc(message)
	else:
		finished=true
		# A returned assault must beat the first completion time; equal times draw.
		if success and (not first_finished or elapsed<first_time-.001):mode.scores=[0,1]
		elif success and first_finished and absf(elapsed-first_time)<=.001:mode.scores=[0,0]
		elif first_finished:mode.scores=[1,0]
		else:mode.scores=[0,0]
		message="DRAW · neither team completed the assault" if not success and not first_finished else "DRAW · equal completion times" if mode.scores==[0,0] else ("RED" if mode.scores[0]>0 else "BLUE")+" WINS THE ASSAULT"
		game._end_round()
func next_leg() -> void:
	leg=1;attacking=1;stage=0;checkpoint=0;switching=false
	budget=maxf(.001,first_time) if first_finished else game.time_limit
	game.round_left=budget;game.intermission=0;game.round_message=""
	for gate in game.gates:
		if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
		gate.open=false;gate.until=0
		if gate.has("base_position"):gate.node.position=gate.base_position
	for pickup in game.pickups:pickup.available=true;pickup.respawn=0
	for id in game.projectiles.keys():game._projectile_end.rpc(id,game.projectiles[id].position,7)
	install_sentries()
	for id in game.players:game._spawn(id)
	game.history.clear();mode.clear_visuals()
	game._announcement.rpc("BLUE attacks · RED defends · beat %.2fs"%budget if first_finished else "BLUE attacks · RED defends")
func status() -> String:
	return "AS · LEG %d/2 · %s ATTACKS · %s"%[leg+1,mode.TEAMS[attacking],objectives[stage].get("title","objective") if stage<objectives.size() else "ASSAULT COMPLETE"]
func snapshot() -> Dictionary:
	return {"leg":leg,"attacking":attacking,"stage":stage,"checkpoint":checkpoint,"budget":budget,"first_time":first_time,"first_finished":first_finished,"switching":switching,"finished":finished,"objectives":objectives.duplicate(true),"message":message}
func receive(data: Dictionary) -> void:
	for key in ["leg","attacking","stage","checkpoint","budget","first_time","first_finished","switching","finished","objectives","message"]:
		if data.has(key):set(key,data[key])
