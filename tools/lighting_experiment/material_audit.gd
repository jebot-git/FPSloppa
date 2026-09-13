extends SceneTree
const OUT="res://test-results/material-audit/"
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var world: Node3D
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func capture(label: String) -> Image:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.save_png(OUT+label+".png");return image
func difference(a: Image,b: Image) -> float:
	var total:=0.0;var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var aa:=a.get_pixel(x,y);var bb:=b.get_pixel(x,y)
			total+=absf(aa.r-bb.r)+absf(aa.g-bb.g)+absf(aa.b-bb.b);count+=3
	return total/count
func normal_texture(size: int,colour: Color) -> Texture2D:
	var im:=Image.create(size,size,false,Image.FORMAT_RGB8);im.fill(colour)
	return ImageTexture.create_from_image(im)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(900,900);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var maps: Array=[]
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
	for row in catalog:
		if row.get("distribution","base")!="base":continue
		var scene: PackedScene=ResourceLoader.load("res://maps/cache/"+row.id+"-lightmap1.scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var level:=scene.instantiate();var materials: Dictionary={}
		for mesh in level.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():materials[mesh.get_active_material(i)]=true
		var info:={"id":row.id,"materials":materials.size(),"baked":0,"glow":0,"cutout":0,"normal":0,"height":0,"roughness_texture":0,"metallic_texture":0}
		for mat in materials:
			if mat is ShaderMaterial:
				if mat.shader and mat.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0"):
					info.baked+=1
					if mat.get_shader_parameter("has_glow"):info.glow+=1
					if mat.get_shader_parameter("alpha_cutout"):info.cutout+=1
			elif mat is BaseMaterial3D:
				if mat.normal_enabled and mat.normal_texture:info.normal+=1
				if mat.heightmap_enabled and mat.heightmap_texture:info.height+=1
				if mat.roughness_texture:info.roughness_texture+=1
				if mat.metallic_texture:info.metallic_texture+=1
		maps.append(info);level.free();scene=null;materials.clear();await process_frame
	world=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1,2.8);camera.look_at(Vector3(0,.9,0));camera.fov=43
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-25,-35,0);light.light_energy=.7
	var library=load("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var avatars: Array=[]
	for name in ["sample_d","sample_f","sample_g"]:
		var avatar=library.create_avatar(FileAccess.get_sha256("res://vrm/"+name+".vrm"));world.add_child(avatar);avatar.rotation.y=PI
		avatar.gun.hide();avatar.offhand_gun.hide();for i in 4:await process_frame
		avatar.process_mode=Node.PROCESS_MODE_DISABLED
		var materials: Dictionary={};var surfaces:=0;var tangents:=0
		for mesh in avatar.visual_meshes:
			for i in mesh.mesh.get_surface_count():
				surfaces+=1;var arrays: Array=mesh.mesh.surface_get_arrays(i)
				if arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4:tangents+=1
				var mat=mesh.get_active_material(i)
				if mat is ShaderMaterial:materials[mat]=mat.get_shader_parameter("_BumpScale")
		var material_rows: Array=[]
		for mat in materials:
			var tex: Texture2D=mat.get_shader_parameter("_BumpMap")
			material_rows.append({"name":mat.resource_name,"normal_size":[tex.get_width(),tex.get_height()] if tex else [],"normal_mipmaps":tex.has_mipmaps() if tex else false,"normal_scale":materials[mat],"arena_policy":mat.get_shader_parameter("_ArenaLightingEnabled"),"has_filter_variants":mat.has_meta(Filtering.BANK),"shader_uses_include":mat.shader.code.contains("#include")})
		var authored:=await capture(name+"-normal-on")
		for mat in materials:mat.set_shader_parameter("_BumpScale",0.0)
		var flat:=await capture(name+"-normal-off")
		var delta:=difference(authored,flat)
		check(delta>.000001,name+": authored normals affect rendered output")
		check(tangents==surfaces,name+": runtime tangents present")
		avatars.append({"id":name,"surfaces":surfaces,"surfaces_with_tangents":tangents,"materials":material_rows,"normal_on_off_difference":delta})
		avatar.free();materials.clear();await process_frame
	var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.position.y=1;world.add_child(quad)
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/Godot-MToon-Shader/mtoon.gdshader")
	mat.set_shader_parameter("_Color",Color(.7,.7,.7));mat.set_shader_parameter("_ShadeColor",Color(.7,.7,.7));mat.set_shader_parameter("_ArenaLightingEnabled",true);quad.material_override=mat
	var probes: Array=[]
	for size in [1,32]:
		mat.set_shader_parameter("_BumpMap",normal_texture(size,Color(.5,.5,1)));var flat:=await capture("probe-"+str(size)+"-flat")
		mat.set_shader_parameter("_BumpMap",normal_texture(size,Color(.8,.5,.9)));var tilted:=await capture("probe-"+str(size)+"-tilted")
		probes.append({"size":size,"normal_difference":difference(flat,tilted)})
	check(probes[1].normal_difference>.001,"Large synthetic normal map affects lighting")
	var result:={"maps":maps,"avatars":avatars,"normal_size_probe":probes,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"failures":failures}
	FileAccess.open(OUT+"runtime.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	world.free();print("MATERIAL_AUDIT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
