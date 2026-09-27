extends SceneTree
const NAMES=["knife","glock","usp","m3","xm1014","mp5","ak47","m4a1","m249","awp","deagle","p90"]
const COLORS={"Parkerized steel":Color(.58,.63,.68),"Stippled polymer":Color(.24,.26,.28),"Oiled walnut":Color(.85,.46,.18),"Olive composite":Color(.56,.67,.38),"Machined steel":Color(.98,.99,1),"Cartridge brass":Color(1,.77,.34)}
var texture: ImageTexture
func _initialize():
	for name in NAMES:
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		assert(doc.append_from_file("res://tools/cs16/refined/"+name+".glb",state)==OK)
		var node:=doc.generate_scene(state);finish(node)
		var scene:=PackedScene.new();assert(scene.pack(node)==OK)
		assert(ResourceSaver.save(scene,"res://deathmatch/weapons/cs16/"+name+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		node.free()
	print("CS16_MODELS_IMPORTED");quit()
func finish(node: Node):
	for key in ["SightRear","SightFront"]:
		if String(node.name).ends_with("_"+key):node.name=key
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if not mat is StandardMaterial3D:continue
			for key in COLORS:
				if key in mat.resource_name:mat.albedo_color=COLORS[key]
			if mat.albedo_texture:
				if texture==null:
					var img: Image=mat.albedo_texture.get_image();img.generate_mipmaps();texture=ImageTexture.create_from_image(img)
					assert(ResourceSaver.save(texture,"res://deathmatch/weapons/cs16/finish.res",ResourceSaver.FLAG_COMPRESS)==OK)
					texture.take_over_path("res://deathmatch/weapons/cs16/finish.res")
				mat.albedo_texture=texture
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mat.cull_mode=BaseMaterial3D.CULL_BACK
		for key in ["Body","Slide","Bolt","Pump","ChargingHandle","Suppressor","Magazine","FeedCover"]:
			if String(node.name).ends_with("_"+key):node.name=key
		if node.name=="Suppressor":node.visible=false
	for child in node.get_children():finish(child)
