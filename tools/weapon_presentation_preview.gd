extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var stage: Node3D
var rows: Array=[]
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1920,1200);root.content_scale_size=root.size
	var args:=OS.get_cmdline_user_args();var folder: String=args[0] if not args.is_empty() else "res://test-results/weapon-presentation/after"
	DirAccess.make_dir_recursive_absolute(folder)
	stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("151c24");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c2cbd5");env.environment.ambient_light_energy=.65;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.4;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_color=Color("9dbbdb");fill.light_energy=.5;stage.add_child(fill)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.8;stage.add_child(camera)
	var armory:=Rules.new()
	for rules in Rules.IDS+["special"]:
		var gallery:=Node3D.new();stage.add_child(gallery)
		armory.select(rules if rules!="special" else "quake")
		var count: int=armory.table.size() if rules!="special" else 3
		for slot in count:
			var profile: String=rules if rules!="special" else ["sentry","tf_sniper","tf_flame"][slot]
			var index: int=slot if rules!="special" else [5,9,7][slot]
			var model:=Art.weapon(index,2,profile);gallery.add_child(model)
			rows.append(audit(model,profile,index))
			model.position=Vector3((slot%4-1.5)*1.87,1.30-(slot/4)*1.45,0)
			model.rotation_degrees=Vector3(14,65,-8);model.scale=Vector3.ONE*1.45
			var label:=Label3D.new();label.text=profile.to_upper()+"  "+str(index)+"\n"+(armory.data(slot).name if rules!="special" else profile);label.font_size=25;label.pixel_size=.0024;label.position=model.position+Vector3(0,-.48,.8);label.no_depth_test=true;gallery.add_child(label)
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(rules+".png"))
		gallery.free()
	FileAccess.open(folder.path_join("inventory.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	stage.free();await create_timer(.1).timeout;print("WEAPON_PRESENTATION_PREVIEW_COMPLETE ",folder);quit()
func audit(model: Node3D,profile: String,slot: int) -> Dictionary:
	var parts: Array=[];var triangles:=0;var surfaces:=0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh or mesh.has_meta("fpsloppa_filter_warmup"):continue
		var count:=0
		for s in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(s)
			if arrays.size()>Mesh.ARRAY_INDEX:count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
		var transform: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
		parts.append({"name":str(model.get_path_to(mesh)),"bounds":str(transform*mesh.get_aabb()),"triangles":count})
		triangles+=count;surfaces+=mesh.mesh.get_surface_count()
	return {"rules":profile,"slot":slot,"meshes":parts.size(),"surfaces":surfaces,"triangles":triangles,"parts":parts}
