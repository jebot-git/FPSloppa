extends SceneTree
const NAMES=['blaster', 'plasma', 'chaingun', 'disc', 'grenade_launcher', 'laser', 'elf', 'mortar', 'repair', 'grenade', 'mine', 'targeter', 'energy_pack', 'ammo_pack', 'repair_pack', 'shield_pack', 'jammer_pack','armour_light','armour_medium','armour_heavy']
var texture: ImageTexture
func _initialize():
	for name in (NAMES if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()):
		assert(name in NAMES)
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		assert(doc.append_from_file("res://tools/tribes/refined/"+name+".glb",state)==OK)
		var node:=doc.generate_scene(state);finish(node)
		var scene:=PackedScene.new();assert(scene.pack(node)==OK)
		assert(ResourceSaver.save(scene,"res://deathmatch/weapons/tribes/"+name+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		node.free()
	print("TRIBES_MODELS_IMPORTED");quit()
func finish(node: Node):
	for key in ["SightRear","SightFront"]:
		if String(node.name).ends_with("_"+key):node.name=key
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if not mat is StandardMaterial3D:continue
			mat.albedo_color=Color.WHITE
			if mat.albedo_texture:
				if texture==null:
					var img: Image=mat.albedo_texture.get_image();img.generate_mipmaps();texture=ImageTexture.create_from_image(img)
					assert(ResourceSaver.save(texture,"res://deathmatch/weapons/tribes/finish.res",ResourceSaver.FLAG_COMPRESS)==OK)
					texture.take_over_path("res://deathmatch/weapons/tribes/finish.res")
				mat.albedo_texture=texture
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mat.cull_mode=BaseMaterial3D.CULL_BACK
		for key in ["Body","Slide","Bolt","Pump","ChargingHandle","Suppressor","Magazine","FeedCover","FeedBelt"]:
			if String(node.name).ends_with("_"+key):node.name=key
		if node.name=="Suppressor":node.visible=false
	for child in node.get_children():finish(child)
