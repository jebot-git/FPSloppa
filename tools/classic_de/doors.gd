extends RefCounted
## Bake open-door connectivity. Runtime collision and activation are tested separately.
static func open_for_navigation(level: Node) -> Array:
	var restored: Array=[]
	for node in level.find_children("*","CollisionObject3D",true,false):
		if node.get_script()!=preload("res://deathmatch/maps/entity.gd"):continue
		if node.attributes.get("classname","")!="func_door" or int(node.attributes.get("_de_reset",0))!=1:continue
		restored.append([node,node.collision_layer]);node.collision_layer=0
	return restored
static func restore(rows: Array) -> void:
	for row in rows:row[0].collision_layer=row[1]
