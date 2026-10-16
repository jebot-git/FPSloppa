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
	if key=="turret":
		var kit:=Node3D.new();var sentry:Node3D=load("res://deathmatch/models/turret/turret.glb").instantiate();kit.add_child(sentry);sentry.scale=Vector3.ONE*.18;sentry.position=Vector3(0,-.1,-.1);kit.scale=Vector3.ONE*.65;return kit
	var node:Node3D=models.weapon(7,"cq_medic" if key=="medical" else "cq_technician") if key in ["medical","engineering"] else models.weapon(8,"cq_scout")
	node.scale=Vector3.ONE*(injector_scale() if key=="medical" else .35)
	return node

static func cloak_held_pose(grip:Transform3D)->Transform3D:
	# The cell is authored along +Y, while the closed palm's thumb axis is -Z.
	# Use the grip frame directly, like a cylindrical grenade, at its authored size.
	return grip*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0,-.018,-.018))

static func injector_grip()->Transform3D:
	# Point the needle out of the pinky side of the fist, away from the thumb.
	return Transform3D(Basis(Vector3.UP,PI),Vector3(0,-.018,-.018))
static func injector_scale()->float:
	return preload("res://deathmatch/conquest/classes/models.gd").metadata(7,"cq_medic").get("held_scale",1.15)
static func injector_pose(grip:Transform3D)->Transform3D:return grip*injector_grip()
static func injector_tip()->Vector3:
	return preload("res://deathmatch/conquest/classes/models.gd").muzzle(7,"cq_medic")*injector_scale()
