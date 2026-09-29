extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
const Layout=preload("res://deathmatch/modes/defusal_maps.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label: String):
	checks+=1;print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var path:=OS.get_cmdline_user_args()[0]
	var row:=Maps.import_custom(path)
	check(not row.has("error") and row.get("modes")==["de"],"Import recognizes embedded objectives independently of filename")
	if row.has("error"):print(row);quit(1);return
	check(Layout.supported(row.id,row.sha256) and Layout.supported("renamed",row.sha256),"DE objectives follow verified content hash")
	check(not Layout.supported(row.id,"0".repeat(64)),"Wrong map hash cannot reuse objective metadata")
	var cfg:=preload("res://deathmatch/server/config.gd").parse('set sv_gametype "de"\nmap '+row.id)
	check(not cfg.has("error") and cfg.values.map==row.id and cfg.values.mode_maps.de==[row.id],"Dedicated server config accepts installed converted map")
	check(preload("res://deathmatch/server/config.gd").parse('set sv_gametype "de"\nset de_maplist "missing_map"').has("error"),"Uninstalled DE maplist rejected")
	check(Maps.catalog().any(func(r):return r.sha256==row.sha256 and r.modes==["de"]),"Catalog restart classification comes from BSP content")
	var layout:=Layout.resolve(row.id,row.sha256)
	var invalid:=layout.duplicate(true);invalid.starts[0]=[]
	check(not Layout.valid_layout(invalid),"Empty role rejected")
	invalid=layout.duplicate(true);invalid.sites[0][1]=NAN
	check(not Layout.valid_layout(invalid),"Non-finite objective rejected")
	invalid=layout.duplicate(true);invalid.bounds[0].max=invalid.bounds[0].min
	check(not Layout.valid_layout(invalid),"Empty site bounds rejected")
	invalid=layout.duplicate(true);invalid.start_yaws[0]=[]
	check(not Layout.valid_layout(invalid),"Mismatched spawn yaw list rejected")
	invalid=layout.duplicate(true);invalid.volumes=[[],[]]
	check(not Layout.valid_layout(invalid),"Empty plant component list rejected")
	invalid=layout.duplicate(true);invalid.volumes[0][0].max[0]=32000
	check(not Layout.valid_layout(invalid),"Plant component outside aggregate bounds rejected")
	var original:=FileAccess.get_file_as_bytes(row.path)
	var extensions:=preload("res://deathmatch/maps/bsp_extensions.gd").directory(row.path)
	var bad_path:=Maps.Paths.root()+"/invalid-conversion.bsp"
	var bad:=original.duplicate();bad[extensions.FSL_DE.x+11]=57
	var output:=FileAccess.open(bad_path,FileAccess.WRITE);output.store_buffer(bad);output.close()
	check(not Maps.validate(bad_path).is_empty(),"Unknown embedded DE version rejected before import")
	bad=original.duplicate();bad.encode_u32(extensions.FSL_PALETTES.x,99)
	output=FileAccess.open(bad_path,FileAccess.WRITE);output.store_buffer(bad);output.close()
	check(not Maps.validate(bad_path).is_empty(),"Invalid palette extension rejected before import")
	DirAccess.remove_absolute(bad_path)
	var level:=Maps.read(row.path);var colour:=false;var cutout:=false;var mips:=true;var nonemissive:=true
	for instance in level.find_children("*","MeshInstance3D",true,false):
		for i in instance.mesh.get_surface_count():
			var material=instance.mesh.surface_get_material(i)
			if not material is ShaderMaterial:continue
			var texture=material.get_shader_parameter("base_texture")
			if not texture is Texture2D:continue
			var image: Image=texture.get_image();mips=mips and image.has_mipmaps()
			var name: String=material.get_meta("bsp_texture_name","")
			if name=="testfloor":
				colour=image.get_pixel(0,0).is_equal_approx(Color8(37,149,231));nonemissive=material.get_shader_parameter("has_glow")!=true
			if name=="{testfence":cutout=image.get_pixel(0,0).a==0 and material.get_shader_parameter("alpha_cutout")==true
	check(colour,"Source palette index 230 retains its exact blue colour")
	check(nonemissive,"GoldSrc high palette indices do not become Quake fullbright pixels")
	check(cutout,"Masked texture index 255 stays transparent")
	check(mips,"Converted colour textures are mipmapped")
	check(level.get_meta("baked_light_invalid_faces",-1)==0 and level.get_meta("baked_light_overflow_faces",-1)==0,"RGB lightmap offsets and atlas are valid")
	level.free()
	# Exercise the same raw BSP disk job used by downloaded/uploaded maps.
	var jobs=preload("res://deathmatch/network/asset_jobs.gd")
	var received:=jobs.map_file(row.path,row.sha256,"Renamed remote map",Maps.Paths.folder("maps"),"unrelated.bsp")
	check(received.get("modes")==["de"],"Network disk import preserves DE even after filename changes")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map=row.id;g.start_host("Converter test",0,16,10,true,"de","doom")
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	var de=g.match_mode.defusal
	await physics_frame;await physics_frame
	check(g.active and g.current_map==row.id and g.armory.effective()=="cs16", "Converted map starts a DE practice match")
	check(de.sites[0]==Layout.vector(layout.sites[0]) and de.starts[0].size()==2 and de.starts[1].size()==2,"DE runtime uses converted sites and both original teams")
	check(g.maps_for_mode("de").has(row.id),"Host and ballot expose converted DE map")
	check(g.gates.size()==1 and int(g.gates[0].node.attributes.get("_de_reset",0))==1,"Converted sliding door uses round-reset mover")
	for i in 2:
		g.fighters[1].position=de.starts[de.role(1)][i]
		check(is_equal_approx(de.spawn_yaw(1),float(layout.start_yaws[de.role(1)][i])),"Per-spawn facing retained %d"%i)
	check(de.site_at(de.sites[0])==0 and de.site_at(de.sites[1])==1,"Bomb placement recognizes A and B")
	de.site_bounds=[AABB(Vector3.ZERO,Vector3(10,3,10))]
	de.site_volumes=[[AABB(Vector3.ZERO,Vector3(3,3,10)),AABB(Vector3(7,0,0),Vector3(3,3,10))]]
	check(de.site_at(Vector3(1,1,5))==0 and de.site_at(Vector3(9,1,5))==0 and de.site_at(Vector3(5,1,5))==-1,"Multi-volume sites exclude gaps inside their aggregate bounds")
	g.queue_free();await process_frame
	print("CS_MAP_CONVERSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
