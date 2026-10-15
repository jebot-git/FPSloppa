extends RefCounted
## Carried kit, independent of deployed box/turret/drone world entities.
static func radio() -> Node3D:
	var root:=Node3D.new()
	var art=preload("res://deathmatch/art.gd")
	art.box(root,Vector3(0,.015,0),Vector3(.065,.10,.035),art.material(Color("303a30"),.25))
	art.box(root,Vector3(-.02,.09,0),Vector3(.006,.09,.006),art.material(Color("171b17")))
	return root
static func utility(key:String) -> Node3D:
	if key in ["jetpack","healing_grenade"]:
		return preload("res://deathmatch/conquest/classes/grenade_visuals.gd").model(3 if key=="healing_grenade" else 0)
	if key in ["recon","recon_drone"]:
		var node:Node3D=load("res://deathmatch/models/cloak_device/cloak_device.glb").instantiate()
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			for index in mesh.mesh.get_surface_count():
				var material:Material=mesh.get_active_material(index)
				if material.resource_name.contains("GlassCell"):
					var energy:=ShaderMaterial.new();energy.shader=preload("res://deathmatch/models/cloak_device/cell_surface.gdshader");mesh.set_surface_override_material(index,energy)
		preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(node)
		return node
	var models=preload("res://deathmatch/conquest/classes/models.gd")
	var node:Node3D=models.weapon(7,"cq_medic" if key=="medical" else "cq_technician") if key in ["medical","engineering"] else models.weapon(8,"cq_scout")
	node.scale=Vector3.ONE*.35
	return node
