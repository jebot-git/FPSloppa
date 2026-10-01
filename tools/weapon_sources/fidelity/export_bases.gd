extends SceneTree
const Art=preload('res://deathmatch/art.gd')
const Rules=preload('res://deathmatch/experimental/weapon_rules.gd')
func _initialize():run.call_deferred()
func run():
	var folder='res://tools/weapon_sources/fidelity/bases';DirAccess.make_dir_recursive_absolute(folder)
	var report={};var armory=Rules.new()
	for rules in Rules.IDS+['sentry','tf_sniper','tf_flame']:
		armory.select(rules if rules in Rules.IDS else 'quake')
		var slots=range(armory.table.size()) if rules in Rules.IDS else [5 if rules=='sentry' else 9 if rules=='tf_sniper' else 7]
		for slot in slots:
			var model=Art._build_weapon(slot,rules);root.add_child(model)
			var key=rules+'_'+str(slot);var doc=GLTFDocument.new();var state=GLTFState.new()
			assert(doc.append_from_scene(model,state)==OK);assert(doc.write_to_filesystem(state,folder.path_join(key+'.glb'))==OK)
			var grip=Art.held_transform(Transform3D.IDENTITY,slot,1.0,rules).origin*-1
			report[key]={'muzzle':Array([Art.muzzle(slot,rules).x,Art.muzzle(slot,rules).y,Art.muzzle(slot,rules).z]),'grip':[grip.x,grip.y,grip.z]}
			model.free()
	FileAccess.open(folder.path_join('anchors.json'),FileAccess.WRITE).store_string(JSON.stringify(report,'  '));print('FIDELITY_BASES_EXPORTED');quit()
