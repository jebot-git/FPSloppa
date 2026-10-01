extends SceneTree
func _initialize():run.call_deferred()
func run():
	var rows:=[]
	for file in DirAccess.get_files_at("res://deathmatch/weapons/fidelity"):
		if not file.ends_with(".scn"):continue
		var model=load("res://deathmatch/weapons/fidelity/"+file).instantiate()
		var total:=0;var parts:=[]
		for node in model.find_children("*","MeshInstance3D",true,false):
			if not node.mesh:continue
			var count:=0
			for surface in node.mesh.get_surface_count():
				var a=node.mesh.surface_get_arrays(surface)
				count+=a[Mesh.ARRAY_INDEX].size()/3 if a[Mesh.ARRAY_INDEX]!=null and a[Mesh.ARRAY_INDEX].size()>0 else a[Mesh.ARRAY_VERTEX].size()/3
			parts.append({"name":str(node.name),"triangles":count});total+=count
		parts.sort_custom(func(a,b):return a.triangles>b.triangles)
		rows.append({"key":file.trim_suffix(".scn"),"triangles":total,"parts":parts});model.free()
	rows.sort_custom(func(a,b):return a.triangles>b.triangles)
	DirAccess.make_dir_recursive_absolute("res://test-results/weapon-stock")
	FileAccess.open("res://test-results/weapon-stock/arsenal-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	for row in rows:
		if row.triangles>10000:print(row.key,' ',row.triangles,' ',row.parts.slice(0,5))
	quit()
