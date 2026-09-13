extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	# Real compressed pre-experiment scene: exercises embedded shader upgrade,
	# atlas preservation, cutouts/glow and map-load preference propagation.
	var path:="res://maps/cache/tf_vesper-lightmap1.scn"
	var level: Node=load(path).instantiate();root.add_child(level)
	var originals: Dictionary={}
	for node in level.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(i)
			if mat is ShaderMaterial and mat.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0"):
				originals[mat]=[mat.get_shader_parameter("bake_texture"),mat.get_shader_parameter("base_texture"),mat.get_shader_parameter("alpha_cutout"),mat.get_shader_parameter("has_glow")]
	check(originals.size()>0,"Fixture contains cached baked materials")
	Filtering.new().apply(level,2,true,1)
	for mat in originals:
		check(mat.shader==Filtering.BAKED and mat.get_shader_parameter("contrast_lighting")==true,"Cached shader receives current lighting and saved contrast choice")
		var old: Array=originals[mat]
		check(mat.get_shader_parameter("bake_texture")==old[0] and mat.get_shader_parameter("alpha_cutout")==old[2] and mat.get_shader_parameter("has_glow")==old[3],"Upgrade retains atlas, cutout and emission flags")
	var shader: Shader=originals.keys()[0].shader
	Filtering.new().apply(level,0,false)
	check(originals.keys()[0].get_shader_parameter("contrast_lighting"),"Texture-only changes preserve contrast setting")
	Filtering.new().apply(level,0,false,0)
	check(originals.keys()[0].shader==shader and originals.keys()[0].get_shader_parameter("contrast_lighting")==false,"Classic restore changes uniforms without replacing shader")
	level.queue_free();await process_frame
	print("LIGHTING_PROFILE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
