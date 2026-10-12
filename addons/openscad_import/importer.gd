@tool
extends EditorImportPlugin
const IO=preload("res://addons/openscad_import/mesh_io.gd")
func _get_importer_name() -> String:return "entryway.openscad_csg"
func _get_visible_name() -> String:return "OpenSCAD CSG baked mesh"
func _get_recognized_extensions() -> PackedStringArray:return ["csg"]
func _get_save_extension() -> String:return "res"
func _get_resource_type() -> String:return "ArrayMesh"
func _get_preset_count() -> int:return 1
func _get_preset_name(_preset: int) -> String:return "Static union mesh"
func _get_import_options(_path: String,_preset: int) -> Array[Dictionary]:return [{"name":"openscad_binary","default_value":"openscad"}]
func _get_import_order() -> int:return 0
func _get_priority() -> float:return 1.0
func _get_option_visibility(_path: String,_option: StringName,_options: Dictionary) -> bool:return true
func _import(source: String,save_path: String,options: Dictionary,_platforms: Array[String],_generated: Array[String]) -> Error:
	var off:=save_path+".off";var output: Array=[]
	var code:=OS.execute(options.openscad_binary,PackedStringArray(["--hardwarnings","-o",ProjectSettings.globalize_path(off),ProjectSettings.globalize_path(source)]),output,true)
	if code!=0 or "ERROR:" in str(output):push_error("OpenSCAD CSG import failed: "+str(output));return ERR_CANT_CREATE
	var mesh:=IO.read_off(off,IO.palette(source.get_basename()+".palette.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(off))
	if mesh==null:return ERR_INVALID_DATA
	return ResourceSaver.save(mesh,save_path+".res")
