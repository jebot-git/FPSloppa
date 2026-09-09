extends SceneTree
const Models=preload("res://deathmatch/pickups/models.gd")
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():
	var arrays: Array=[]
	for kind in ["health","armor","ammo","bonus"]:
		for item in range(4 if kind=="ammo" else 3 if kind=="armor" else 2 if kind=="bonus" else 1):
			var node=Models.create(kind,item)
			check(node.mesh.get_surface_count()==1,kind+str(item)+" uses one draw surface")
			var vertices:PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(vertices.size()>100 and vertices.size()<20000 and Array(vertices).all(func(v):return v.is_finite()),kind+str(item)+" has bounded detailed geometry")
			check(node.mesh.get_aabb().size.length()<1.1,kind+str(item)+" remains inside pickup display footprint")
			if kind=="ammo":arrays.append(vertices)
			var second=Models.create(kind,item)
			check(second.mesh==node.mesh,kind+str(item)+" reuses cached mesh")
			node.free();second.free()
	check(arrays[0]!=arrays[1] and arrays[1]!=arrays[2] and arrays[2]!=arrays[3],"All four ammunition types have distinct silhouettes")
	for pair in [["health",25,100],["armor",1,2]]:
		var normal=Models.create(pair[0],pair[1]);var mega=Models.create(pair[0],pair[2])
		check(normal.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]!=mega.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR],pair[0]+" mega variant has a distinct material palette")
		normal.free();mega.free()
	print("PICKUP_MODELS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
