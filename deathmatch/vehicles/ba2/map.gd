extends RefCounted
## Read TB gameplay markers from the compiled BSP; no external layout file needed.
static func configure(game,entities: Array) -> bool:
	var route: Array=[];var spawns: Array=[[],[],[]];var defenders: Array=[];var stations: Array=[];var gate: Node3D
	var yaw_by_point: Dictionary={}
	var vantages: Array=[]
	for node in entities:
		var e: Dictionary=node.attributes;var kind: String=e.get("classname","")
		var point: Vector3=node.global_position-Vector3.UP*.70
		if kind=="info_tb_route":route.append({"order":int(e.get("order",0)),"position":point})
		elif kind=="info_tb_spawn":
			var team:=int(e.get("team",0));var stage:=clampi(int(e.get("stage",0)),0,2)
			if team==0:spawns[stage].append(point)
			elif team==1:defenders.append(point)
			yaw_by_point[point]=deg_to_rad(float(e.get("angle",0)))
		elif kind=="info_tb_resupply":stations.append(point)
		elif kind=="info_tb_vantage":vantages.append({"position":point,"distance":float(e.get("distance",0)),"side":int(e.get("side",0))})
		elif kind in ["info_tb_checkpoint","info_tb_goal"] and not game.headless:
			var label:=Label3D.new();label.name="TBObjectiveLabel";node.add_child(label)
			label.text="CHECKPOINT %s · +3:00"%e.get("stage","") if kind=="info_tb_checkpoint" else "BLUE BASE · DELIVER TITAN"
			label.position.y=11;label.font_size=44;label.pixel_size=.008;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		elif e.get("tb_gate","")=="1":gate=node
	if route.size()<2 or route.size()>64 or spawns.any(func(group):return group.is_empty()) or defenders.is_empty():return false
	route.sort_custom(func(a,b):return a.order<b.order)
	var points: Array=route.map(func(row):return row.position)
	game.spawn_points.clear();game.spawn_yaws.clear()
	for group in spawns+[defenders]:
		for point in group:game.spawn_points.append(point);game.spawn_yaws.append(yaw_by_point[point])
	game.ctf_spawns=[spawns[0].duplicate(),defenders.duplicate()]
	var tb=game.match_mode.titanball;tb.configure(spawns,defenders,stations,vantages)
	if gate:tb.register_gate(gate)
	game.match_mode.fortress.walkers.configure([{"id":"test","points":points,"loop":false,"team":tb.ATTACKERS}])
	game.map_objectives["red"]=points.front();game.map_objectives["blue"]=points.back()
	return true
