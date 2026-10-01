extends SceneTree
const Art=preload('res://deathmatch/art.gd')
var texture:Texture2D
var texture_path:String
var surface_texture:Texture2D
var surface_path:String
func _initialize():run.call_deferred()
func run():
	var source='res://tools/weapon_sources/fidelity/refined';var output='res://deathmatch/weapons/fidelity';DirAccess.make_dir_recursive_absolute(output)
	var selected=OS.get_cmdline_user_args();var report=[]
	for file in DirAccess.get_files_at(source):
		if not file.ends_with('.glb'):continue
		var key=file.trim_suffix('.glb')
		if not selected.is_empty() and not key in selected:continue
		texture=null;texture_path=output.path_join(key+'_albedo.res');surface_texture=null;surface_path=output.path_join(key+'_orm.res')
		var split=key.rfind('_');var rules=key.substr(0,split);var slot=int(key.substr(split+1))
		var doc=GLTFDocument.new();var state=GLTFState.new();assert(doc.append_from_file(source.path_join(file),state)==OK)
		var node=doc.generate_scene(state)
		own(node,null)
		var container=node.get_node_or_null('WeaponModel')
		if container:
			for child in container.get_children():
				if child is Node3D:child.transform=container.transform*child.transform
				container.remove_child(child);node.add_child(child)
			node.remove_child(container);container.free()
		node.name='WeaponModel';var original=Art._build_weapon(slot,rules)
		for meta in original.get_meta_list():node.set_meta(meta,original.get_meta(meta))
		original.free();node.set_meta('authored_fidelity',true)
		# Existing runtime assets may predate a longer firing assembly.
		# Always use the same authoritative origin as actual weapon shots.
		node.set_meta('muzzle',Art.muzzle(slot,rules))
		# The GLTF interchange omits Godot-only metadata on nested source scenes.
		# Restore authored melee sweep / grip landmarks from their original assets.
		for asset in ['axe','impact_hammer','sniper','sentry_gatling','tf_flamethrower']:
			var target=node.find_child(asset,true,false)
			if target:
				var inherited=load('res://deathmatch/weapons/experimental/'+asset+'.scn').instantiate()
				for meta in inherited.get_meta_list():target.set_meta(meta,inherited.get_meta(meta))
				inherited.free()
		var extras={}
		for entry in state.json.get('nodes',[]):
			if entry.has('extras'):extras[entry.get('name','')]=entry.extras
		finish(node,extras,rules,slot)
		own(node,node);var scene=PackedScene.new();assert(scene.pack(node)==OK)
		assert(ResourceSaver.save(scene,output.path_join(key+'.scn'),ResourceSaver.FLAG_COMPRESS)==OK)
		report.append({'key':key,'children':node.get_child_count()});node.free()
	FileAccess.open('res://test-results/weapon-fidelity/import.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '));print('FIDELITY_IMPORT_COMPLETE ',report.size());quit()
func finish(node:Node,extras:Dictionary,rules:String,slot:int):
	if str(node.name) in ['ChamberAction','WeaponMechanism','PresentationDetails'] and not node is MeshInstance3D:
		node.get_parent().remove_child(node);node.free();return
	var data=extras.get(str(node.name),{})
	if data.has('motion'):
		node.set_meta('motion',data.motion);var amount=data.amount;node.set_meta('amount',Vector3(amount[0],amount[1],amount[2]))
	if node is MeshInstance3D:
		if node.name=='Suppressor':node.visible=false
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if not mat is StandardMaterial3D:continue
			if mat.albedo_texture:
				if texture==null:
					var img=mat.albedo_texture.get_image();img.generate_mipmaps();texture=ImageTexture.create_from_image(img)
					assert(ResourceSaver.save(texture,texture_path,ResourceSaver.FLAG_COMPRESS)==OK);texture.take_over_path(texture_path)
				mat.albedo_texture=texture
			if mat.roughness_texture:
				if surface_texture==null:
					var response=mat.roughness_texture.get_image();response.generate_mipmaps();surface_texture=ImageTexture.create_from_image(response)
					assert(ResourceSaver.save(surface_texture,surface_path,ResourceSaver.FLAG_COMPRESS)==OK);surface_texture.take_over_path(surface_path)
				mat.roughness_texture=surface_texture;mat.metallic_texture=surface_texture
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if data.has('lamp'):
				mat=mat.duplicate();node.set_surface_override_material(i,mat)
				var rgb=data.lamp;var color=Color(rgb[0],rgb[1],rgb[2]);mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=.6;node.set_meta('emission_color',color)
			if rules=='tribes' and str(node.name).begins_with('Energy') or rules=='tribes' and str(node.name).begins_with('Magnetic rim') or str(node.name).begins_with('Reservoir glow') or str(node.name).begins_with('Probe energy'):
				mat=mat.duplicate();node.set_surface_override_material(i,mat)
				var color=Color('ffb44c') if slot==1 else Color('63cdda');mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=.6;node.set_meta('emission_color',color)
	for child in node.get_children():finish(child,extras,rules,slot)
func own(node:Node,root:Node):
	node.scene_file_path=''
	for child in node.get_children():child.owner=root;own(child,root)
