extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
class Probe extends "res://deathmatch/maps/filtering.gd":
	var pixel_calls:=0
	func texture(source: Texture2D) -> Texture2D:
		pixel_calls+=1
		return super.texture(source)
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fixture() -> Array:
	var world:=Node3D.new();root.add_child(world)
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(image)
	var node:=MeshInstance3D.new();node.mesh=BoxMesh.new();node.material_override=material;world.add_child(node)
	var shader:=ShaderMaterial.new();shader.shader=load("res://deathmatch/maps/baked_light.gdshader");shader.set_shader_parameter("base_texture",material.albedo_texture)
	var baked:=MeshInstance3D.new();baked.mesh=BoxMesh.new();baked.material_override=shader;world.add_child(baked)
	Filtering.new().apply(world,2)
	var bank: Array=material.get_meta(Filtering.BANK)
	var baked_shader: Shader=shader.shader
	check(bank.size()==3 and bank.all(func(variant):return variant.albedo_texture==material.albedo_texture),"Three retained variants share the prepared texture without duplicating pixels")
	check(material.albedo_texture.get_image().has_mipmaps(),"Asset preparation generates missing mipmaps")
	var original: Texture2D=material.albedo_texture
	material.albedo_color=Color.RED
	shader.set_shader_parameter("base_colour",Color.BLUE)
	var no_reads:=true;var stable:=true
	for mode in [0,1,2,0,2,1]:
		var probe:=Probe.new();probe.apply(world,mode,false)
		no_reads=no_reads and probe.pixel_calls==0
		stable=stable and material.albedo_texture==original and material.texture_filter==Filtering.FILTERS[mode] and shader.shader==baked_shader and shader.get_shader_parameter("texture_filter_mode")==mode
	check(no_reads,"Settings switches never call pixel preparation")
	check(stable,"Every filter mode reuses the existing texture and shader variants")
	check(node.material_override==material and material.albedo_color==Color.RED and shader.get_shader_parameter("base_colour")==Color.BLUE,"Switches preserve live material references and gameplay colour/uniform changes")
	Filtering.new().apply(world,0)
	check(is_same(material.get_meta(Filtering.BANK),bank),"Preparing a shared asset again reuses its variant bank")
	var plain:=StandardMaterial3D.new();var plain_filter:=plain.texture_filter
	var helper:=Filtering.new();helper.mode=0;helper.material(plain)
	check(plain.texture_filter==plain_filter and not plain.has_meta(Filtering.BANK),"Untextured materials remain untouched")
	var viewport:=SubViewport.new();root.add_child(viewport)
	var ui:=StandardMaterial3D.new();ui.albedo_texture=viewport.get_texture();var ui_filter:=ui.texture_filter
	helper.material(ui)
	check(ui.texture_filter==ui_filter and not ui.has_meta(Filtering.BANK),"Live viewport textures keep their independent UI sampling")
	var legacy:=ShaderMaterial.new();legacy.shader=Shader.new()
	legacy.shader.code="""shader_type spatial;
uniform sampler2D base_texture : source_color, filter_nearest_mipmap_anisotropic;
uniform sampler2D bake_texture;
uniform vec4 base_colour : source_color = vec4(1.0);
void fragment() {
 vec3 base=texture(base_texture,UV).rgb*base_colour.rgb;
 vec3 baked=texture(bake_texture,UV).rgb;
 EMISSION = base * clamp(sqrt(baked) * 2.0,vec3(0.25),vec3(1.5));
}"""
	legacy.set_shader_parameter("base_texture",original);legacy.set_shader_parameter("bake_texture",original);legacy.set_shader_parameter("base_colour",Color.GREEN)
	Filtering.new().material(legacy)
	check(legacy.shader==Filtering.BAKED and legacy.get_shader_parameter("bake_texture")==original and legacy.get_shader_parameter("base_colour")==Color.GREEN,"Older embedded baked shaders upgrade without losing lighting or tint")
	check(legacy.get_shader_parameter("base_nearest")==original and legacy.get_shader_parameter("base_linear")==original,"All baked filter samplers share the original prepared image")
	var multi:=MultiMeshInstance3D.new();multi.multimesh=MultiMesh.new();multi.multimesh.mesh=BoxMesh.new();multi.multimesh.mesh.material=material;world.add_child(multi)
	Filtering.new().apply(world,2,false)
	check(material.texture_filter==Filtering.FILTERS[2],"MultiMesh map fixtures follow the selected filter")
	var references: Array=[weakref(material),weakref(bank[0]),weakref(shader)]
	viewport.free();world.free()
	return references
func run() -> void:
	var references:=fixture()
	await process_frame
	check(references.all(func(reference):return reference.get_ref()==null),"Asset unload releases variant banks without reference cycles")
	print("FILTER_VARIANTS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
