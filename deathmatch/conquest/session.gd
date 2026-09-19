extends RefCounted
const Rules=preload("res://deathmatch/conquest/rules.gd")
const MAP_ID="prototype_km1"
const MAP_PATH="res://maps/Benchmark1km/prototype_km1.bsp"
const MAP_HASH="727ebb90f7c4239b1a3a3e6fde4bd713a971ba2b552444afe1a16888d7599ca3"
const PROTOCOL="fpsloppa-cq-experimental-1"
var game
var rules=Rules.new()
var labels: Array=[]
func setup(arena) -> void:game=arena
func install() -> String:
	var path: String=game.Maps.Paths.resolve(MAP_PATH)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=MAP_HASH:return "CQ requires the matching baked Vesper map; see docs/CONQUEST.md."
	if not OS.has_feature("dedicated_server") and not FileAccess.file_exists(game.Maps.Paths.resolve("res://maps/Benchmark1km/zones-lightmap1.scn")):return "CQ requires the prepared Vesper scene cache."
	game.map_catalog.append({"id":MAP_ID,"title":"Vesper Megalopolis · CONQUEST","path":path,"scene":game.Maps.Paths.resolve("res://maps/Benchmark1km/zones.scn"),"sha256":MAP_HASH,"size":24197612,"modes":["cq"]})
	game.selected_map=MAP_ID
	return ""
func reset() -> void:
	rules.reset();labels.clear()
	for state in game.players.values():state.erase("cq_started")
func spawn_points(id: int) -> Array:
	var state: Dictionary=game.players[id]
	var zone: int
	if not state.get("cq_started",false):
		# Eight persistent four-person deployment groups on each team.
		if not state.has("cq_group_zone"):
			var counts: Dictionary={}
			for other in game.players.values():
				if other.team==state.team and other.has("cq_group_zone"):counts[other.cq_group_zone]=int(counts.get(other.cq_group_zone,0))+1
			zone=-1
			for candidate in 16:
				if Rules.INITIAL[candidate]==state.team and int(counts.get(candidate,0))<4:zone=candidate;break
			if zone<0:return []
			state.cq_group_zone=zone
		zone=int(state.cq_group_zone)
		if rules.owners[zone]!=state.team:zone=rules.nearest(state.team,Rules.center(zone))
		state.cq_started=true
	else:zone=rules.nearest(state.team,game.fighters[id].position)
	if zone<0:return []
	return game.spawn_points.filter(func(point):return Rules.district(point)==zone)
func configure_pickups() -> void:
	# Deterministic ordering shared by server and clients. No paired sniper caches.
	for pickup in game.pickups:
		if is_instance_valid(pickup.node):pickup.node.free()
	game.pickups.clear()
	for zone in 16:
		var home: bool=zone in Rules.HOMEBASES
		var equipment: Array=[
			["weapon",6 if home else 3,Vector3(-7,0,0),6 if home else 20],
			["weapon",8 if home else 5,Vector3(7,0,0),10 if home else 100],
			["weapon",9 if home else 7,Vector3(0,0,7),8 if home else 60],
			["weapon",4 if home else 10,Vector3(0,0,-7),10 if home else 15],
			["health",100 if home else 25,Vector3(10,0,10),0],
			["armor",2 if home else 1,Vector3(-10,0,-10),150 if home else 50],
			["ammo",2 if home else 0,Vector3(-10,0,10),6 if home else 50],
			["ammo",3,Vector3(10,0,-10),25]]
		for row in equipment:
			var pickup: Dictionary={"kind":row[0],"item":row[1],"position":Rules.center(zone)+row[2],"amount":row[3],"available":true,"respawn":0.0,"node":null}
			if row[0]=="armor":pickup.title="SHIELD BELT" if home else "THIGHPADS"
			if row[0]=="health" and home:pickup.title="KEG O’ HEALTH"
			if not game.headless:pickup.node=game._pickup_art(pickup)
			game.pickups.append(pickup)
func tick(delta: float) -> void:
	# The coordinator owns capture and match time, never individual workers.
	if is_instance_valid(game.district_worker):return
	var present: Array=[]
	for zone in 16:present.append([false,false])
	for id in game.players:
		var state: Dictionary=game.players[id]
		if state.dead or state.spectator or not state.team in [0,1]:continue
		var zone:=Rules.district(game.fighters[id].position)
		if game.match_mode.nearby(id,Rules.center(zone),Rules.RADIUS):present[zone][state.team]=true
	var changed:=rules.advance(delta,present)
	game.match_mode.scores=rules.scores()
	for zone in changed:game._announcement.rpc("District %02d captured by %s"%[zone+1,game.match_mode.TEAMS[rules.owners[zone]]])
	if rules.winner()>=0:game._end_round()
func result() -> String:
	var winner:=rules.winner(true);var scores:=rules.scores()
	return ("DRAW" if winner<0 else game.match_mode.TEAMS[winner]+" WINS")+" · HOMEBASES %d : %d"%scores
func status(id: int) -> String:
	var scores:=rules.scores()
	var text:="CQ · HOMEBASES RED %d BLUE %d / 4"%scores
	if game.players.has(id) and game.fighters.has(id):
		var zone:=Rules.district(game.fighters[id].position)
		text+=" · DISTRICT %02d · %s"%[zone+1,game.match_mode.TEAMS[rules.owners[zone]]]
		text+=" · R %.0f B %.0f / %d"%[rules.progress[zone][0],rules.progress[zone][1],Rules.threshold(zone)]
		if rules.contested[zone]:text+=" · CONTESTED"
	return text
func radio_allowed(sender: int,recipient: int) -> bool:
	if not game.fighters.has(sender) or not game.fighters.has(recipient):return false
	return Rules.radio_connected(Rules.district(game.fighters[sender].position),Rules.district(game.fighters[recipient].position))
func draw(parent: Node3D) -> void:
	labels.clear()
	for zone in 16:
		var color: Color=game.match_mode.COLORS[rules.owners[zone]]
		var label: Label3D=game.match_mode.marker(Rules.center(zone),color,"",Rules.RADIUS)
		labels.append(label)
		var flag:=preload("res://deathmatch/modes/flag.gd").create(rules.owners[zone],false)
		flag.position=Rules.center(zone);parent.add_child(flag)
func update_labels() -> void:
	for zone in mini(16,labels.size()):
		if not is_instance_valid(labels[zone]):continue
		var team: int=1-rules.owners[zone]
		labels[zone].text=("HOMEBASE" if zone in Rules.HOMEBASES else "PERIMETER")+" %02d · %s\n"%[zone+1,game.match_mode.TEAMS[rules.owners[zone]]]
		labels[zone].text+="CONTESTED" if rules.contested[zone] else "LOCKED · CAPTURE ALL 3 PERIMETERS" if not rules.unlocked(zone,team) else "%s %.0f / %d"%[game.match_mode.TEAMS[team],rules.progress[zone][team],Rules.threshold(zone)]
