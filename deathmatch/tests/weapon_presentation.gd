extends SceneTree
const Art=preload('res://deathmatch/art.gd')
const Rules=preload('res://deathmatch/experimental/weapon_rules.gd')
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var armory=Rules.new();var count=0
	for rules in Rules.IDS+['sentry','tf_sniper','tf_flame']:
		armory.select(rules if rules in Rules.IDS else 'quake')
		var slots:Array=range(armory.table.size()) if rules in Rules.IDS else [5 if rules=='sentry' else 9 if rules=='tf_sniper' else 7]
		for slot in slots:
			var model=Art.weapon(slot,2,rules);root.add_child(model);count+=1
			var label=rules+':'+str(slot);var action=model.get_node('WeaponMechanism')
			check(rules=='doom' and slot==0 or model.get_meta('authored_fidelity',false),label+' authored asset integrated')
			check(model.has_node('PresentationDetails'),label+' details instantiated')
			check(not action.is_processing(),label+' idle has no animation tick')
			check(model.get_meta('muzzle').is_equal_approx(Art.muzzle(slot,rules)),label+' visual muzzle matches authoritative shot origin')
			if rules=='ut99' and slot==11:
				check(model.get_node('TranslocatorDisc').position.is_equal_approx(Vector3(0,.18,-.23)),label+' raised disc position preserved')
				check(model.get_node('DiscCore').position.is_equal_approx(Vector3(0,.215,-.23)),label+' raised disc core preserved')
			var rests=[]
			if rules=='doom' and slot==3 or rules=='quake' and slot==2:
				check(model.find_child('ReciprocatingForeEnd',true,false)!=null and not action.parts.is_empty(),label+' actual fore-end remains animated')
			if rules=='doom' and slot==4 or rules=='quake' and slot==3:
				check(model.find_child('TwinBoreLeft',true,false)!=null and model.find_child('TwinBoreRight',true,false)!=null and action.parts.size()>=2,label+' paired barrels retain break action')
			if rules=='quake' and slot in [0,1]:check(model.get_child(0).get_meta('cutting_edge',Vector3.ZERO).is_equal_approx(Art.muzzle(slot,rules)),label+' physical axe edge survives interchange')
			for p in action.parts:rests.append(p.node.transform)
			Art.fire(model,slot,rules,.6);action._process(.25)
			check(action.is_processing(),label+' accepted shot wakes feedback')
			if not action.parts.is_empty():
				var moved=false
				for i in rests.size():moved=moved or not rests[i].is_equal_approx(action.parts[i].node.transform)
				check(moved,label+' working geometry moves')
			var second=Art.weapon(slot,2,rules);root.add_child(second);var other=second.get_node('WeaponMechanism')
			check(not other.is_processing(),label+' shot leaves other instance asleep')
			for lamp in other.lamps:check(is_equal_approx(lamp.material.emission_energy_multiplier,.6),label+' emission independent')
			Art.charge(model,.8);action._process(.2)
			for lamp in action.lamps:check(lamp.material.emission_energy_multiplier>1.5,label+' charged indicator brightens')
			Art.charge(model,0);action._process(5)
			check(not action.is_processing(),label+' returns to sleep')
			for p in action.parts:
				if p.kind!='spin':check(p.node.transform.is_equal_approx(p.rest),label+' moving part returns to rest')
			var triangles=0
			var response_maps:=0
			var response_channels_ok:=true
			var bounds:=AABB();var has_bounds:=false
			for mesh in model.find_children('*','MeshInstance3D',true,false):
				if mesh.has_meta('fpsloppa_filter_warmup'):continue
				var local: AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
				bounds=bounds.merge(local) if has_bounds else local;has_bounds=true
				for i in mesh.mesh.get_surface_count():
					var material=mesh.get_active_material(i)
					if material is StandardMaterial3D and material.roughness_texture:
						response_maps+=1
						response_channels_ok=response_channels_ok and material.roughness_texture==material.metallic_texture and material.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN and material.metallic_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_BLUE and material.roughness_texture.get_image().has_mipmaps()
					var arrays=mesh.mesh.surface_get_arrays(i)
					triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
			if model.get_meta('authored_fidelity',false):
				check(response_maps>0 and response_channels_ok,label+' baked material response survives import and filtering')
			check(triangles<30000,label+' geometry budget')
			check(not has_bounds or bounds.size[bounds.size.max_axis_index()]<2.0,label+' source units fit held-weapon scale')
			model.free();second.free()
	print('WEAPON_PRESENTATION_RESULT ',JSON.stringify({'weapons':count,'checks':checks,'failures':failures}));quit(0 if failures.is_empty() else 1)
