extends RefCounted
## Prepare pixels/variants when assets load; settings changes only select sampling.
const FILTERS=[BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]
const HINTS=["filter_nearest_mipmap","filter_linear_mipmap","filter_linear_mipmap_anisotropic"]
const BANK="fpsloppa_filter_variants"
const BAKED=preload("res://deathmatch/maps/baked_light.gdshader")
var mode:=2
var prepare_assets:=true
var shaders: Dictionary={}
var textures: Dictionary={}
var materials: Dictionary={}
class Warmup extends Node3D:
	var sources: Array=[]
	func _ready() -> void:
		# Hidden instances allow Mobile/Forward+ surface pipeline precompilation.
		# Material variants remain alive after these temporary instances are gone.
		for frame in 3:await get_tree().process_frame
		for source in sources:source.set_meta("fpsloppa_filter_warmed",true)
		queue_free()
func texture(source: Texture2D) -> Texture2D:
	if not source or source is ViewportTexture or source.has_mipmaps():return source
	if textures.has(source):return textures[source]
	var result: Texture2D=source
	var image:=source.get_image()
	if image and not image.has_mipmaps():
		if image.is_compressed():image.decompress()
		if image.generate_mipmaps()==OK:result=ImageTexture.create_from_image(image)
	textures[source]=result
	return result
func textured(source: BaseMaterial3D) -> bool:
	for slot in BaseMaterial3D.TEXTURE_MAX:
		var value:=source.get_texture(slot)
		if value and not value is ViewportTexture:return true
	return false
func material(source: Material) -> void:
	if not source or materials.has(source):return
	materials[source]=true
	if source is BaseMaterial3D:
		if not textured(source):return
		if prepare_assets:
			for slot in BaseMaterial3D.TEXTURE_MAX:
				var original: Texture2D=source.get_texture(slot)
				var prepared:=texture(original)
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
		if source.shader==BAKED or (prepare_assets and source.shader and source.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0")):
			if prepare_assets:
				if source.shader!=BAKED:source.shader=BAKED
				for key in ["base","glow"]:
					var image_texture=source.get_shader_parameter(key+"_texture")
					if image_texture is Texture2D:
						var prepared:=texture(image_texture)
						if image_texture!=prepared:source.set_shader_parameter(key+"_texture",prepared)
						for suffix in ["_nearest","_linear"]:source.set_shader_parameter(key+suffix,prepared)
			source.set_shader_parameter("texture_filter_mode",mode)
			return
		if prepare_assets:
			for key in ["base_texture","glow_texture","_MainTex","_ShadeTexture","_EmissionMap","_SphereAdd","_RimTexture","_ShadingGradeTexture","_ReceiveShadowTexture","_UvAnimMaskTexture","_OutlineWidthTexture"]:
				var value=source.get_shader_parameter(key)
				if value is Texture2D:
					var prepared:=texture(value)
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
func apply(root: Node,filter_mode: int=2,prepare: bool=true) -> void:
	mode=clampi(filter_mode,0,2);prepare_assets=prepare
	var warmup: Warmup
	var warmed: Dictionary={}
	var nodes:=root.find_children("*","GeometryInstance3D",true,false)
	if root is GeometryInstance3D:nodes.append(root)
	for node in nodes:
		if node.has_meta("fpsloppa_filter_warmup"):continue
		var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null
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
