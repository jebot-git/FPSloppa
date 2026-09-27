extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pixels(size: Vector2i=Vector2i(8,4)) -> ImageTexture:
	var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGB8)
	image.fill(Color(.8,.5,.9))
	for y in size.y:
		for x in range(size.x/2):image.set_pixel(x,y,Color(.2,.5,.9))
	return ImageTexture.create_from_image(image)
func surface() -> StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_texture=pixels();return result
func complete(texture: Texture2D) -> bool:
	return texture.get_image().has_mipmaps() and texture.get_image().get_mipmap_count()==3
func run() -> void:
	var helper:=Filtering.new();var source:=pixels()
	var colour:=helper.texture(source);var normal:=helper.normal_texture(source)
	var image:=normal.get_image();var bytes:=image.get_data();var offset:=image.get_mipmap_offset(3)
	var vector:=Vector3(bytes[offset],bytes[offset+1],bytes[offset+2])/255.0*2.0-Vector3.ONE
	check(complete(normal) and absf(vector.length()-1.0)<.015 and vector.z>.99,"Normal mip vectors stay normalized through the last level")
	check(normal!=colour and helper.normal_texture(source)==normal and helper.texture(source)==colour,"Shared colour/normal sources retain separate, reusable mip chains")
	check(bytes.slice(0,8*4*3)==source.get_image().get_data(),"Normal mip generation preserves level zero")
	var single:=pixels(Vector2i.ONE)
	check(helper.texture(single)==single,"One-pixel textures require no lower levels")
	var shader:=ShaderMaterial.new();shader.shader=Shader.new()
	shader.shader.code="""shader_type spatial;
uniform sampler2D _BumpMap : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D custom_mask : filter_linear_mipmap;
uniform sampler2D bake_texture : filter_linear;
uniform sampler2D weapon_occlusion_tree : filter_nearest;
void fragment() { ALBEDO=texture(custom_mask,UV).rgb; NORMAL_MAP=texture(_BumpMap,UV).rgb; }
"""
	for key in ["_BumpMap","custom_mask","bake_texture","weapon_occlusion_tree"]:shader.set_shader_parameter(key,source)
	helper.material(shader)
	check(shader.get_shader_parameter("_BumpMap")==normal and shader.get_shader_parameter("custom_mask")==colour,"Custom shader and avatar normal samplers acquire the right mip chain")
	check(shader.get_shader_parameter("bake_texture")==source and shader.get_shader_parameter("weapon_occlusion_tree")==source and not source.get_image().has_mipmaps(),"Packed lightmaps and exact-texel lookup textures remain untouched")
	var world:=Node3D.new()
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.material_override=surface();mesh.material_overlay=surface();mesh.material_override.next_pass=surface();world.add_child(mesh)
	var cpu:=CPUParticles3D.new();cpu.mesh=QuadMesh.new();cpu.mesh.material=surface();world.add_child(cpu)
	var gpu:=GPUParticles3D.new();gpu.draw_pass_1=QuadMesh.new();gpu.draw_pass_1.material=surface();world.add_child(gpu)
	var sprite:=Sprite3D.new();sprite.texture=pixels();world.add_child(sprite)
	var decal:=Decal.new();decal.texture_albedo=pixels();decal.texture_normal=pixels();world.add_child(decal)
	helper.apply(world)
	check(complete(mesh.material_overlay.albedo_texture) and complete(mesh.material_override.next_pass.albedo_texture),"Overlay and secondary material passes are prepared")
	check(complete(cpu.mesh.material.albedo_texture) and complete(gpu.draw_pass_1.material.albedo_texture),"CPU and GPU particle draw meshes are prepared")
	check(complete(sprite.texture) and sprite.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"World sprites generate and sample mipmaps")
	check(complete(decal.texture_albedo) and complete(decal.texture_normal),"Decal colour and normal maps are prepared")
	var standalone:=Decal.new();standalone.texture_albedo=pixels();Filtering.new().apply(standalone)
	check(complete(standalone.texture_albedo),"Root decals follow the same preparation path")
	var viewport:=SubViewport.new();root.add_child(viewport)
	var live:=Sprite3D.new();live.texture=viewport.get_texture();var old_filter:=live.texture_filter
	Filtering.new().apply(live)
	check(live.texture==viewport.get_texture() and live.texture_filter==old_filter,"Live viewport sprites retain their independent sampling")
	live.free();viewport.free();standalone.free();world.free()
	print("MIPMAPS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
