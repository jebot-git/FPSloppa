extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
	var mesh: NavigationMesh=load("res://maps/navigation/tb_ashfall.res")
	var vertices:=mesh.get_vertices();var edges: Dictionary={};var neighbors: Array=[]
	for i in mesh.get_polygon_count():neighbors.append([])
	for i in mesh.get_polygon_count():
		var polygon:=mesh.get_polygon(i)
		for j in polygon.size():
			var a:=polygon[j];var b:=polygon[(j+1)%polygon.size()];var key:=Vector2i(mini(a,b),maxi(a,b))
			if edges.has(key):neighbors[i].append(edges[key]);neighbors[edges[key]].append(i)
			else:edges[key]=i
	var seen: Dictionary={};var groups: Array=[]
	for i in neighbors.size():
		if seen.has(i):continue
		var queue: Array=[i];seen[i]=true;var cursor:=0
		while cursor<queue.size():
			for j in neighbors[queue[cursor]]:
				if not seen.has(j):seen[j]=true;queue.append(j)
			cursor+=1
		groups.append(queue)
	groups.sort_custom(func(a,b):return a.size()>b.size())
	var report: Array=[]
	for group in groups:
		var bounds:=AABB(vertices[mesh.get_polygon(group[0])[0]],Vector3.ZERO)
		for i in group:
			for v in mesh.get_polygon(i):bounds=bounds.expand(vertices[v])
		report.append({"polygons":group.size(),"bounds":bounds})
	print("NAV_COMPONENTS ",JSON.stringify(report))
	quit()
