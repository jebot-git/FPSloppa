extends Node
## Bounded local models and team-only world/aim markers, shared by desktop and XR.
var rules
var nodes: Dictionary={}
var markers: Dictionary={}
var next_update:=0.0
var epoch:=-1
var visible_markers: Dictionary={}
var selected_target:=""
func setup(value):rules=value
func _exit_tree():
	for node in nodes.values()+markers.values():
		if is_instance_valid(node):node.queue_free()
func update():
	var game=rules.game
	if epoch!=game.map_epoch:epoch=game.map_epoch;next_update=0.0
	if game.clock<next_update and rules.enabled():return
	next_update=game.clock+.1
	var present: Dictionary={}
	if rules.enabled():
		for key in rules.recovery.rows:
			var row: Dictionary=rules.recovery.rows[key];var tag: String="r%d"%key;present[tag]=true
			if not nodes.has(tag):
				var node=preload("res://deathmatch/tribes/equipment.gd").model("kit" if row.kind=="patch" else "pack")
				node.scale=Vector3.ONE*(2.6 if row.kind=="corpse" else 1.7);game.add_child(node);nodes[tag]=node
				var label:=Label3D.new();label.name="Info";label.font_size=24;label.pixel_size=.003;label.position.y=.15;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.add_child(label)
			nodes[tag].global_position=row.position
			var p: Dictionary=row.payload;var count: int=p.ammo.reduce(func(total,v):return total+v,0)
			nodes[tag].get_node("Info").text=("RECOVERY" if row.kind=="corpse" else "REPAIR PATCH" if row.kind=="patch" else rules.Arsenal.PACKS[p.pack].name if p.pack!="none" else "AMMO" if row.kind=="ammo" else "WEAPON")+(" · %d"%count if count>0 else "")
		for key in rules.targeting.beacons:
			var tag: String="b%d"%key;var row: Dictionary=rules.targeting.beacons[key];present[tag]=true
			if not nodes.has(tag):
				var node:=Node3D.new();game.add_child(node);nodes[tag]=node
				var art=preload("res://deathmatch/art.gd");art.box(node,Vector3.ZERO,Vector3(.22,.12,.22),art.material(Color("354651"),.6));art.box(node,Vector3(0,.09,0),Vector3(.06,.1,.06),art.material(Color("f48c75") if row.team==0 else Color("7bbcf5"),.2,1))
			nodes[tag].global_position=row.position
			var y: Vector3=row.normal;var x: Vector3=Vector3.FORWARD.cross(y).normalized() if absf(y.z)<.95 else Vector3.RIGHT.cross(y).normalized()
			nodes[tag].global_basis=Basis(x,y,x.cross(y))
	for key in nodes.keys():
		if not present.has(key):nodes[key].queue_free();nodes.erase(key)
	visible_markers.clear()
	for marker in markers.values():marker.hide()
	var s: Dictionary=game.local_state();var id: int=game.multiplayer.get_unique_id()
	if not rules.enabled() or s.get("dead",true) or s.get("spectator",false) or s.get("team",-1) not in [0,1] or s.get("weapon",-1) not in [4,7,11]:purge_markers();return
	var targets: Array=rules.targeting.targets(s.team)
	targets.sort_custom(func(a,b):return a.position.distance_squared_to(game.fighters[id].position)<b.position.distance_squared_to(game.fighters[id].position))
	var candidates: Array=targets.slice(0,8)
	var origin: Vector3=game._shot_solution(id).origin
	var forward: Vector3=-game.camera.global_basis.z
	if game.is_vr():forward=-game.xr_rig.head.global_basis.z
	var chosen: Dictionary={};var best:=-2.0
	for row in candidates:
		mark(row.key,row.position+Vector3.UP*.3,"◇ "+row.name,Color("dfbe78"))
		var score: float=forward.dot((row.position-origin).normalized())+(.25 if row.key==selected_target else 0.0)
		if score>best:chosen=row;best=score
	# One collision-checked solution per 10 Hz update, not an arc for every
	# beacon. Head direction plus hysteresis keeps the chosen target stable.
	if not chosen.is_empty():
		selected_target=chosen.key
		var solution: Dictionary=rules.targeting.solution(id,chosen.position)
		if not solution.is_empty():mark("aim"+chosen.key,origin+solution.direction*8,"⊕ "+chosen.name+" %0.1fs"%solution.time,Color("86efbe"))
	purge_markers()
func purge_markers():
	for key in markers.keys():
		if not visible_markers.has(key):markers[key].queue_free();markers.erase(key)
func mark(key: String,point: Vector3,text: String,color: Color):
	visible_markers[key]=true
	if not markers.has(key):
		var label:=Label3D.new();label.font_size=28;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;rules.game.add_child(label);markers[key]=label
	markers[key].global_position=point;markers[key].text=text;markers[key].modulate=color;markers[key].show()
