extends RefCounted
## Reference-led native Blender models, shared between deployed and carried art.
const Props=preload("res://deathmatch/tribes/prop_library.gd")
static func make(kind: String,team: int=0,packed: bool=false) -> Node3D:
	var root=Props.make(kind,team)
	if packed:
		root.scale=Vector3.ONE*.3
		# Move body and moving head together; never detach the carried turret head.
		for child in root.get_children():if child is Node3D:child.position.y-=.7
	return root
