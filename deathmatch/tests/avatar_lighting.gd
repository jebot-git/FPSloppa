extends SceneTree
var failures: Array=[]
var reports: Array=[]
var world: Node3D
var sun: DirectionalLight3D
var lamp: OmniLight3D
var environment: Environment
func _initialize():call_deferred("run")
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func shot(name: String) -> Image:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();im.save_png("res://test-results/avatar-lighting-"+name+".png");return im
func stats(im: Image) -> Dictionary:
	var count:=0;var sum:=Vector3.ZERO;var bright:=0;var peak:=0.0
	for y in range(0,im.get_height(),2):
		for x in range(im.get_width()/5,im.get_width()*4/5,2):
			var c:=im.get_pixel(x,y);var value:=maxf(c.r,maxf(c.g,c.b))
			if value<.01:continue
			count+=1;sum+=Vector3(c.r,c.g,c.b);peak=maxf(peak,value)
			if minf(c.r,minf(c.g,c.b))>.96:bright+=1
	var mean:=sum/maxi(1,count)
	return {"pixels":count,"rgb":[mean.x,mean.y,mean.z],"luma":mean.dot(Vector3(.2126,.7152,.0722)),"white_fraction":float(bright)/maxi(1,count),"peak":peak}
func run() -> void:
	root.size=Vector2i(640,640)
	world=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();environment=Environment.new();env.environment=environment;world.add_child(env)
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.02
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.0,2.7);camera.look_at(Vector3(0,.87,0));camera.fov=43;camera.make_current()
	sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-35,-20,0);sun.light_energy=0
	lamp=OmniLight3D.new();world.add_child(lamp);lamp.position=Vector3(-.7,1.3,1);lamp.omni_range=5;lamp.light_energy=0
	var library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	for sample in ["sample_d","sample_f","sample_g"]:
		var hash: String=FileAccess.get_sha256(library.Paths.folder("vrm")+sample+".vrm")
		var avatar=library.create_avatar(hash);check(avatar!=null,"Load "+sample)
		if not avatar:continue
		world.add_child(avatar);avatar.set_process(false);avatar.rotation.y=PI
		if avatar.gun:avatar.gun.hide()
		if avatar.offhand_gun:avatar.offhand_gun.hide()
		for mesh in avatar.visual_meshes:
			for i in mesh.mesh.get_surface_count():
				var material: Material=mesh.get_active_material(i)
				print("AVATAR_MATERIAL ",sample," ",material.get_class()," ",material.shader.resource_path if material is ShaderMaterial else "PBR")
				if material is ShaderMaterial:
					check(material.get_shader_parameter("_ArenaLightingEnabled")==true,"MToon arena response enabled")
					for key in ["_MainTex","_ShadeTexture","_EmissionMap"]:
						var texture=material.get_shader_parameter(key)
						if texture is Texture2D and maxi(texture.get_width(),texture.get_height())>8:check(texture.get_image().has_mipmaps(),"MToon "+key+" has mipmaps")
		sun.light_energy=0;lamp.light_energy=0;environment.ambient_light_energy=.02
		var dark:=stats(await shot(sample+"-dark"))
		sun.light_energy=5;lamp.light_energy=8;lamp.light_color=Color.WHITE;environment.ambient_light_energy=.6
		var bright:=stats(await shot(sample+"-bright"))
		sun.light_energy=.1;lamp.light_energy=2;lamp.light_color=Color(1,.12,.04);environment.ambient_light_energy=.15
		var red:=stats(await shot(sample+"-warm"))
		lamp.light_color=Color(.05,.2,1)
		var blue:=stats(await shot(sample+"-cool"))
		check(dark.pixels>1500 and dark.luma>.04,"Readable silhouette in dim light "+sample)
		check(bright.luma>dark.luma and bright.white_fraction<.03,"Bright scene responds without white clipping "+sample)
		check(red.rgb[0]-red.rgb[2]>blue.rgb[0]-blue.rgb[2]+.025,"Environment light colour affects VRM "+sample)
		reports.append({"model":sample,"dark":dark,"bright":bright,"warm":red,"cool":blue});avatar.free()
	var standard:=StandardMaterial3D.new();standard.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	preload("res://deathmatch/avatars/lighting.gd").prepare(standard)
	check(standard.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and standard.emission_enabled,"Unlit glTF fallback gains local lighting and fill")
	var out:=FileAccess.open("res://test-results/avatar-lighting-validation.json",FileAccess.WRITE);out.store_string(JSON.stringify({"models":reports,"failures":failures},"  "));out.close()
	print("AVATAR_LIGHTING_RESULT ",JSON.stringify(failures));world.free();quit(0 if failures.is_empty() else 1)
