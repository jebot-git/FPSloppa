extends RefCounted
## Ashfall's walking space is one connected street/ramp component. Roofs and
## disconnected wreck tops are physical cover, but not walking destinations.
static func retain_walkable_component(mesh: NavigationMesh) -> Dictionary:
	var edges: Dictionary={};var neighbors: Array=[]
	for i in mesh.get_polygon_count():neighbors.append([])
	for i in mesh.get_polygon_count():
		var polygon:=mesh.get_polygon(i)
		for j in polygon.size():
			var a:=polygon[j];var b:=polygon[(j+1)%polygon.size()];var key:=Vector2i(mini(a,b),maxi(a,b))
			if edges.has(key):neighbors[i].append(edges[key]);neighbors[edges[key]].append(i)
			else:edges[key]=i
	var seen: Dictionary={};var largest: Array=[];var components:=0
	for i in neighbors.size():
		if seen.has(i):continue
		var queue: Array=[i];seen[i]=true;var cursor:=0;components+=1
		while cursor<queue.size():
			for j in neighbors[queue[cursor]]:
				if not seen.has(j):seen[j]=true;queue.append(j)
			cursor+=1
		if queue.size()>largest.size():largest=queue
	var polygons: Array=[]
	largest.sort()
	for i in largest:polygons.append(mesh.get_polygon(i))
	var report: Dictionary={"original_polygons":mesh.get_polygon_count(),"retained_polygons":polygons.size(),"components":components}
	mesh.clear_polygons()
	for polygon in polygons:mesh.add_polygon(polygon)
	mesh.set_meta("ashfall_walkable_component",report)
	return report
