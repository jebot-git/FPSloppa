extends RefCounted
## Remove a redundant baked polygon only when its entire ground footprint is
## already covered by neighbours sharing an over-owned edge. Never fill gaps or
## silence invalid topology: unfamiliar cases fail preparation for inspection.
static func edge_owners(mesh: NavigationMesh) -> Dictionary:
	var vertices:=mesh.vertices;var edges: Dictionary={}
	for index in mesh.get_polygon_count():
		var poly:=mesh.get_polygon(index)
		for j in poly.size():
			var a: Vector3=vertices[poly[j]];var b: Vector3=vertices[poly[(j+1)%poly.size()]]
			var key: Array=[a,b] if a<b else [b,a]
			if not edges.has(key):edges[key]=[]
			edges[key].append(index)
	return edges
static func footprint(mesh: NavigationMesh,index: int) -> PackedVector2Array:
	var result:=PackedVector2Array();var vertices:=mesh.vertices
	for vertex in mesh.get_polygon(index):result.append(Vector2(vertices[vertex].x,vertices[vertex].z))
	return result
static func area(poly: PackedVector2Array) -> float:
	var result:=0.0
	for i in poly.size():result+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(result)*.5
static func clean(mesh: NavigationMesh) -> Dictionary:
	var removed:=0
	for pass_index in 32:
		var edges:=edge_owners(mesh);var suspects: Dictionary={};var neighbours: Dictionary={}
		for owners in edges.values():
			if owners.size()<=2:continue
			for index in owners:
				suspects[index]=int(suspects.get(index,0))+1
				if not neighbours.has(index):neighbours[index]=[]
				for other in owners:
					if other!=index and other not in neighbours[index]:neighbours[index].append(other)
		if suspects.is_empty():return {"removed_redundant_polygons":removed,"unresolved_edges":0}
		var candidates: Array=suspects.keys();candidates.sort_custom(func(a,b):return suspects[a]>suspects[b])
		var redundant:=-1
		for index in candidates:
			var remains: Array=[footprint(mesh,index)]
			for other in neighbours[index]:
				var next: Array=[]
				for polygon in remains:next.append_array(Geometry2D.clip_polygons(polygon,footprint(mesh,other)))
				remains=next
				if remains.is_empty():break
			var uncovered:=0.0
			for polygon in remains:uncovered+=area(polygon)
			if uncovered<.0001:redundant=index;break
		if redundant<0:return {"removed_redundant_polygons":removed,"unresolved_edges":suspects.size()}
		var polygons: Array=[]
		for index in mesh.get_polygon_count():
			if index!=redundant:polygons.append(mesh.get_polygon(index))
		mesh.clear_polygons()
		for polygon in polygons:mesh.add_polygon(polygon)
		removed+=1
	return {"removed_redundant_polygons":removed,"unresolved_edges":-1}
