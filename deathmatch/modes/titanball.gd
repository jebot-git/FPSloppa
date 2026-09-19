extends RefCounted
## Server-owned, once-per-round route extensions. Pilot changes never reset these.
const PREPARATION_SECONDS=60.0
const BASE_SECONDS=600.0
const EXTENSION_SECONDS=180.0
const ROUTE_METRES=350.0
const CHECKPOINTS=[80.0,230.0]
# Conservative full animated footprint radius, including the rear legs on bends.
const CLEARANCE_METRES=10.0
var mode_ref: WeakRef
var mode:
	get:return mode_ref.get_ref()
var game:
	get:return mode.game
const ATTACKERS=0 # Red escorts; blue defends.
const DEFENDERS=1
var attacker_spawns: Array=[]
var defender_spawns: Array=[]
var preparation_left:=PREPARATION_SECONDS
var stations: Array=[]
var vantages: Array=[]
var gate_ref: WeakRef
var gate_closed:=Vector3.ZERO
var winner:=-1
var cleared:=0
var route_id:=""
var progress:=0.0
func setup(value) -> void:mode_ref=weakref(value)
func reset() -> void:
	cleared=0;route_id="";progress=0.0;winner=-1;preparation_left=PREPARATION_SECONDS
	update_gate();install_stations()
	if mode.kind=="tb":game.time_limit=BASE_SECONDS;game.round_left=BASE_SECONDS
func configure(forward: Array,base: Array,supply: Array=[],high_ground: Array=[]) -> void:
	attacker_spawns=forward.duplicate(true);defender_spawns=base.duplicate();stations=supply.duplicate()
	vantages=high_ground.duplicate(true)
	if game.multiplayer.is_server():install_stations()
func preparing() -> bool:return mode.kind=="tb" and preparation_left>0.0
func advance_time(delta: float) -> float:
	if not game.multiplayer.is_server():return 0.0
	var used:=minf(preparation_left,delta);preparation_left=maxf(0.0,preparation_left-delta)
	update_gate()
	if used>0.0 and preparation_left==0.0:game._announcement.rpc("TITANBALL · HANGAR OPEN · ESCORT THE TITAN")
	return delta-used
func register_gate(node: Node3D) -> void:
	gate_ref=weakref(node);gate_closed=node.position;update_gate()
func update_gate() -> void:
	var gate=gate_ref.get_ref() if gate_ref else null
	if is_instance_valid(gate):gate.position=gate_closed+(Vector3.ZERO if preparing() else Vector3.UP*15.)
	else:
		gate=game.get_node_or_null("Map/HangarGate")
		if gate:gate.position.y=0.0 if preparing() else 15.0
func install_stations() -> void:
	if not game.multiplayer.is_server():return
	var tf=mode.fortress
	for key in tf.buildings.keys():
		if tf.buildings[key].get("tb_station",false):tf.buildings.erase(key)
	for i in stations.size():tf.buildings[-9000-i]={"owner":0,"team":-1,"position":stations[i],"kind":"dispenser","hp":150,"ready":0.,"next":0.,"expires":0.,"map_owned":true,"universal":true,"tb_station":true,"invulnerable":true}
func spawns(team: int) -> Array:
	if team==ATTACKERS and attacker_spawns.size()==3:return attacker_spawns[cleared]
	if team==DEFENDERS and not defender_spawns.is_empty():return defender_spawns
	return game.ctf_spawns[team] if team in [0,1] and not game.ctf_spawns[team].is_empty() else game.spawn_points
func finish(team: int) -> void:
	if mode.kind!="tb" or not game.multiplayer.is_server() or winner!=-1 or game.intermission>0:return
	winner=team;mode.scores[team]=1;game._end_round()
func timeout() -> void:finish(DEFENDERS)
func result() -> String:
	return "RED ATTACKERS WIN · TITAN DELIVERED" if winner==ATTACKERS else "BLUE DEFENDERS WIN · TITAN STOPPED" if winner==DEFENDERS else "TITANBALL ROUND ENDED"
func observe(key: String,row: Dictionary) -> void:
	if mode.kind!="tb" or not game.multiplayer.is_server() or not game.active or game.map_loading or game.lobby.active() or game.intermission>0 or game.round_left<=0 or winner!=-1 or preparing():return
	if row.get("loop",false):return
	if route_id.is_empty():route_id=key
	if route_id!=key:return
	progress=maxf(progress,float(row.distance))
	while cleared<CHECKPOINTS.size() and progress>=CHECKPOINTS[cleared]+CLEARANCE_METRES:
		cleared+=1;game.round_left+=EXTENSION_SECONDS
		game._announcement.rpc("TITANBALL · CHECKPOINT %d CLEAR · +3:00 · ATTACKER SPAWNS ADVANCED"%cleared)
	if cleared==2 and float(row.distance)>=ROUTE_METRES-.02 and float(row.get("speed",1.0))<.0001:finish(ATTACKERS)
func snapshot() -> Dictionary:return {"cleared":cleared,"route":route_id,"progress":progress,"winner":winner,"attack_spawns":attacker_spawns,"defend_spawns":defender_spawns,"preparation":preparation_left,"stations":stations,"vantages":vantages}
func receive(data: Dictionary) -> void:
	winner=int(data.get("winner",-1));configure(data.get("attack_spawns",[]),data.get("defend_spawns",[]),data.get("stations",[]),data.get("vantages",[]))
	preparation_left=float(data.get("preparation",0.));update_gate()
	cleared=clampi(int(data.get("cleared",0)),0,CHECKPOINTS.size());route_id=str(data.get("route",""));progress=float(data.get("progress",0.0))
func status(id: int=0) -> String:
	var team: int=game.players.get(id,{}).get("team",-1)
	var role: String="ATTACK · PILOT TO BLUE BASE" if team==ATTACKERS else "DEFEND · STOP THE TITAN" if team==DEFENDERS else "RED ATTACKS · BLUE DEFENDS"
	return ("TB · PREPARE %d:%02d · "%[int(ceil(preparation_left))/60,int(ceil(preparation_left))%60] if preparing() else "TB · ")+role+" · CHECKPOINTS %d / 2 · %d / %d m"%[cleared,mini(int(ROUTE_METRES),int(progress)),int(ROUTE_METRES)]
