extends RefCounted
## Prepare pixels/variants when assets load; settings changes only select sampling.
const FILTERS=[BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]
const HINTS=["filter_nearest_mipmap","filter_linear_mipmap","filter_linear_mipmap_anisotropic"]
const BANK="fpsloppa_filter_variants"
const BAKED=preload("res://deathmatch/maps/baked_light.gdshader")
const QUAKE=preload("res://deathmatch/maps/quake_light.gdshader")
const ColourMips=preload("res://deathmatch/maps/colour_mips.gd")
const DATA_SAMPLERS=["bake_texture","weapon_occlusion_tree"]
const MIPS_READY="fpsloppa_mipmaps_ready"
var mode:=2
var prepare_assets:=true
var lighting_mode:=-1
var shaders: Dictionary={}
var textures: Dictionary={}
var materials: Dictionary={}
var map_textures: Dictionary={}
class Warmup extends Node3D:
	var sources: Array=[]
	var frames_left:=3
	func _process(_delta: float) -> void:
		# Hidden instances allow Mobile/Forward+ surface pipeline precompilation.
		# Material variants remain alive after these temporary instances are gone.
		frames_left-=1
		if frames_left>0:return
		for source in sources:source.set_meta("fpsloppa_filter_warmed",true)
		queue_free()
func texture(source: Texture2D) -> Texture2D:
	return prepare_texture(source,false)
func normal_texture(source: Texture2D) -> Texture2D:
	return prepare_texture(source,true)
func prepare_texture(source: Texture2D,normal: bool) -> Texture2D:
	if not source or source is ViewportTexture or source.has_meta(MIPS_READY) or source.has_mipmaps():return source
	var key:=[source,normal]
	if textures.has(key):return textures[key]
	var result: Texture2D=source
	var image:=source.get_image()
	if image and not image.has_mipmaps() and maxi(image.get_width(),image.get_height())>1:
		# The headless renderer may return the shared backing Image. Never alter
		# source pixels: another material may interpret them as a normal map.
		image=image.duplicate() as Image
		if image.is_compressed() and image.decompress()!=OK:return source
		if image.generate_mipmaps(normal)==OK:result=ImageTexture.create_from_image(image)
	# Texture2D.has_mipmaps() returns false for ImageTexture in Godot 4.7.2;
	# retain the verified result to avoid another GPU read on subsequent loads.
	if image and image.has_mipmaps():result.set_meta(MIPS_READY,true)
	textures[key]=result
	return result
func textured(source: BaseMaterial3D) -> bool:
	for slot in BaseMaterial3D.TEXTURE_MAX:
		var value:=source.get_texture(slot)
		if value and not value is ViewportTexture:return true
	return false
func map_texture(source: Texture2D,cutout: bool=false) -> Texture2D:
	if not source:return source
	var key:=[source,cutout]
	if not map_textures.has(key):map_textures[key]=ColourMips.prepare(source,cutout)
	return map_textures[key]
func material(source: Material) -> void:
	if not source or materials.has(source):return
	materials[source]=true
	material(source.next_pass)
	if source is BaseMaterial3D:
		if not textured(source):return
		if prepare_assets:
			if source.has_meta("bsp_texture_name"):
				var previous: Texture2D=source.albedo_texture
				source.albedo_texture=map_texture(source.albedo_texture,source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
				source.emission_texture=map_texture(source.emission_texture)
				if previous!=source.albedo_texture and source.has_meta(BANK):source.remove_meta(BANK)
			for slot in BaseMaterial3D.TEXTURE_MAX:
				var original: Texture2D=source.get_texture(slot)
				var prepared:=normal_texture(original) if slot in [BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_DETAIL_NORMAL] else texture(original)
				if original!=prepared:source.set_texture(slot,prepared)
			if not source.has_meta(BANK):
				var variants: Array=[]
				for filter_mode in 3:
					var variant:=source.duplicate() as BaseMaterial3D
					variant.texture_filter=FILTERS[filter_mode];variants.append(variant)
				# None of the variants references this source: no resource cycle.
				source.set_meta(BANK,variants)
		if source.texture_filter!=FILTERS[mode]:source.texture_filter=FILTERS[mode]
	elif source is ShaderMaterial:
		# Upgrade our older cached baked shader once, retaining its named uniforms.
		if source.shader in [BAKED,QUAKE] or (prepare_assets and source.shader and source.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0")):
			if prepare_assets:
				var desired: Shader=QUAKE if source.get_meta("quake_authored_light",false) else BAKED
				if source.shader!=desired:source.shader=desired
				for key in ["base","glow"]:
					var image_texture=source.get_shader_parameter(key+"_texture")
					if image_texture is Texture2D:
						var prepared:=map_texture(image_texture,key=="base" and source.get_shader_parameter("alpha_cutout")==true)
						if image_texture!=prepared:source.set_shader_parameter(key+"_texture",prepared)
						for suffix in ["_nearest","_linear"]:source.set_shader_parameter(key+suffix,prepared)
			source.set_shader_parameter("texture_filter_mode",mode)
			if lighting_mode>=0:source.set_shader_parameter("contrast_lighting",lighting_mode==1)
			return
		if prepare_assets:
			# Includes imported avatar normal/mask maps and custom material slots.
			# Packed light atlases and the exact-texel BSP lookup are not images
			# that can be downsampled safely; live ViewportTextures also bypass it.
			for uniform in source.shader.get_shader_uniform_list() if source.shader else []:
				var key: String=uniform.name
				if key in DATA_SAMPLERS:continue
				var value=source.get_shader_parameter(key)
				if value is Texture2D:
					var prepared:=normal_texture(value) if key=="_BumpMap" or "normal" in key.to_lower() else texture(value)
					if value!=prepared:source.set_shader_parameter(key,prepared)
			if source.shader and not source.has_meta(BANK):
				var code: String=source.shader.code
				var regex:=RegEx.new();regex.compile("filter_(?:nearest|linear)_mipmap(?:_anisotropic)?")
				if regex.search(code):
					var variants: Array=[]
					for filter_mode in 3:
						var updated:=regex.sub(code,HINTS[filter_mode],true)
						if not shaders.has(updated):
							var shader:=Shader.new();shader.code=updated;shaders[updated]=shader
						var variant:=source.duplicate() as ShaderMaterial
						variant.shader=shaders[updated];variants.append(variant)
					source.set_meta(BANK,variants)
		if source.has_meta(BANK):
			var shader: Shader=source.get_meta(BANK)[mode].shader
			if source.shader!=shader:source.shader=shader
func apply(root: Node,filter_mode: int=2,prepare: bool=true,lighting: int=-1) -> void:
	mode=clampi(filter_mode,0,2);prepare_assets=prepare;lighting_mode=lighting
	var warmup: Warmup
	var warmed: Dictionary={}
	var nodes:=root.find_children("*","GeometryInstance3D",true,false)
	if root is GeometryInstance3D:nodes.append(root)
	for node in nodes:
		if node.has_meta("fpsloppa_filter_warmup"):continue
		material(node.material_override)
		material(node.material_overlay)
		if node is Sprite3D:
			if node.texture and not node.texture is ViewportTexture:
				if prepare:node.texture=texture(node.texture)
				node.texture_filter=FILTERS[mode]
		if node is GPUParticles3D:
			for pass_index in node.draw_passes:
				var particle_mesh: Mesh=node.get_draw_pass_mesh(pass_index)
				if particle_mesh:
					for surface in particle_mesh.get_surface_count():material(node.material_override if node.material_override else particle_mesh.surface_get_material(surface))
		var mesh: Mesh=node.mesh if node is MeshInstance3D or node is CPUParticles3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null
		if not mesh:continue
		for surface in mesh.get_surface_count():
			var source: Material=node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override else mesh.surface_get_material(surface)
			material(source)
			if not prepare or not source or not source.has_meta(BANK) or warmed.has(source) or source.has_meta("fpsloppa_filter_warmed"):continue
			if DisplayServer.get_name()=="headless":continue
			warmed[source]=true
			if not warmup:warmup=Warmup.new();warmup.name="FilterWarmup";warmup.visible=false
			warmup.sources.append(source)
			for variant in source.get_meta(BANK):
				var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=variant
				instance.cast_shadow=node.cast_shadow;instance.set_meta("fpsloppa_filter_warmup",true);warmup.add_child(instance)
	if warmup:root.add_child(warmup)
	if prepare:
		var decals:=root.find_children("*","Decal",true,false)
		if root is Decal:decals.append(root)
		for decal in decals:
			for slot in Decal.TEXTURE_MAX:
				var value: Texture2D=decal.get_texture(slot)
				decal.set_texture(slot,normal_texture(value) if slot==Decal.TEXTURE_NORMAL else texture(value))
